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

var current_state: RingState = RingState.INACTIVE
var telegraph_timer: float = 0.0

@onready var rings_container: Node3D = $RingsStack if has_node("RingsStack") else null
@onready var beam_column: MeshInstance3D = $BeamColumn if has_node("BeamColumn") else null
@onready var telegraph_light: OmniLight3D = $TelegraphLight if has_node("TelegraphLight") else null
@onready var crush_area: Area3D = $CrushArea if has_node("CrushArea") else null


func _ready() -> void:
	if beam_column != null:
		beam_column.visible = false
	if crush_area != null:
		crush_area.monitoring = false
		crush_area.body_entered.connect(_on_crush_body_entered)


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

	# If server and configured, spawn Jaffa reinforcements directly in the rings
	if multiplayer.is_server() and spawn_enemies_on_beam:
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
