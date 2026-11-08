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

@export var difficulty: DifficultyTier = DifficultyTier.EASY
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
var completed_incursions: int = 0
var incursion_established: bool = false
var computer_upgraded: bool = false
var iris_repaired_under_fire: bool = false
var defense_started: bool = false
var outbound_reserved: bool = false
var mission_ended: bool = false
var sequence_token: int = 0
var sequence_active: bool = false
var sequence_run_token: int = 0
var sequence_chevron: int = 0
var sequence_wait: float = 0.0
var completion_announced: bool = false
var snapshot_timer: float = 0.0
var counted_deaths: Dictionary = {}
signal objective_status_changed(text: String)


@export var rank_spawn_interval: float = 2.0
var pending_column_spawns: int = 0
var column_stream_timer: float = 0.0
var current_rank_index: int = 0

@onready var enemies_container: Node3D = get_node_or_null("../Enemies")
@onready var gate_spawn_marker: Marker3D = get_node_or_null("../GateSpawnMarker")
@onready var transport_rings: TransportRings = get_node_or_null("../TransportRings") as TransportRings


var hostile_gate_activation_enabled: bool = true

func _ready() -> void:
	hostile_gate_activation_enabled = get_parent().get("mission_id") != SGCNetworkManager.MISSION_SGC_UAT
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and net.get("mission_difficulty") != null:
		difficulty = clampi(int(net.get("mission_difficulty")), 0, 2) as DifficultyTier
	_configure_difficulty()
	var gate: StargateRing = _gate()
	if gate != null:
		gate.wormhole_closed.connect(_on_gate_closed)

	# Connect Iris Servo Housing if present in Gate Room
	var iris_servo := get_node_or_null("../IrisServoHousing") as IrisServoHousingScript
	if iris_servo != null:
		iris_servo.iris_repaired.connect(_on_iris_servo_repaired)

	# Connect Dialing Console patch upload signal
	var dialer := _dialer()
	if dialer != null:
		dialer.patch_upload_completed.connect(_on_patch_upload_completed)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_mission_snapshot.rpc_id(1)


func set_difficulty(tier: DifficultyTier) -> void:
	difficulty = tier
	_configure_difficulty()


func _configure_difficulty() -> void:
	# All tiers require three complete incursions; objectives add pressure, not a wave-one shortcut.
	target_activations = 3
	max_waves = 3
	var dialer := _dialer()
	if dialer != null:
		dialer.set_buffer_corrupted(difficulty != DifficultyTier.EASY and not computer_upgraded)


func _gate() -> StargateRing:
	return get_node_or_null("../Stargate") as StargateRing


func _dialer() -> SGCDialingConsoleScript:
	return get_parent().find_child("SGCDialingConsole", true, false) as SGCDialingConsoleScript


func requirements_met() -> bool:
	return completed_incursions >= target_activations and (difficulty == DifficultyTier.EASY or computer_upgraded) and (difficulty != DifficultyTier.HARD or iris_repaired_under_fire)


func dialing_block_reason() -> String:
	if not hostile_gate_activation_enabled: return "UAT BASE: EXPLORE SUBLEVELS 28 / 27 / 26 — NO HOSTILE ACTIVATION"
	if mission_ended:
		return "MISSION ENDED"
	if completed_incursions < target_activations:
		return "SURVIVE INCURSIONS: %d / %d CLEARED" % [completed_incursions, target_activations]
	if difficulty != DifficultyTier.EASY and not computer_upgraded:
		return "UPGRADE DIALING COMPUTER: RETRIEVE LAB ROM AND UPLOAD AT CONTROL ROOM"
	if difficulty == DifficultyTier.HARD and not iris_repaired_under_fire:
		return "HARD MODE: REPAIR IRIS DURING AN ACTIVE INCOMING BREACH"
	var gate: StargateRing = _gate()
	if is_wave_active or is_wormhole_open or (gate != null and gate.current_state != StargateRing.GateState.INACTIVE):
		return "GATE BUSY: CLEAR THE CURRENT INCOMING INCURSION"
	return ""


