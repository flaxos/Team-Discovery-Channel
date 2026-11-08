class_name DHDDialer
extends Node3D
## SGC Dialing Computer & DHD Pedestal.
## Handles Helldivers-style 7-Chevron directional glyph combos under fire,
## Tech Specialist perks, GDO Iris authorization, and Stargate network dispatch.

signal dialing_engaged(player: Node)
signal chevron_advanced(current_index: int, total_chevrons: int)
signal phase_changed(new_phase: DialPhase)
signal gdo_beat_advanced(current_beat: int, total_beats: int)
signal glyph_error()
signal gdo_verified()
signal sequence_completed()
signal dialing_cancelled()

const TOTAL_CHEVRONS: int = 7
const GDO_CODE_LENGTH: int = 4

enum DialPhase { INACTIVE, CHEVRONS, GDO_AUTH, COMPLETE }

var current_phase: DialPhase = DialPhase.INACTIVE
var active_dialer: PlayerController3D = null
var current_chevron_index: int = 0
var gdo_index: int = 0

var chevron_sequence: Array[String] = []
var gdo_sequence: Array[String] = []

@export var stargate_path: NodePath = NodePath("../Stargate")
var target_stargate: StargateRing = null
var denial_reason: String = ""
signal dialing_denied(reason: String)

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var console_light: OmniLight3D = $ConsoleLight if has_node("ConsoleLight") else null


func _ready() -> void:
	if has_node(stargate_path):
		target_stargate = get_node(stargate_path) as StargateRing

	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or current_phase not in [DialPhase.CHEVRONS, DialPhase.GDO_AUTH]:
		return
	if not is_instance_valid(active_dialer):
		_cancel_authoritative()
		return
	var health: HealthComponent = active_dialer.health_component
	if (health != null and (health.is_dead or health.is_downed or health.is_stunned)) or active_dialer.global_position.distance_to(global_position) > 5.0:
		_cancel_authoritative()


func _generate_sequences() -> void:
	var glyphs: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
	chevron_sequence.clear()
	for i in range(TOTAL_CHEVRONS):
		chevron_sequence.append(glyphs[randi() % glyphs.size()])

	gdo_sequence.clear()
	for i in range(GDO_CODE_LENGTH):
		gdo_sequence.append(glyphs[randi() % glyphs.size()])


func _wave_manager() -> Node:
	var gate: StargateRing = target_stargate
	return gate.get_parent().get_node_or_null("WaveManager") if gate != null else null


func start_dialing(player: PlayerController3D) -> void:
	if player == null:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_start_dialing.rpc_id(1, _player_path(player))
	else:
		request_start_dialing(_player_path(player))


func _player_path(player: PlayerController3D) -> NodePath:
	return target_stargate.get_parent().get_path_to(player) if target_stargate != null else get_path_to(player)


func _player_node(path: NodePath) -> PlayerController3D:
	return target_stargate.get_parent().get_node_or_null(path) as PlayerController3D if target_stargate != null else get_node_or_null(path) as PlayerController3D


func _request_player(path: NodePath) -> PlayerController3D:
	var player: PlayerController3D = _player_node(path)
	var sender: int = multiplayer.get_remote_sender_id()
	if player == null or (sender != 0 and player.get_multiplayer_authority() != sender):
		return null
	return player


@rpc("any_peer", "call_local", "reliable")
func request_start_dialing(player_path: NodePath) -> void:
	if not multiplayer.is_server() or current_phase != DialPhase.INACTIVE:
		return
	var player: PlayerController3D = _request_player(player_path)
	if player == null:
		return
	var manager: Node = _wave_manager()
	if manager != null and not manager.request_outbound():
		denial_reason = manager.dialing_block_reason()
		if multiplayer.has_multiplayer_peer():
			sync_denial.rpc(denial_reason)
		else:
			sync_denial(denial_reason)
		return
	if manager == null and target_stargate != null and not target_stargate.reserve_connection(false):
		sync_denial("GATE BUSY")
		return
	active_dialer = player
	_generate_sequences()
	current_phase = DialPhase.CHEVRONS
	current_chevron_index = 0
	gdo_index = 0

	if console_light != null:
		console_light.light_energy = 3.0
		console_light.light_color = Color(1.0, 0.6, 0.1)

	dialing_engaged.emit(player)
	print("DHD: Operative %s engaged SGC Dialing Console!" % player.name)


	_broadcast_state()


@rpc("authority", "call_local", "reliable")
func sync_denial(reason: String) -> void:
	denial_reason = reason
	dialing_denied.emit(reason)


func _broadcast_state() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var path: NodePath = _player_path(active_dialer) if is_instance_valid(active_dialer) else NodePath()
		sync_dial_state.rpc(path, current_phase, current_chevron_index, gdo_index, chevron_sequence, gdo_sequence)


