class_name WaveManager
extends Node
## SGC Foothold Defense Wave Coordinator.
## Manages 38-second wormhole incursions, sequential chevron locking, Kawoosh event horizons,
## Iris malfunctions, inter-gate recharge windows, tiered difficulty, and Hard Mode Lab ROM objectives.

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal jaffa_count_changed(remaining: int, current_wave: int)
signal intermission_tick(seconds_left: int)
signal all_waves_defeated()
signal multi_sector_incursion_started(sectors: Array[String])
signal wormhole_timer_tick(seconds_left: float, total_duration: float)
signal wormhole_state_changed(is_open: bool, state_name: String)
signal chevron_sequence_started()
signal iris_malfunction_declared()
signal lab_patch_objective_started()
signal iris_repaired_event()

enum DifficultyTier { EASY, MEDIUM, HARD }

const JAFFA_SCENE_PATH: String = "res://scenes/entities/JaffaGuard.tscn"
const SHOCK_GUARD_SCENE_PATH: String = "res://scenes/entities/JaffaShockGuard.tscn"

@export var difficulty: DifficultyTier = DifficultyTier.MEDIUM
@export var wormhole_duration_s: float = 38.0
@export var inter_gate_recharge_s: float = 20.0
@export var max_waves: int = 3

var current_wave: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
var is_intermission: bool = false
var intermission_timer: float = 0.0
var klaxon_loop_timer: float = 0.0

var inbound_wormhole_timer: float = 0.0
var is_wormhole_open: bool = false
var stream_spawn_timer: float = 0.0
var stream_spawn_interval: float = 7.0
var is_iris_repaired: bool = false
var target_activations: int = 3

@export var rank_spawn_interval: float = 2.0
var pending_column_spawns: int = 0
var column_stream_timer: float = 0.0
var current_rank_index: int = 0

@onready var enemies_container: Node3D = get_node_or_null("../Enemies")
@onready var gate_spawn_marker: Marker3D = get_node_or_null("../GateSpawnMarker")
@onready var transport_rings: TransportRings = get_node_or_null("../TransportRings") as TransportRings


func _ready() -> void:
	_configure_difficulty()

	# Connect Iris Servo Housing if present in Gate Room
	var iris_servo := get_node_or_null("../IrisServoHousing") as IrisServoHousingScript
	if iris_servo != null:
		iris_servo.iris_repaired.connect(_on_iris_servo_repaired)

	# Connect Dialing Console patch upload signal
	var dialer := get_tree().root.find_child("SGCDialingConsole", true, false) as SGCDialingConsoleScript
	if dialer != null:
		dialer.patch_upload_completed.connect(_on_patch_upload_completed)


func set_difficulty(tier: DifficultyTier) -> void:
	difficulty = tier
	_configure_difficulty()


func _configure_difficulty() -> void:
	match difficulty:
		DifficultyTier.EASY:
			target_activations = 1
			max_waves = 1
		DifficultyTier.MEDIUM:
			target_activations = 3
			max_waves = 3
		DifficultyTier.HARD:
			target_activations = 4
			max_waves = 4


func start_wave_defense() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	current_wave = 0
	_configure_difficulty()
	start_next_wave()


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Inbound Wormhole 38-second Countdown Engine
	if is_wormhole_open:
		inbound_wormhole_timer -= delta
		wormhole_timer_tick.emit(maxf(0.0, inbound_wormhole_timer), wormhole_duration_s)

		# Hostile reinforcement streaming down the ramp while wormhole is open
		if not is_iris_repaired:
			# Cadenced 2-by-2 column stream spawner
			if pending_column_spawns > 0:
				column_stream_timer -= delta
				if column_stream_timer <= 0.0:
					column_stream_timer = rank_spawn_interval
					_spawn_next_column_rank()

			# Continuous reinforcements while gate is active
			stream_spawn_timer -= delta
			if stream_spawn_timer <= 0.0 and inbound_wormhole_timer > 6.0:
				stream_spawn_timer = stream_spawn_interval
				_spawn_ramp_reinforcements(2)

		if inbound_wormhole_timer <= 0.0:
			_collapse_inbound_wormhole()

	# Inter-gate Recharge Window / Intermission
	if is_intermission:
		intermission_timer -= delta
		intermission_tick.emit(int(ceil(intermission_timer)))
		if intermission_timer <= 0.0:
			is_intermission = false
			start_next_wave()

	# Klaxon alarm pulse during active breaches
	if is_wave_active and is_wormhole_open:
		klaxon_loop_timer -= delta
		if klaxon_loop_timer <= 0.0:
			klaxon_loop_timer = 4.0
			_play_klaxon()


