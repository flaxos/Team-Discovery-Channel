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
	if multiplayer.is_server() and is_buffer_corrupted:
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
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_patch_upload.rpc_id(1, _player_path(player))
		return
	_begin_patch_upload(player)


@rpc("any_peer", "call_local", "reliable")
func request_patch_upload(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var player: PlayerController3D = _request_player(player_path)
	if player != null:
		_begin_patch_upload(player)


func _begin_patch_upload(player: PlayerController3D) -> void:
	if not is_buffer_corrupted or not player.is_carrying_patch_rom or is_uploading_patch:
		return
	uploader_player = player
	is_uploading_patch = true
	current_upload_time = 0.0
	print("SGCDialingConsole: Dialing patch upload initiated by %s (10.0s defense required)..." % player.name)
	_update_screen_visuals()
	_broadcast_upload()


func cancel_patch_upload() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_cancel_upload.rpc_id(1)
		return
	_cancel_upload()


@rpc("any_peer", "call_local", "reliable")
func request_cancel_upload() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0 or (uploader_player != null and uploader_player.get_multiplayer_authority() == sender):
		_cancel_upload()


func _cancel_upload() -> void:
	if is_uploading_patch:
		print("SGCDialingConsole: Patch upload aborted!")
		is_uploading_patch = false
		current_upload_time = 0.0
		uploader_player = null
		_update_screen_visuals()
		_broadcast_upload()


func update_upload(delta: float) -> bool:
	if not multiplayer.is_server() or not is_uploading_patch:
		return false

	current_upload_time += delta
	var progress: float = clampf(current_upload_time / upload_time_required, 0.0, 1.0)
	patch_upload_progress.emit(progress)
	_broadcast_upload()

	if current_upload_time >= upload_time_required:
		complete_patch_upload()
		return true
	return false


func complete_patch_upload() -> void:
	if not multiplayer.is_server():
		return
	if is_instance_valid(uploader_player):
		uploader_player.is_carrying_patch_rom = false
	is_uploading_patch = false
	is_buffer_corrupted = false
	current_upload_time = 0.0
	uploader_player = null
	buffer_restored.emit()
	patch_upload_completed.emit()
	print("SGCDialingConsole: Dialing ROM patch applied! Goa'uld buffer lockout purged. System READY!")
	_play_sfx("res://audio/sfx_gdo_beep.wav", 30.0)
	_update_screen_visuals()
	_broadcast_upload()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not multiplayer.is_server() or not is_uploading_patch:
		return
	if not is_instance_valid(uploader_player):
		_cancel_upload()
		return
	var health: HealthComponent = uploader_player.health_component
	if health != null and (health.is_dead or health.is_downed or health.is_stunned):
		_cancel_upload()
		return
	if uploader_player.global_position.distance_to(global_position) > 4.5:
		_cancel_upload()
		return
	# Host controller drives its own channel; remote channels advance on the server.
	if not uploader_player.is_local_authority:
		update_upload(delta)


func _broadcast_upload() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var path: NodePath = _player_path(uploader_player) if is_instance_valid(uploader_player) else NodePath()
		sync_upload.rpc(path, is_uploading_patch, current_upload_time, is_buffer_corrupted)


@rpc("authority", "call_remote", "reliable")
func sync_upload(player_path: NodePath, uploading: bool, elapsed: float, corrupted: bool) -> void:
	var was_corrupted: bool = is_buffer_corrupted
	uploader_player = _player_node(player_path) if not player_path.is_empty() else null
	is_uploading_patch = uploading
	current_upload_time = elapsed
	is_buffer_corrupted = corrupted
	patch_upload_progress.emit(clampf(elapsed / upload_time_required, 0.0, 1.0))
	if was_corrupted and not corrupted:
		buffer_restored.emit()
		patch_upload_completed.emit()
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


func request_abort_mission() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_abort_mission.rpc_id(1)
		return
	_execute_abort()


@rpc("any_peer", "call_local", "reliable")
func server_abort_mission() -> void:
	if multiplayer.is_server():
		_execute_abort()


func _execute_abort() -> void:
	var world: Node = MissionWorld.of(self)
	if world != null:
		var sess: Variant = world.get("session")
		if sess != null and sess.has_method("abort_mission"):
			print("SGCDialingConsole: [ABORT] Mission aborted by SGC Control Mezzanine!")
			sess.call(&"abort_mission")
