class_name WaveManager
extends Node
## SGC Foothold Defense Wave Coordinator.
## Manages wave progressions, Stargate gate-room spawns, enemy tracking, and intermission timers.

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal jaffa_count_changed(remaining: int, current_wave: int)
signal intermission_tick(seconds_left: int)
signal all_waves_defeated()
signal multi_sector_incursion_started(sectors: Array[String])

const JAFFA_SCENE_PATH: String = "res://scenes/entities/JaffaGuard.tscn"
const SHOCK_GUARD_SCENE_PATH: String = "res://scenes/entities/JaffaShockGuard.tscn"

@export var max_waves: int = 3
@export var intermission_duration_s: float = 8.0

var current_wave: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
var is_intermission: bool = false
var intermission_timer: float = 0.0
var klaxon_loop_timer: float = 0.0

@onready var enemies_container: Node3D = get_node_or_null("../Enemies")
@onready var gate_spawn_marker: Marker3D = get_node_or_null("../GateSpawnMarker")
@onready var transport_rings: TransportRings = get_node_or_null("../TransportRings") as TransportRings


func _ready() -> void:
	# Waves are driven authoritatively by the host server
	if not multiplayer.is_server():
		return

	if transport_rings != null and not transport_rings.reinforcement_spawned.is_connected(_on_ring_reinforcement_spawned):
		transport_rings.reinforcement_spawned.connect(_on_ring_reinforcement_spawned)


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

	# Continuous Klaxon alarm pulse during Wave 3 Overwhelming Assault
	if is_wave_active and current_wave == 3:
		klaxon_loop_timer -= delta
		if klaxon_loop_timer <= 0.0:
			klaxon_loop_timer = 3.0
			_play_klaxon()


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
	print("WaveManager: Starting Wave %d with %d %s!" % [current_wave, count_to_spawn, "Shock Guards" if current_wave == 3 else "Jaffa Guards"])

	_play_klaxon()
	klaxon_loop_timer = 3.0
	_trigger_incoming_stargate(count_to_spawn)


func _play_klaxon() -> void:
	if ResourceLoader.exists("res://audio/sfx_klaxon.wav"):
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://audio/sfx_klaxon.wav")
		if AudioServer.get_bus_index("Klaxons / Ambience") != -1:
			audio.bus = &"Klaxons / Ambience"
		elif AudioServer.get_bus_index("Ambience") != -1:
			audio.bus = &"Ambience"
		else:
			audio.bus = &"Master"
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _trigger_incoming_stargate(total_count: int) -> void:
	var stargate := get_node_or_null("../Stargate") as StargateRing
	if stargate != null:
		# Lock Chevrons 1 through 7 sequentially (0.15s interval)
		for c in range(1, 8):
			await get_tree().create_timer(0.15).timeout
			stargate.lock_chevron(c)
		await get_tree().create_timer(1.2).timeout

	var ramp_count: int = total_count
	var ring_reinforcements: int = 0

	if current_wave >= 2 and transport_rings != null:
		ring_reinforcements = 2
		ramp_count = maxi(0, total_count - ring_reinforcements)

		transport_rings.reinforcements_per_beam = ring_reinforcements
		if current_wave == 3:
			transport_rings.reinforcement_scene = load(SHOCK_GUARD_SCENE_PATH) as PackedScene
		else:
			transport_rings.reinforcement_scene = load(JAFFA_SCENE_PATH) as PackedScene

		var ring_timer := get_tree().create_timer(3.0)
		ring_timer.timeout.connect(func() -> void:
			if transport_rings != null and is_wave_active:
				transport_rings.trigger_ring_drop()
		)

	# Spawn ramp enemies
	_spawn_wave_jaffa(ramp_count)


func _spawn_wave_jaffa(ramp_count: int) -> void:
	var scene_path: String = SHOCK_GUARD_SCENE_PATH if current_wave == 3 else JAFFA_SCENE_PATH
	var jaffa_scene := load(scene_path) as PackedScene
	if jaffa_scene == null or enemies_container == null:
		push_error("WaveManager: Missing Jaffa scene or Enemies container.")
		return

	var spawn_pos: Vector3 = Vector3(0, 2.2, -13.5)
	if gate_spawn_marker != null:
		spawn_pos = gate_spawn_marker.global_position

	for i in range(ramp_count):
		var offset := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-0.5, 1.5))
		var jaffa := jaffa_scene.instantiate() as JaffaAI
		jaffa.name = "%s_W%d_%d" % ["Shock" if current_wave == 3 else "Jaffa", current_wave, i + 1]
		jaffa.position = spawn_pos + offset

		enemies_container.add_child(jaffa, true)
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))


func _on_ring_reinforcement_spawned(jaffa: JaffaAI) -> void:
	if jaffa != null and not jaffa.jaffa_died.is_connected(_on_jaffa_killed):
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))


func _on_jaffa_killed(_killer: Node, _jaffa: JaffaAI) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	jaffa_count_changed.emit(enemies_alive, current_wave)
	print("WaveManager: Enemy eliminated! %d remaining in Wave %d." % [enemies_alive, current_wave])

	if enemies_alive == 0 and is_wave_active:
		is_wave_active = false
		wave_cleared.emit(current_wave)
		print("WaveManager: Wave %d CLEARED! Intermission starting (%.0f s)..." % [current_wave, intermission_duration_s])

		if current_wave < max_waves:
			is_intermission = true
			intermission_timer = intermission_duration_s
		else:
			all_waves_defeated.emit()


## Initiates Sprint 9 Foothold Climax Multi-Sector Incursion.
## Concurrently spawns elite strike squads across Gate Room, Transport Rings, and Level 27 Upper Deck.
func trigger_climax_incursion() -> void:
	current_wave = 4
	max_waves = 4
	is_wave_active = true
	var total_count := 8
	enemies_alive = total_count
	wave_started.emit(current_wave, total_count)
	var sectors: Array[String] = ["GATE_ROOM", "ARMORY_HALLWAY", "LEVEL_27_CORRIDOR"]
	multi_sector_incursion_started.emit(sectors)
	print("WaveManager: MULTI-SECTOR CLIMAX INCURSION ENGAGED! Breaches across Gate Room, Armory Rings, and Level 27 Upper Deck!")

	# 1. Sector 1: Gate Room Ramp incursion (4 hostiles)
	_spawn_wave_jaffa(4)

	# 2. Sector 2: Fallback Hallway / Armory rings incursion (2 hostiles)
	if transport_rings != null:
		transport_rings.reinforcements_per_beam = 2
		transport_rings.reinforcement_scene = load(SHOCK_GUARD_SCENE_PATH) as PackedScene
		transport_rings.trigger_ring_drop()
	else:
		_spawn_sector_jaffa(Vector3(3.0, 0.0, 39.0), 2, true)

	# 3. Sector 3: Level 27 Upper Corridor breach (2 Shock Guards)
	_spawn_sector_jaffa(Vector3(26.0, 5.5, 18.0), 2, true)


func _spawn_sector_jaffa(spawn_pos: Vector3, count: int, is_shock: bool = false) -> void:
	var scene_path: String = SHOCK_GUARD_SCENE_PATH if is_shock else JAFFA_SCENE_PATH
	var jaffa_scene := load(scene_path) as PackedScene
	if jaffa_scene == null or enemies_container == null:
		return

	for i in range(count):
		var offset := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
		var jaffa := jaffa_scene.instantiate() as JaffaAI
		jaffa.name = "%s_Sector_%d" % ["Shock" if is_shock else "Jaffa", i + 1]
		jaffa.position = spawn_pos + offset
		enemies_container.add_child(jaffa, true)
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))
