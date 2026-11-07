class_name TransportRings
extends Node3D
## Goa'uld Transport Rings with 2-way tactical physics.
## Handles ceiling telegraph, crush hitbox, beaming column flash, and reinforcement drops.

signal telegraph_started()
signal rings_slammed(ground_position: Vector3)
signal beam_discharged()
signal rings_retracted()

enum RingState { INACTIVE, TELEGRAPH, SLAM, BEAM, RETRACT }

@export var ring_count: int = 5
@export var telegraph_duration_s: float = 2.0
@export var beam_duration_s: float = 1.0
@export var crush_damage: float = 80.0
@export var spawn_enemies_on_beam: bool = true
@export var paired_rings_path: NodePath = ""
var paired_rings: TransportRings = null

var current_state: RingState = RingState.INACTIVE
var telegraph_timer: float = 0.0

@onready var rings_container: Node3D = $RingsStack if has_node("RingsStack") else null
@onready var beam_column: MeshInstance3D = $BeamColumn if has_node("BeamColumn") else null
@onready var telegraph_light: OmniLight3D = $TelegraphLight if has_node("TelegraphLight") else null
@onready var crush_area: Area3D = $CrushArea if has_node("CrushArea") else null


func _ready() -> void:
	_resolve_paired_rings()
	call_deferred("_resolve_paired_rings")

	if beam_column != null:
		beam_column.visible = false
	if crush_area != null:
		crush_area.monitoring = false
		crush_area.body_entered.connect(_on_crush_body_entered)


func _resolve_paired_rings() -> void:
	if paired_rings == null and not paired_rings_path.is_empty() and has_node(paired_rings_path):
		paired_rings = get_node(paired_rings_path) as TransportRings


## Initiates the transport ring drop sequence
func trigger_ring_drop() -> void:
	if not multiplayer.is_server():
		return
	rpc("sync_trigger_ring_drop")


@rpc("call_local", "reliable")
func sync_trigger_ring_drop() -> void:
	current_state = RingState.TELEGRAPH
	telegraph_started.emit()
	print("Transport Rings: Ceiling hatch opening! Rings descending in 2s...")
	_play_sfx("res://audio/sfx_rings.wav", 60.0)

	if telegraph_light != null:
		telegraph_light.visible = true
		telegraph_light.light_color = Color(1.0, 0.75, 0.2)
		telegraph_light.light_energy = 4.0

	# Telegraph timer
	var timer := get_tree().create_timer(telegraph_duration_s)
	timer.timeout.connect(_slam_rings_down)


func _slam_rings_down() -> void:
	current_state = RingState.SLAM
	rings_slammed.emit(global_position)
	print("Transport Rings: SLAM! Concentric rings hit floor plate.")

	# Screen shake on kinetic floor slam
	var players_node := get_tree().root.find_child("Players", true, false)
	if players_node != null:
		for p in players_node.get_children():
			if p is PlayerController3D:
				p.add_screen_shake(0.55)

	# Enable crush hitbox
	if crush_area != null:
		crush_area.monitoring = true

	# Animate rings stack descending rapidly
	if rings_container != null:
		rings_container.position.y = 8.0
		rings_container.visible = true
		var tween := create_tween()
		tween.tween_property(rings_container, "position:y", 0.0, 0.22)
		tween.tween_callback(_discharge_beam)
	else:
		_discharge_beam()


func _discharge_beam() -> void:
	current_state = RingState.BEAM
	beam_discharged.emit()
	print("Transport Rings: Beaming matter stream activated!")

	if crush_area != null:
		crush_area.monitoring = false

	if beam_column != null:
		beam_column.visible = true
		beam_column.scale = Vector3(1, 1, 1)

	var intercepted_explosive: bool = false

	# 1. Check for explosives inside the rings (Tactical Interception)
	var satchels := get_tree().root.find_children("", "C4Satchel", true, false)
	for s in satchels:
		var satchel := s as Node3D
		if satchel != null and global_position.distance_to(satchel.global_position) <= 2.2:
			intercepted_explosive = true
			satchel.queue_free()
			print("Transport Rings: Explosive beamed up to mothership! Reserve wave neutralized!")
			if ResourceLoader.exists("res://audio/sfx_explosion.wav"):
				_play_sfx("res://audio/sfx_explosion.wav", 80.0)

	# 2. Check for operatives inside the rings (2-Way Teleportation)
	if paired_rings == null:
		_resolve_paired_rings()
	if paired_rings != null and is_instance_valid(paired_rings):
		var players := get_tree().root.find_children("", "PlayerController3D", true, false)
		for p in players:
			var player := p as PlayerController3D
			if player != null and global_position.distance_to(player.global_position) <= 2.2:
				var dest: Vector3 = paired_rings.global_position + Vector3(0, 0.1, 0)
				player.global_position = dest
				print("Transport Rings: Operative %s beamed to paired rings at %s!" % [player.name, str(dest)])
				paired_rings.trigger_ring_drop()

	# 3. If server and not intercepted, spawn reinforcements
	if multiplayer.is_server() and spawn_enemies_on_beam and not intercepted_explosive:
		_spawn_ring_reinforcements()

	var timer := get_tree().create_timer(beam_duration_s)
	timer.timeout.connect(_retract_rings)


func _spawn_ring_reinforcements() -> void:
	var jaffa_scene := load("res://scenes/entities/JaffaGuard.tscn") as PackedScene
	var enemies_container := get_tree().root.find_child("Enemies", true, false)
	if jaffa_scene != null and enemies_container != null:
		var jaffa := jaffa_scene.instantiate() as JaffaAI
		jaffa.name = "RingJaffa_%d" % randi()
		jaffa.position = global_position + Vector3(0, 0.1, 0)
		enemies_container.add_child(jaffa, true)
		print("Transport Rings: Beamed down Jaffa Shock Guard!")


func _retract_rings() -> void:
	current_state = RingState.RETRACT
	rings_retracted.emit()
	print("Transport Rings: Matter transfer complete. Rings ascending.")

	if beam_column != null:
		beam_column.visible = false

	if rings_container != null:
		var tween := create_tween()
		tween.tween_property(rings_container, "position:y", 8.0, 0.35)
		tween.tween_callback(func() -> void:
			current_state = RingState.INACTIVE
			rings_container.visible = false
			if telegraph_light != null:
				telegraph_light.visible = false
		)
	else:
		current_state = RingState.INACTIVE
		if telegraph_light != null:
			telegraph_light.visible = false


func _on_crush_body_entered(body: Node) -> void:
	if current_state != RingState.SLAM:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and not health.is_dead:
		print("Transport Rings: Entity %s crushed by slamming rings!" % body.name)
		health.take_damage(crush_damage, self, "ring_crush")


func _play_sfx(path: String, max_dist: float) -> void:
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 12.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