func request_outbound() -> bool:
	if not hostile_gate_activation_enabled: return false
	if not multiplayer.is_server() or not dialing_block_reason().is_empty():
		objective_status_changed.emit(dialing_block_reason())
		return false
	var gate: StargateRing = _gate()
	if gate == null or not gate.reserve_connection(false):
		return false
	sequence_token += 1
	outbound_reserved = true
	is_intermission = false
	pending_column_spawns = 0
	return true


func release_outbound() -> void:
	if not multiplayer.is_server() or not outbound_reserved:
		return
	outbound_reserved = false
	if not mission_ended:
		is_intermission = true
		intermission_timer = inter_gate_recharge_s


func end_mission() -> void:
	mission_ended = true
	sequence_active = false
	sequence_token += 1
	pending_column_spawns = 0
	is_wave_active = false
	is_wormhole_open = false
	is_intermission = false
	var gate: StargateRing = _gate()
	if gate != null and multiplayer.is_server():
		gate.close_wormhole()
	_broadcast_mission_snapshot()


func start_wave_defense() -> void:
	if not hostile_gate_activation_enabled: return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	current_wave = 0
	counted_deaths.clear()
	completed_incursions = 0
	defense_started = true
	mission_ended = false
	_configure_difficulty()
	start_next_wave()


func _physics_process(delta: float) -> void:
	if not hostile_gate_activation_enabled: return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if mission_ended:
		return
	snapshot_timer -= delta
	if snapshot_timer <= 0.0:
		snapshot_timer = 0.25
		_broadcast_mission_snapshot()
	if mission_ended or outbound_reserved:
		return

	_advance_inbound_sequence(delta)

	# Inbound Wormhole 38-second Countdown Engine
	if is_wormhole_open:
		if not _inbound_gate_active():
			_collapse_inbound_wormhole()
			return
		inbound_wormhole_timer -= delta
		wormhole_timer_tick.emit(maxf(0.0, inbound_wormhole_timer), wormhole_duration_s)

		if inbound_wormhole_timer <= 0.0:
			_collapse_inbound_wormhole()
			return

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
	if not hostile_gate_activation_enabled: return
	if not multiplayer.is_server() or mission_ended or outbound_reserved or is_wave_active:
		return
	var gate: StargateRing = _gate()
	if gate == null or not gate.reserve_connection(true):
		return
	current_wave += 1
	incursion_established = false
	is_iris_repaired = false
	var servo: Node = get_node_or_null("../IrisServoHousing")
	if servo != null and servo.has_method("reset_for_breach"):
		servo.reset_for_breach()
	is_wave_active = true
	is_intermission = false
	stream_spawn_timer = stream_spawn_interval
	column_stream_timer = 0.0
	current_rank_index = 0
	pending_column_spawns = 0
	enemies_alive = 0
	wave_started.emit(current_wave, 4 + mini(current_wave - 1, 4) * 2)
	_play_klaxon()
	sequence_token += 1
	_execute_inbound_gate_sequence(sequence_token)


func _execute_inbound_gate_sequence(token: int = -1) -> void:
	sequence_run_token = sequence_token if token < 0 else token
	sequence_active = true
	sequence_chevron = 0
	sequence_wait = 0.2
	chevron_sequence_started.emit()


func _advance_inbound_sequence(delta: float) -> void:
	if not sequence_active:
		return
	if not _sequence_valid(sequence_run_token):
		sequence_active = false
		return
	var gate: StargateRing = _gate()
	if sequence_chevron < 7:
		sequence_wait -= delta
		if sequence_wait <= 0.0:
			sequence_chevron += 1
			sequence_wait = 0.2
			gate.lock_chevron(sequence_chevron)
		return
	if gate.current_state != StargateRing.GateState.ACTIVE:
		return
	sequence_active = false
	if not is_iris_repaired:
		iris_malfunction_declared.emit()
	is_wormhole_open = true
	incursion_established = true
	inbound_wormhole_timer = wormhole_duration_s
	wormhole_state_changed.emit(true, "INBOUND_ACTIVE")
	var count: int = 4 + mini(current_wave - 1, 4) * 2
	enemies_alive += count
	_spawn_wave_jaffa(count)
	jaffa_count_changed.emit(enemies_alive, current_wave)


