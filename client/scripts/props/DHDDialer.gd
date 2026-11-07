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

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var console_light: OmniLight3D = $ConsoleLight if has_node("ConsoleLight") else null


func _ready() -> void:
	if has_node(stargate_path):
		target_stargate = get_node(stargate_path) as StargateRing

	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _generate_sequences() -> void:
	var glyphs: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
	chevron_sequence.clear()
	for i in range(TOTAL_CHEVRONS):
		chevron_sequence.append(glyphs[randi() % glyphs.size()])

	gdo_sequence.clear()
	for i in range(GDO_CODE_LENGTH):
		gdo_sequence.append(glyphs[randi() % glyphs.size()])


func start_dialing(player: PlayerController3D) -> void:
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


func input_glyph(direction: String) -> bool:
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

	if ResourceLoader.exists("res://audio/sfx_error_buzz.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_error_buzz.wav")
		audio.max_distance = 35.0
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func cancel_dialing() -> void:
	current_phase = DialPhase.INACTIVE
	active_dialer = null
	if console_light != null:
		console_light.light_energy = 0.5
		console_light.light_color = Color(0.7, 0.7, 0.7)
	dialing_cancelled.emit()


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		print("DHD: Operative in range. Press [E] to dial Stargate.")


func _on_body_exited(body: Node) -> void:
	if body == active_dialer:
		cancel_dialing()