func start_next_wave() -> void:
	current_wave += 1
	if current_wave > target_activations:
		print("WaveManager: All %d incursion activations repelled!" % target_activations)
		_evaluate_mission_completion()
		return

	is_wave_active = true
	is_iris_repaired = false
	stream_spawn_timer = stream_spawn_interval
	column_stream_timer = 0.0
	current_rank_index = 0
	pending_column_spawns = 0

	var initial_count: int = 4 + (current_wave - 1) * 2
	enemies_alive = initial_count
	wave_started.emit(current_wave, enemies_alive)

	print("WaveManager: === UNSCHEDULED OFFWORLD ACTIVATION (Incursion %d/%d) ===" % [current_wave, target_activations])
	_play_klaxon()
	_execute_inbound_gate_sequence()


func _execute_inbound_gate_sequence() -> void:
	chevron_sequence_started.emit()
	var stargate := get_node_or_null("../Stargate") as StargateRing

	# Step 1: Sequential Chevrons 1 through 7 locking
	if stargate != null:
		for c in range(1, 8):
			await get_tree().create_timer(0.2).timeout
			stargate.lock_chevron(c)
		await get_tree().create_timer(0.8).timeout

	# Step 2: Chevron 7 locked -> Kawoosh Eruption occurs automatically via StargateRing!
	# Step 3: Iris Malfunction Tannoy Announcement
	await get_tree().create_timer(0.6).timeout
	iris_malfunction_declared.emit()
	print("WaveManager: [TANNOY] Iris malfunction! Trinium iris jammed open! Red alert! All response teams to the Gate Room!")
	_play_sfx("res://audio/sfx_iris_open.wav", 60.0)

	# Step 4: 38-Second Incursion Window Begins
	is_wormhole_open = true
	inbound_wormhole_timer = wormhole_duration_s
	wormhole_state_changed.emit(true, "INBOUND_ACTIVE")

	# Initial breach squad (4 Jaffa)
	var initial_count := 4 + (current_wave - 1) * 2
	_spawn_wave_jaffa(initial_count)


func _collapse_inbound_wormhole() -> void:
	is_wormhole_open = false
	wormhole_state_changed.emit(false, "DISENGAGED")
	print("WaveManager: [TANNOY] Inbound wormhole collapsed! Inter-gate recharge window: %.0fs." % inter_gate_recharge_s)

	if pending_column_spawns > 0:
		enemies_alive = maxi(0, enemies_alive - pending_column_spawns)
		pending_column_spawns = 0
		jaffa_count_changed.emit(enemies_alive, current_wave)

	var stargate := get_node_or_null("../Stargate") as StargateRing
	if stargate != null:
		stargate.close_wormhole()

	if enemies_alive == 0:
		_on_all_incursion_enemies_cleared()


func _spawn_ramp_reinforcements(count: int) -> void:
	if not is_wave_active or not is_wormhole_open:
		return
	enemies_alive += count
	jaffa_count_changed.emit(enemies_alive, current_wave)
	print("WaveManager: Reinforcements streaming through event horizon (+%d Jaffa)!" % count)
	_spawn_wave_jaffa(count)


func _spawn_wave_jaffa(ramp_count: int) -> void:
	pending_column_spawns += ramp_count
	# Immediately spawn the first rank upon event horizon activation
	if column_stream_timer <= 0.0:
		_spawn_next_column_rank()
		column_stream_timer = rank_spawn_interval


func _spawn_next_column_rank() -> void:
	if pending_column_spawns <= 0:
		return

	var is_shock_wave: bool = (current_wave >= 3)
	var scene_path: String = SHOCK_GUARD_SCENE_PATH if is_shock_wave else JAFFA_SCENE_PATH
	var jaffa_scene: PackedScene = load(scene_path) as PackedScene
	if jaffa_scene == null or enemies_container == null:
		push_error("WaveManager: Missing Jaffa scene or Enemies container.")
		return

	var spawn_origin: Vector3 = Vector3(0.0, 2.2, -13.5)
	if gate_spawn_marker != null:
		spawn_origin = gate_spawn_marker.global_position

	var count_this_rank: int = mini(2, pending_column_spawns)
	pending_column_spawns -= count_this_rank

	var offsets: Array[float] = [-0.8, 0.8]
	if count_this_rank == 1:
		offsets = [-0.8]

	for i: int in range(count_this_rank):
		var x_offset: float = offsets[i]
		var jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		if jaffa == null:
			continue
		jaffa.name = "%s_W%d_R%d_%d" % [
			"Shock" if is_shock_wave else "Jaffa",
			current_wave,
			current_rank_index,
			randi() % 10000
		]
		jaffa.position = Vector3(spawn_origin.x + x_offset, spawn_origin.y, spawn_origin.z)
		jaffa.formation_rank = current_rank_index
		jaffa.is_front_rank = (current_rank_index == 0)
		jaffa.column_x_lane = spawn_origin.x + x_offset

		enemies_container.add_child(jaffa, true)
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))

		# Symmetrically march down the ramp toward Gate Room center (Z = 0.0)
		var march_target_pos: Vector3 = Vector3(spawn_origin.x + x_offset, 0.0, 0.0)
		jaffa.start_column_march(march_target_pos)

	current_rank_index += 1


