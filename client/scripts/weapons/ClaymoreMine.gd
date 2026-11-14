class_name ClaymoreMine
extends Node3D
## SGC M18A1 Directional Anti-Personnel Claymore Mine.
## Features laser tripwire detection, 1.0s arming delay, and 120-degree forward lethal fragmentation blast.

signal detonated(origin: Vector3)
## Metres the blast or shot is heard by patrolling sentries (JaffaAI.hear).
const NOISE_RADIUS := 40.0

@export var blast_damage: float = 320.0
@export var blast_radius: float = 7.5
@export var blast_arc_deg: float = 120.0
@export var tripwire_range: float = 4.5

var planter: Node = null
var is_armed: bool = false

@onready var tripwire_area: Area3D = $TripwireArea if has_node("TripwireArea") else null
@onready var arm_light: OmniLight3D = $ArmLight if has_node("ArmLight") else null


func _ready() -> void:
	if tripwire_area != null:
		tripwire_area.monitoring = false
		tripwire_area.body_entered.connect(_on_tripwire_tripped)

	# 1.0s arming timer
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		is_armed = true
		if tripwire_area != null:
			tripwire_area.monitoring = true
		if arm_light != null:
			arm_light.light_color = Color(1.0, 0.2, 0.2)
			arm_light.light_energy = 2.0
		print("Claymore: ARMED and monitoring directional tripwire.")
	)


func _on_tripwire_tripped(body: Node) -> void:
	if not is_armed:
		return
	var jaffa := body as JaffaAI
	if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
		detonate()


func detonate() -> void:
	is_armed = false
	detonated.emit(global_position)
	get_tree().call_group(&"noise_listeners", &"hear", global_position, NOISE_RADIUS, planter)
	print("Claymore: TRIPWIRE TRIGGERED! Detonating directional fragmentation blast!")

	# Spatial query for all entities in forward arc
	var forward := -global_transform.basis.z.normalized()
	var half_arc_rad := deg_to_rad(blast_arc_deg * 0.5)

	var enemies := MissionWorld.find(self, "Enemies")
	if enemies != null:
		for child in enemies.get_children():
			var jaffa := child as JaffaAI
			if jaffa != null and jaffa.health_component != null:
				var to_enemy := (jaffa.global_position - global_position)
				var dist := to_enemy.length()
				if dist <= blast_radius:
					var angle := forward.angle_to(to_enemy.normalized())
					if angle <= half_arc_rad:
						var falloff := 1.0 - (dist / blast_radius) * 0.5
						var applied_dmg := blast_damage * falloff
						jaffa.health_component.take_damage(applied_dmg, planter, "claymore_shrapnel")

	_spawn_blast_fx()
	queue_free()


func _spawn_blast_fx() -> void:
	# Screen shake for nearby operatives
	var players := MissionWorld.find(self, "Players")
	if players != null:
		for p in players.get_children():
			if p is PlayerController3D:
				var d := global_position.distance_to(p.global_position)
				var falloff := clampf(1.0 - (d / 30.0), 0.1, 1.0)
				p.add_screen_shake(0.70 * falloff)

	# Audio
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://audio/sfx_explosion.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_explosion.wav")
		audio.bus = &"SFX"
		audio.max_distance = 60.0
		audio.unit_size = 15.0
		get_tree().root.add_child(audio)
		audio.global_position = global_position
		audio.finished.connect(audio.queue_free)
		audio.play()

	# Visual blast cone
	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.8
	sphere.height = 5.6
	blast_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.95)
	blast_mesh.material_override = mat
	get_tree().root.add_child(blast_mesh)
	blast_mesh.global_position = global_position

	var tween := blast_mesh.create_tween()
	tween.tween_property(blast_mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.15)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(blast_mesh.queue_free)