func _sequence_valid(token: int) -> bool:
	var gate: StargateRing = _gate()
	return token == sequence_token and not mission_ended and not outbound_reserved and is_wave_active and gate != null and gate.direction == StargateRing.GateDirection.INBOUND


func _inbound_gate_active() -> bool:
	var gate: StargateRing = _gate()
	return not mission_ended and not outbound_reserved and gate != null and gate.direction == StargateRing.GateDirection.INBOUND and gate.current_state == StargateRing.GateState.ACTIVE


func _on_gate_closed() -> void:
	if is_wave_active:
		sequence_token += 1
		is_wormhole_open = false
		_clear_pending_spawns()
		if enemies_alive == 0:
			_on_all_incursion_enemies_cleared()


func _clear_pending_spawns() -> void:
	if pending_column_spawns > 0:
		enemies_alive = maxi(0, enemies_alive - pending_column_spawns)
		pending_column_spawns = 0
		jaffa_count_changed.emit(enemies_alive, current_wave)


func _collapse_inbound_wormhole() -> void:
	if not multiplayer.is_server():
		return
	sequence_token += 1
	is_wormhole_open = false
	wormhole_state_changed.emit(false, "DISENGAGED")
	_clear_pending_spawns()
	var gate: StargateRing = _gate()
	if gate != null and gate.direction == StargateRing.GateDirection.INBOUND:
		gate.close_wormhole()
	if enemies_alive == 0 and is_wave_active:
		_on_all_incursion_enemies_cleared()


func _spawn_ramp_reinforcements(count: int) -> void:
	if not is_wave_active or not is_wormhole_open or not _inbound_gate_active() or is_iris_repaired:
		return
	enemies_alive += count
	jaffa_count_changed.emit(enemies_alive, current_wave)
	print("WaveManager: Reinforcements streaming through event horizon (+%d Jaffa)!" % count)
	_spawn_wave_jaffa(count)


func _spawn_wave_jaffa(ramp_count: int) -> void:
	if not is_wormhole_open or not _inbound_gate_active() or is_iris_repaired:
		return
	pending_column_spawns += ramp_count
	# Immediately spawn the first rank upon event horizon activation
	if column_stream_timer <= 0.0:
		_spawn_next_column_rank()
		column_stream_timer = rank_spawn_interval


func _spawn_next_column_rank() -> void:
	if pending_column_spawns <= 0 or not is_wormhole_open or not _inbound_gate_active() or is_iris_repaired:
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
	if not multiplayer.is_server() or _jaffa == null or counted_deaths.has(_jaffa.get_instance_id()):
		return
	counted_deaths[_jaffa.get_instance_id()] = true
	enemies_alive = maxi(0, enemies_alive - 1)
	jaffa_count_changed.emit(enemies_alive, current_wave)
	print("WaveManager: Enemy eliminated! %d remaining in Incursion %d." % [enemies_alive, current_wave])

	if enemies_alive == 0 and not is_wormhole_open and is_wave_active:
		_on_all_incursion_enemies_cleared()


func _on_all_incursion_enemies_cleared() -> void:
	if not is_wave_active:
		return
	is_wave_active = false
	if incursion_established:
		completed_incursions += 1
	wave_cleared.emit(current_wave)
	_evaluate_mission_completion()
	# Incoming gates keep competing during resupply, even after the minimum wave objective.
	is_intermission = true
	intermission_timer = inter_gate_recharge_s