func _on_jaffa_killed(_killer: Node, _jaffa: JaffaAI) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	jaffa_count_changed.emit(enemies_alive, current_wave)
	print("WaveManager: Enemy eliminated! %d remaining in Incursion %d." % [enemies_alive, current_wave])

	if enemies_alive == 0 and not is_wormhole_open and is_wave_active:
		_on_all_incursion_enemies_cleared()


func _on_all_incursion_enemies_cleared() -> void:
	is_wave_active = false
	wave_cleared.emit(current_wave)
	print("WaveManager: Incursion %d/%d REPULSED!" % [current_wave, target_activations])

	if current_wave < target_activations:
		is_intermission = true
		intermission_timer = inter_gate_recharge_s
		print("WaveManager: Inter-gate recharge active (%.0f s). Resupply at Armory!" % inter_gate_recharge_s)
	else:
		_evaluate_mission_completion()


func _evaluate_mission_completion() -> void:
	if difficulty == DifficultyTier.HARD:
		_trigger_hard_mode_buffer_lockout()
	else:
		print("WaveManager: SGC Sublevel 28 SECURED! Outbound dialing permitted.")
		all_waves_defeated.emit()


func _trigger_hard_mode_buffer_lockout() -> void:
	print("WaveManager: [HARD MODE] Goa'uld dialing buffer encryption virus active! Corrupted buffer!")
	var dialer := get_tree().root.find_child("SGCDialingConsole", true, false) as SGCDialingConsoleScript
	if dialer != null:
		dialer.set_buffer_corrupted(true)

	lab_patch_objective_started.emit()
	print("WaveManager: [OBJECTIVE] RETRIEVE CLEAN DIALING ROM FROM LEVEL 28 RESEARCH LAB!")

	# Spawn ambush squad in Round Hallway and corridor
	_spawn_sector_jaffa(Vector3(26.0, 0.0, 36.0), 3, true)
	_spawn_sector_jaffa(Vector3(20.0, 0.0, 20.0), 2, false)


func _on_patch_upload_completed() -> void:
	print("WaveManager: Dialing buffer patch verified! Outbound wormhole clearance granted!")
	all_waves_defeated.emit()


func _on_iris_servo_repaired() -> void:
	is_iris_repaired = true
	iris_repaired_event.emit()
	print("WaveManager: Iris manually engaged! Inbound matter transmission blocked!")
	if pending_column_spawns > 0:
		enemies_alive = maxi(0, enemies_alive - pending_column_spawns)
		pending_column_spawns = 0
		jaffa_count_changed.emit(enemies_alive, current_wave)
	_play_sfx("res://audio/sfx_iris_open.wav", 60.0)


func _play_klaxon() -> void:
	if DisplayServer.get_name() == "headless":
		return
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


func _play_sfx(path: String, max_dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 15.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


## Initiates Sprint 9 Foothold Climax Multi-Sector Incursion.
func trigger_climax_incursion() -> void:
	current_wave = 4
	target_activations = 4
	is_wave_active = true
	var total_count := 8
	enemies_alive = total_count
	wave_started.emit(current_wave, total_count)
	var sectors: Array[String] = ["GATE_ROOM", "ARMORY_HALLWAY", "LEVEL_27_CORRIDOR"]
	multi_sector_incursion_started.emit(sectors)
	print("WaveManager: MULTI-SECTOR CLIMAX INCURSION ENGAGED! Breaches across Gate Room and Level 27!")

	_spawn_wave_jaffa(4)
	_spawn_sector_jaffa(Vector3(3.0, 0.0, 39.0), 2, true)
	_spawn_sector_jaffa(Vector3(26.0, 5.5, 18.0), 2, true)


func _spawn_sector_jaffa(spawn_pos: Vector3, count: int, is_shock: bool = false) -> void:
	var scene_path: String = SHOCK_GUARD_SCENE_PATH if is_shock else JAFFA_SCENE_PATH
	var jaffa_scene := load(scene_path) as PackedScene
	if jaffa_scene == null or enemies_container == null:
		return

	for i in range(count):
		var offset := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
		var jaffa := jaffa_scene.instantiate() as JaffaAI
		jaffa.name = "%s_Sector_%d" % ["Shock" if is_shock else "Jaffa", randi() % 10000]
		jaffa.position = spawn_pos + offset
		enemies_container.add_child(jaffa, true)
		jaffa.jaffa_died.connect(_on_jaffa_killed.bind(jaffa))
