class_name SGCDialingConsole
extends DHDDialer
## Canonical SGC Sublevel 28 Gate Control & Dialing Supercomputer.
## Positioned in the Control Room Mezzanine overlooking the Gate Room.
## Operatives input 7-chevron sequences and GDO Iris codes here rather than an offworld DHD.
## Supports Goa'uld buffer encryption lockout, lab patch uploads, and Walter Harriman tannoy cues.

signal buffer_lockout_triggered()
signal buffer_restored()
signal patch_upload_progress(progress: float)
signal patch_upload_completed()

@export var is_buffer_corrupted: bool = false
@export var upload_time_required: float = 10.0

var current_upload_time: float = 0.0
var is_uploading_patch: bool = false
var uploader_player: PlayerController3D = null

@onready var crt_screen_center: MeshInstance3D = get_node_or_null("CRTScreenCenter")
@onready var status_light: OmniLight3D = get_node_or_null("StatusLight")


func _ready() -> void:
	super._ready()
	_update_screen_visuals()


func start_dialing(player: PlayerController3D) -> void:
	if is_buffer_corrupted:
		_trigger_error_feedback()
		print("SGCDialingConsole: [ALERT] DIALING BUFFER CORRUPTED! Clean ROM patch required from Level 28 Lab!")
		buffer_lockout_triggered.emit()
		return

	super.start_dialing(player)
	_update_screen_visuals()


func set_buffer_corrupted(corrupted: bool) -> void:
	is_buffer_corrupted = corrupted
	if is_buffer_corrupted:
		if active_dialer != null:
			cancel_dialing()
		buffer_lockout_triggered.emit()
	else:
		buffer_restored.emit()
	_update_screen_visuals()


func start_patch_upload(player: PlayerController3D) -> void:
	uploader_player = player
	is_uploading_patch = true
	current_upload_time = 0.0
	print("SGCDialingConsole: Dialing patch upload initiated by %s (10.0s defense required)..." % player.name)
	_update_screen_visuals()


func cancel_patch_upload() -> void:
	if is_uploading_patch:
		print("SGCDialingConsole: Patch upload aborted!")
		is_uploading_patch = false
		current_upload_time = 0.0
		uploader_player = null
		_update_screen_visuals()


func update_upload(delta: float) -> bool:
	if not is_uploading_patch:
		return false

	current_upload_time += delta
	var progress: float = clampf(current_upload_time / upload_time_required, 0.0, 1.0)
	patch_upload_progress.emit(progress)

	if current_upload_time >= upload_time_required:
		complete_patch_upload()
		return true
	return false


func complete_patch_upload() -> void:
	is_uploading_patch = false
	is_buffer_corrupted = false
	current_upload_time = 0.0
	uploader_player = null
	buffer_restored.emit()
	patch_upload_completed.emit()
	print("SGCDialingConsole: Dialing ROM patch applied! Goa'uld buffer lockout purged. System READY!")
	_play_sfx("res://audio/sfx_gdo_beep.wav", 30.0)
	_update_screen_visuals()


func _update_screen_visuals() -> void:
	if status_light == null:
		return

	if is_buffer_corrupted:
		status_light.light_color = Color(1.0, 0.15, 0.1)
		status_light.light_energy = 3.5
	elif is_uploading_patch:
		status_light.light_color = Color(0.2, 0.6, 1.0)
		status_light.light_energy = 4.0
	elif current_phase == DialPhase.CHEVRONS:
		status_light.light_color = Color(1.0, 0.6, 0.1)
		status_light.light_energy = 3.0
	elif current_phase == DialPhase.COMPLETE:
		status_light.light_color = Color(0.1, 0.9, 0.3)
		status_light.light_energy = 2.5
	else:
		status_light.light_color = Color(0.3, 0.8, 0.4)
		status_light.light_energy = 1.2
