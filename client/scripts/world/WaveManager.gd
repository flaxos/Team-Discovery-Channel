class_name WaveManager
extends Node
## SGC Foothold Defense Wave Coordinator.
## Manages wave progressions, Stargate gate-room spawns, enemy tracking, and intermission timers.

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal intermission_tick(seconds_left: int)
signal all_waves_defeated()

const JAFFA_SCENE_PATH: String = "res://scenes/entities/JaffaGuard.tscn"

@export var max_waves: int = 3
@export var intermission_duration_s: float = 8.0

var current_wave: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
var is_intermission: bool = false
var intermission_timer: float = 0.0

@onready var enemies_container: Node3D = get_node_or_null("../Enemies")
@onready var gate_spawn_marker: Marker3D = get_node_or_null("../GateSpawnMarker")


func _ready() -> void:
	# Waves are driven authoritatively by the host server
	if not multiplayer.is_server():
		return


func start_wave_defense() -> void:
	if not multiplayer.is_server():
		return
	current_wave = 0
	start_next_wave()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if is_intermission:
		intermission_timer -= delta
		intermission_tick.emit(int(ceil(intermission_timer)))
		if intermission_timer <= 0.0:
			is_intermission = false
			start_next_wave()


func start_next_wave() -> void:
	current_wave += 1
	if current_wave > max_waves:
		print("WaveManager: All SGC Foothold waves defeated! Iris secured.")
		all_waves_defeated.emit()
		return

	is_wave_active = true
	var count_to_spawn := 2 + current_wave * 2  # Wave 1 = 4, Wave 2 = 6, Wave 3 = 8
	enemies_alive = count_to_spawn
	wave_started.emit(current_wave, count_to_spawn)
	print("WaveManager: Starting Wave %d with %d Jaffa Guards!" % [current_wave, count_to_spawn])

	# Spawn Jaffa with slight delays from Stargate platform
	_spawn_wave_jaffa(count_to_spawn)


func _spawn_wave_jaffa(total_count: int) -> void:
	var jaffa_scene := load(JAFFA_SCENE_PATH) as PackedScene
	if jaffa_scene == null or enemies_container == null:
		push_error("WaveManager: Missing Jaffa scene or Enemies container.")
		return

	var spawn_pos: Vector3 = Vector3(0, 2.2, -13.5)
	if gate_spawn_marker != null:
		spawn_pos = gate_spawn_marker.global_position

	for i in range(total_count):
		# Slight offset on platform
		var offset := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-0.5, 1.5))
		var jaffa := jaffa_scene.instantiate() as JaffaAI
		jaffa.name = "Jaffa_W%d_%d" % [current_wave, i + 1]
		jaffa.position = spawn_pos + offset

		enemies_container.add_child(jaffa, true)
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))


func _on_jaffa_killed(_killer: Node, jaffa: JaffaAI) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	print("WaveManager: Jaffa killed! %d remaining in Wave %d." % [enemies_alive, current_wave])

	if enemies_alive == 0 and is_wave_active:
		is_wave_active = false
		wave_cleared.emit(current_wave)
		print("WaveManager: Wave %d CLEARED! Intermission starting (%.0f s)..." % [current_wave, intermission_duration_s])

		if current_wave < max_waves:
			is_intermission = true
			intermission_timer = intermission_duration_s
		else:
			all_waves_defeated.emit()