@rpc("authority", "call_remote", "reliable")
func sync_dial_state(player_path: NodePath, phase: int, chevron: int, beat: int, glyphs: Array[String], code: Array[String]) -> void:
	var previous: DialPhase = current_phase
	active_dialer = _player_node(player_path) if not player_path.is_empty() else null
	current_phase = phase as DialPhase
	current_chevron_index = chevron
	gdo_index = beat
	chevron_sequence = glyphs
	gdo_sequence = code
	if previous == DialPhase.INACTIVE and current_phase == DialPhase.CHEVRONS:
		dialing_engaged.emit(active_dialer)
	if current_phase == DialPhase.INACTIVE:
		dialing_cancelled.emit()
	phase_changed.emit(current_phase)
	chevron_advanced.emit(chevron, TOTAL_CHEVRONS)
	gdo_beat_advanced.emit(beat, GDO_CODE_LENGTH)
	if current_phase == DialPhase.COMPLETE and previous != DialPhase.COMPLETE:
		sequence_completed.emit()


func input_glyph(direction: String) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_input_glyph.rpc_id(1, direction)
		return false
	var accepted: bool = _apply_glyph(direction)
	_broadcast_state()
	return accepted


@rpc("any_peer", "call_local", "reliable")
func request_input_glyph(direction: String) -> void:
	if not multiplayer.is_server() or not is_instance_valid(active_dialer):
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and active_dialer.get_multiplayer_authority() != sender:
		return
	_apply_glyph(direction)
	_broadcast_state()


func _apply_glyph(direction: String) -> bool:
	if current_phase == DialPhase.CHEVRONS:
		var expected := chevron_sequence[current_chevron_index]
		if direction == expected:
			current_chevron_index += 1
			print("DHD: Glyph '%s' accepted. Chevron %d locked." % [direction, current_chevron_index])

			# Inform target Stargate
			if target_stargate != null:
				target_stargate.lock_chevron(current_chevron_index)

			chevron_advanced.emit(current_chevron_index, TOTAL_CHEVRONS)

			if current_chevron_index >= TOTAL_CHEVRONS:
				current_phase = DialPhase.GDO_AUTH
				phase_changed.emit(current_phase)
				print("DHD: 7 Chevrons locked! Awaiting 4-beat GDO Iris IDC code...")

			return true
		else:
			print("DHD: Incorrect glyph '%s' (expected '%s')! SEQUENCE RESET!" % [direction, expected])
			current_chevron_index = 0
			if target_stargate != null:
				target_stargate.reset_chevrons()
			_trigger_error_feedback()
			glyph_error.emit()
			chevron_advanced.emit(0, TOTAL_CHEVRONS)
			return false

	elif current_phase == DialPhase.GDO_AUTH:
		var expected_gdo := gdo_sequence[gdo_index]
		if direction == expected_gdo:
			gdo_index += 1
			print("DHD: GDO Beat %d/%d accepted." % [gdo_index, GDO_CODE_LENGTH])
			_play_sfx("res://audio/sfx_gdo_beep.wav", 25.0)
			gdo_beat_advanced.emit(gdo_index, GDO_CODE_LENGTH)

			if gdo_index >= GDO_CODE_LENGTH:
				current_phase = DialPhase.COMPLETE
				phase_changed.emit(current_phase)
				gdo_verified.emit()
				sequence_completed.emit()
				if target_stargate != null:
					target_stargate.authorize_extraction()
				active_dialer = null # Release operative movement so they can sprint to the gate!
				print("DHD: SGC IRIS OPENED! WORMHOLE STABILIZED FOR EXTRACTION!")
				_play_sfx("res://audio/sfx_iris_open.wav", 40.0)
				if console_light != null:
					console_light.light_color = Color(0.1, 0.85, 0.4)
			return true
		else:
			print("DHD: GDO code mismatch! (expected '%s')! RESETTING GDO CODE!" % expected_gdo)
			gdo_index = 0
			_trigger_error_feedback()
			glyph_error.emit()
			gdo_beat_advanced.emit(0, GDO_CODE_LENGTH)
			return false

	return false


func _play_sfx(path: String, max_dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _trigger_error_feedback() -> void:
	if console_light != null:
		console_light.light_color = Color(1.0, 0.1, 0.1)
		console_light.light_energy = 4.0
		var tween := console_light.create_tween()
		tween.tween_property(console_light, "light_color", Color(1.0, 0.6, 0.1), 0.35)

	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://audio/sfx_error_buzz.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_error_buzz.wav")
		audio.max_distance = 35.0
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func cancel_dialing() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_cancel_dialing.rpc_id(1)
		return
	_cancel_authoritative()


@rpc("any_peer", "call_local", "reliable")
func request_cancel_dialing() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and (active_dialer == null or active_dialer.get_multiplayer_authority() != sender):
		return
	_cancel_authoritative()


func _cancel_authoritative() -> void:
	if current_phase == DialPhase.COMPLETE:
		return
	if target_stargate != null and target_stargate.direction == StargateRing.GateDirection.OUTBOUND:
		target_stargate.close_wormhole()
	var manager: Node = _wave_manager()
	if manager != null:
		manager.release_outbound()
	current_phase = DialPhase.INACTIVE
	active_dialer = null
	if console_light != null:
		console_light.light_energy = 0.5
		console_light.light_color = Color(0.7, 0.7, 0.7)
	dialing_cancelled.emit()
	_broadcast_state()


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		print("DHD: Operative in range. Press [E] to dial Stargate.")


func _on_body_exited(body: Node) -> void:
	if body == active_dialer:
		cancel_dialing()
