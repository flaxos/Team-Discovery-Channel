class_name IrisServoHousing
extends Node3D
## SGC Gate Room Manual Iris Servo Housing.
## Tactical sub-mission: Segmented 3-Stage manual Iris mechanical override under fire:
##  Stage 1 (33%): Realign Trinium Drive Gears
##  Stage 2 (66%): Reset High-Pressure Hydraulic Bypass
##  Stage 3 (100%): Engage Primary Iris Mechanical Lock
## Completed stage checkpoints persist across combat firefights and ducking into cover.

signal repair_progress(progress: float)
signal stage_completed(stage_num: int, stage_name: String)
signal iris_repaired()

const STAGE_NAMES: Array[String] = [
	"Realign Trinium Drive Gears",
	"Reset Hydraulic Bypass",
	"Engage Mechanical Iris Lock"
]
const STAGE_DURATION_S: float = 2.5
const TOTAL_STAGES: int = 3

@export var is_repaired: bool = false
var completed_stages: int = 0
var current_stage: int = 1
var stage_repair_time: float = 0.0
var is_repairing: bool = false
var repairer_player: PlayerController3D = null

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var servo_light: OmniLight3D = $ServoLight if has_node("ServoLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _room() -> Node:
	return get_parent()


func reset_for_breach() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		sync_reset_for_breach.rpc()
	else:
		sync_reset_for_breach()


@rpc("authority", "call_local", "reliable")
func sync_reset_for_breach() -> void:
	is_repaired = false
	completed_stages = 0
	current_stage = 1
	stage_repair_time = 0.0
	is_repairing = false
	repairer_player = null
	if prompt_label != null:
		prompt_label.text = "IRIS JAMMED: REPAIR DURING INCOMING BREACH"
	if servo_light != null:
		servo_light.light_color = Color(1.0, 0.3, 0.1)


func _repair_allowed() -> bool:
	var manager: Node = _room().get_node_or_null("WaveManager")
	return manager == null or int(manager.difficulty) != 2 or (manager.is_wormhole_open and manager._inbound_gate_active())


func start_repair(player: PlayerController3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_repair.rpc_id(1, _room().get_path_to(player))
		return
	_begin_repair(player)


@rpc("any_peer", "call_local", "reliable")
func request_repair(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var player: PlayerController3D = _room().get_node_or_null(player_path) as PlayerController3D
	var sender: int = multiplayer.get_remote_sender_id()
	if player != null and (sender == 0 or player.get_multiplayer_authority() == sender):
		_begin_repair(player)


func _begin_repair(player: PlayerController3D) -> void:
	if not _repair_allowed():
		return
	if is_repaired:
		return
	repairer_player = player
	is_repairing = true
	stage_repair_time = 0.0
	print("IrisServoHousing: Operative %s started manual Iris repair [Stage %d: %s]..." % [
		player.name,
		current_stage,
		STAGE_NAMES[current_stage - 1]
	])
	_broadcast_repair()


func cancel_repair() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_cancel_repair.rpc_id(1)
		return
	_cancel_repair()


@rpc("any_peer", "call_local", "reliable")
func request_cancel_repair() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0 or (repairer_player != null and repairer_player.get_multiplayer_authority() == sender):
		_cancel_repair()


func _cancel_repair() -> void:
	if is_repairing:
		print("IrisServoHousing: Iris repair paused at Checkpoint %d/3! Progress saved." % completed_stages)
		is_repairing = false
		stage_repair_time = 0.0
		repairer_player = null
		_broadcast_repair()


func update_repair(delta: float) -> bool:
	if not multiplayer.is_server() or not is_repairing or is_repaired:
		return false

	if not _repair_allowed():
		_cancel_repair()
		return false
	stage_repair_time += delta
	var current_stage_fraction: float = clampf(stage_repair_time / STAGE_DURATION_S, 0.0, 1.0)
	var total_progress: float = (float(completed_stages) + current_stage_fraction) / float(TOTAL_STAGES)
	repair_progress.emit(total_progress)
	_broadcast_repair()

	if stage_repair_time >= STAGE_DURATION_S:
		completed_stages = current_stage
		stage_completed.emit(completed_stages, STAGE_NAMES[completed_stages - 1])
		print("IrisServoHousing: STAGE %d COMPLETED: %s!" % [completed_stages, STAGE_NAMES[completed_stages - 1]])

		if completed_stages >= TOTAL_STAGES:
			complete_repair()
			return true
		else:
			current_stage = completed_stages + 1
			stage_repair_time = 0.0
			if prompt_label != null:
				prompt_label.text = _bindings().format_prompt("[E] STAGE %d: %s" % [current_stage, STAGE_NAMES[current_stage - 1].to_upper()])
	return false


func complete_repair() -> void:
	if not multiplayer.is_server() or not _repair_allowed():
		return
	is_repairing = false
	is_repaired = true
	completed_stages = 3
	stage_repair_time = 0.0
	repairer_player = null
	repair_progress.emit(1.0)
	iris_repaired.emit()
	print("IrisServoHousing: TRINIUM IRIS OVERRIDE ENGAGED! Iris snapped SHUT! Gate room secured!")

	if servo_light != null:
		servo_light.light_color = Color(0.1, 0.9, 0.3)
		servo_light.light_energy = 3.0
	if prompt_label != null:
		prompt_label.text = "IRIS SECURED (CLOSED 100%)"
		prompt_label.modulate = Color(0.2, 0.95, 0.4)

	_play_sfx("res://audio/sfx_iris_open.wav", 40.0)
	_broadcast_repair()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not is_repairing:
		return
	if not is_instance_valid(repairer_player):
		_cancel_repair()
		return
	var health: HealthComponent = repairer_player.health_component
	if health != null and (health.is_dead or health.is_downed or health.is_stunned):
		_cancel_repair()
		return
	if repairer_player.global_position.distance_to(global_position) > 4.5:
		_cancel_repair()
		return
	# Host controller drives its own channel; remote channels advance on the server.
	if not repairer_player.is_local_authority:
		update_repair(delta)


func _broadcast_repair() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var path: NodePath = _room().get_path_to(repairer_player) if is_instance_valid(repairer_player) else NodePath()
		sync_repair.rpc(path, is_repairing, is_repaired, completed_stages, current_stage, stage_repair_time)


@rpc("authority", "call_remote", "reliable")
func sync_repair(player_path: NodePath, repairing: bool, repaired: bool, completed: int, stage: int, elapsed: float) -> void:
	var previous: int = completed_stages
	var previously_repaired: bool = is_repaired
	repairer_player = _room().get_node_or_null(player_path) as PlayerController3D if not player_path.is_empty() else null
	is_repairing = repairing
	is_repaired = repaired
	completed_stages = completed
	current_stage = stage
	stage_repair_time = elapsed
	if completed > previous:
		stage_completed.emit(completed, STAGE_NAMES[completed - 1])
	if repaired and not previously_repaired:
		iris_repaired.emit()


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_repaired and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = _bindings().format_prompt("[E] STAGE %d/3: %s" % [current_stage, STAGE_NAMES[current_stage - 1].to_upper()])


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_repaired and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "IRIS SERVO HOUSING [%d/3 SAVED]" % completed_stages


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


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