func _evaluate_mission_completion() -> void:
	if requirements_met():
		if not completion_announced:
			completion_announced = true
			all_waves_defeated.emit()
		objective_status_changed.emit("OUTBOUND READY: DIAL BEFORE THE NEXT INCOMING ACTIVATION")
	else:
		objective_status_changed.emit(dialing_block_reason())


func _trigger_hard_mode_buffer_lockout() -> void:
	var dialer := _dialer()
	if dialer != null:
		dialer.set_buffer_corrupted(true)
	lab_patch_objective_started.emit()


func _on_patch_upload_completed() -> void:
	if not multiplayer.is_server():
		return
	computer_upgraded = true
	_evaluate_mission_completion()


func _on_iris_servo_repaired() -> void:
	if not multiplayer.is_server():
		return
	iris_repaired_under_fire = iris_repaired_under_fire or (is_wormhole_open and _inbound_gate_active())
	is_iris_repaired = true
	iris_repaired_event.emit()
	print("WaveManager: Iris manually engaged! Inbound matter transmission blocked!")
	if pending_column_spawns > 0:
		enemies_alive = maxi(0, enemies_alive - pending_column_spawns)
		pending_column_spawns = 0
		jaffa_count_changed.emit(enemies_alive, current_wave)
	_play_sfx("res://audio/sfx_iris_open.wav", 60.0)
	_evaluate_mission_completion()


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
	if not multiplayer.is_server() or mission_ended:
		return
	current_wave = 4
	target_activations = 4
	is_wave_active = true
	var total_count := 8
	enemies_alive = total_count
	wave_started.emit(current_wave, total_count)
	var sectors: Array[String] = ["GATE_ROOM", "ARMORY_HALLWAY", "LEVEL_27_CORRIDOR"]
	multi_sector_incursion_started.emit(sectors)
	print("WaveManager: MULTI-SECTOR CLIMAX INCURSION ENGAGED! Breaches across Gate Room and Level 27!")

	# This multi-sector breach must not depend on an already-open inbound gate.
	_spawn_sector_jaffa(Vector3(0.0, 0.0, -6.0), 4, true)
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


func _broadcast_mission_snapshot(peer: int = 0) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var values: Array = [current_wave, completed_incursions, enemies_alive, is_wave_active, is_wormhole_open, is_intermission, intermission_timer, inbound_wormhole_timer, computer_upgraded, iris_repaired_under_fire, outbound_reserved, mission_ended, is_iris_repaired]
	if peer > 0:
		sync_mission_snapshot.rpc_id(peer, values)
	else:
		sync_mission_snapshot.rpc(values)


@rpc("any_peer", "call_remote", "reliable")
func request_mission_snapshot() -> void:
	if multiplayer.is_server():
		_broadcast_mission_snapshot(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func sync_mission_snapshot(values: Array) -> void:
	if values.size() != 13:
		return
	var previous_wave: int = current_wave
	var previous_count: int = enemies_alive
	var previous_completed: int = completed_incursions
	current_wave = values[0]
	completed_incursions = values[1]
	enemies_alive = values[2]
	is_wave_active = values[3]
	is_wormhole_open = values[4]
	is_intermission = values[5]
	intermission_timer = values[6]
	inbound_wormhole_timer = values[7]
	computer_upgraded = values[8]
	iris_repaired_under_fire = values[9]
	outbound_reserved = values[10]
	mission_ended = values[11]
	is_iris_repaired = values[12]
	if current_wave != previous_wave:
		wave_started.emit(current_wave, enemies_alive)
	if enemies_alive != previous_count:
		jaffa_count_changed.emit(enemies_alive, current_wave)
	if completed_incursions > previous_completed:
		wave_cleared.emit(current_wave)
	if is_wormhole_open:
		wormhole_timer_tick.emit(inbound_wormhole_timer, wormhole_duration_s)
	elif is_intermission:
		intermission_tick.emit(int(ceil(intermission_timer)))
	else:
		objective_status_changed.emit(dialing_block_reason())
