class_name C4Satchel
extends RigidBody3D
## Tactical C4 Satchel Charge with Remote Detonator or Configurable Timers.
## Can be thrown at choke points and detonated remotely or set on timed fuses (5s/10s/30s).

signal exploded(origin: Vector3)
## Metres the blast or shot is heard by patrolling sentries (JaffaAI.hear).
const NOISE_RADIUS := 45.0

enum C4Mode { REMOTE, TIMER_5S, TIMER_10S, TIMER_30S }

@export var blast_damage: float = 200.0
@export var blast_radius: float = 7.5
@export var mode: C4Mode = C4Mode.REMOTE
@export var countdown_seconds: float = 0.0

var is_armed: bool = false
var is_detonated: bool = false
var timer_remaining: float = 0.0
var planter: Node = null
var last_beep_second: int = 999

@onready var led_light: OmniLight3D = $LEDLight if has_node("LEDLight") else null


func set_timer_mode(seconds: float) -> void:
	if seconds <= 5.5:
		mode = C4Mode.TIMER_5S
	elif seconds <= 15.0:
		mode = C4Mode.TIMER_10S
	else:
		mode = C4Mode.TIMER_30S
	countdown_seconds = seconds
	timer_remaining = seconds


func _ready() -> void:
	if mode != C4Mode.REMOTE and countdown_seconds > 0.0:
		timer_remaining = countdown_seconds
		last_beep_second = int(ceilf(timer_remaining))

	# Arm charge 0.5s after throw
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		is_armed = true
		if led_light != null:
			led_light.visible = true
	)


func _process(delta: float) -> void:
	if is_armed and mode != C4Mode.REMOTE and not is_detonated:
		timer_remaining -= delta
		var current_sec := int(ceilf(timer_remaining))
		if current_sec != last_beep_second and current_sec >= 0:
			last_beep_second = current_sec
			_play_beep_sfx()
			if led_light != null:
				led_light.light_energy = 4.0
				var tween := create_tween()
				tween.tween_property(led_light, "light_energy", 1.0, 0.2)

		if timer_remaining <= 0.0:
			detonate()


func _play_beep_sfx() -> void:
	if ResourceLoader.exists("res://audio/sfx_gdo_beep.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_gdo_beep.wav")
		audio.max_distance = 25.0
		audio.unit_size = 4.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func detonate() -> void:
	if is_detonated or not is_armed:
		return
	is_detonated = true
	exploded.emit(global_position)
	get_tree().call_group(&"noise_listeners", &"hear", global_position, NOISE_RADIUS, planter)

	# Apply radial blast damage to all entities within radius
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 | 4  # Players (2) and Jaffa (4)

	var hits := space.intersect_shape(query, 32)
	for hit in hits:
		var collider := hit["collider"] as Node
		if collider != null:
			var health := collider.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				var dist := global_position.distance_to(collider.global_position)
				var falloff := 1.0 - clampf(dist / blast_radius, 0.0, 1.0)
				var applied_dmg := blast_damage * falloff
				health.take_damage(applied_dmg, planter, "c4_explosion")

	# Visual explosion burst
	_spawn_explosion_fx()
	queue_free()


func _spawn_explosion_fx() -> void:
	# Screen shake for nearby operatives
	var players := get_tree().root.find_child("Players", true, false)
	if players != null:
		for p in players.get_children():
			if p is PlayerController3D:
				var d := global_position.distance_to(p.global_position)
				var falloff := clampf(1.0 - (d / 35.0), 0.1, 1.0)
				p.add_screen_shake(0.85 * falloff)

	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.5
	sphere.height = 5.0
	blast_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.1, 0.9)
	blast_mesh.material_override = mat
	get_tree().root.add_child(blast_mesh)
	blast_mesh.global_position = global_position

	var tween := blast_mesh.create_tween()
	tween.tween_property(blast_mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.15)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(blast_mesh.queue_free)

	if ResourceLoader.exists("res://audio/sfx_explosion.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_explosion.wav")
		audio.bus = &"SFX"
		audio.max_distance = 60.0
		audio.unit_size = 15.0
		get_tree().root.add_child(audio)
		audio.global_position = global_position
		audio.finished.connect(audio.queue_free)
		audio.play()
