class_name SGCElevator
extends Node3D
## SGC Hydraulic Freight Elevator connecting Sublevel 28 and Sublevel 27.
## Provides automated vertical transit, animated sliding doors, multiplayer RPC synchronization,
## dynamic floor indicator displays, and arrival audio cues.

signal elevator_started(from_floor: int, to_floor: int)
signal elevator_arrived(floor_num: int)

enum ElevatorState { AT_28, MOVING_UP, AT_27, MOVING_DOWN }

const FLOOR_28_Y: float = 0.0
const FLOOR_27_Y: float = 5.5
const TRANSIT_DURATION: float = 3.0

const DOOR_CLOSED_LEFT_X: float = -0.8
const DOOR_CLOSED_RIGHT_X: float = 0.8
const DOOR_OPEN_OFFSET: float = 1.6
const DOOR_OPEN_LEFT_X: float = -2.4
const DOOR_OPEN_RIGHT_X: float = 2.4

@export var current_floor: int = 28
var state: ElevatorState = ElevatorState.AT_28
var is_moving: bool = false
var riders: Array[CharacterBody3D] = []

@onready var cabin: AnimatableBody3D = $Cabin if has_node("Cabin") else null
@onready var door_left: Node3D = $Cabin/DoorLeft if has_node("Cabin/DoorLeft") else null
@onready var door_right: Node3D = $Cabin/DoorRight if has_node("Cabin/DoorRight") else null
@onready var indicator_label: Label3D = $Cabin/IndicatorLabel if has_node("Cabin/IndicatorLabel") else null
@onready var cabin_light: OmniLight3D = $Cabin/CabinLight if has_node("Cabin/CabinLight") else null
@onready var ride_area: Area3D = $Cabin/RideArea if has_node("Cabin/RideArea") else null
@onready var call_pedestal_28: Node3D = $CallPedestal28 if has_node("CallPedestal28") else null
@onready var call_pedestal_27: Node3D = $CallPedestal27 if has_node("CallPedestal27") else null
@onready var pedestal_light_28: OmniLight3D = $CallPedestal28/PedestalLight if has_node("CallPedestal28/PedestalLight") else null
@onready var pedestal_light_27: OmniLight3D = $CallPedestal27/PedestalLight if has_node("CallPedestal27/PedestalLight") else null


func _ready() -> void:
	if ride_area != null:
		ride_area.body_entered.connect(_on_ride_area_entered)
		ride_area.body_exited.connect(_on_ride_area_exited)

	_update_floor_indicator(current_floor)
	if cabin != null:
		cabin.position.y = FLOOR_27_Y if current_floor == 27 else FLOOR_28_Y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _can_interact_with_elevator():
			_handle_interaction()


func _can_interact_with_elevator() -> bool:
	if is_moving:
		return false
	# Check if local player is in cabin or at either call pedestal
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var local_id: int = 1
	if net != null and net.multiplayer_peer != null:
		local_id = net.get_unique_id()

	for rider: CharacterBody3D in riders:
		if rider != null and rider.name == str(local_id):
			return true

	# Check proximity to pedestals
	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container != null:
		var local_p: CharacterBody3D = players_container.get_node_or_null(str(local_id)) as CharacterBody3D
		if local_p != null:
			if call_pedestal_28 != null and local_p.global_position.distance_to(call_pedestal_28.global_position) < 3.5:
				return true
			if call_pedestal_27 != null and local_p.global_position.distance_to(call_pedestal_27.global_position) < 3.5:
				return true

	return false


func _handle_interaction() -> void:
	if is_moving:
		return

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var local_id: int = 1
	if net != null and net.multiplayer_peer != null:
		local_id = net.get_unique_id()

	# If riding inside the cabin, toggle destination floor
	for rider: CharacterBody3D in riders:
		if rider != null and rider.name == str(local_id):
			toggle_elevator()
			return

	# Outside cabin: call elevator to the floor corresponding to nearest pedestal
	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container != null:
		var local_p: CharacterBody3D = players_container.get_node_or_null(str(local_id)) as CharacterBody3D
		if local_p != null:
			var dist_28: float = INF
			var dist_27: float = INF
			if call_pedestal_28 != null:
				dist_28 = local_p.global_position.distance_to(call_pedestal_28.global_position)
			if call_pedestal_27 != null:
				dist_27 = local_p.global_position.distance_to(call_pedestal_27.global_position)

			if dist_28 < 3.5 and dist_28 <= dist_27:
				call_elevator(28)
			elif dist_27 < 3.5 and dist_27 < dist_28:
				call_elevator(27)
			else:
				toggle_elevator()


func toggle_elevator() -> void:
	var target_floor: int = 27 if current_floor == 28 else 28
	call_elevator(target_floor)


func call_elevator(target_floor: int) -> void:
	if is_moving:
		return
	if target_floor == current_floor and not is_moving:
		_open_doors()
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "server_request_elevator", target_floor)
	else:
		sync_move_elevator(target_floor)


@rpc("any_peer", "call_local", "reliable")
func server_request_elevator(target_floor: int) -> void:
	if not multiplayer.is_server():
		return
	if is_moving:
		return
	rpc("sync_move_elevator", target_floor)


@rpc("call_local", "reliable")
func sync_move_elevator(target_floor: int) -> void:
	if is_moving:
		return

	is_moving = true
	var from_floor: int = current_floor
	state = ElevatorState.MOVING_UP if target_floor == 27 else ElevatorState.MOVING_DOWN
	elevator_started.emit(from_floor, target_floor)
	print("SGCElevator: Transit initiated from Level %d to Level %d" % [from_floor, target_floor])

	_set_pedestal_lights_status(Color(1.0, 0.65, 0.1)) # Amber during transit
	_play_sfx("res://audio/sfx_door_hydraulic.wav", 40.0)

	# 1. Close doors first
	_close_doors(func() -> void:
		_animate_cabin_transit(target_floor)
	)


func _animate_cabin_transit(target_floor: int) -> void:
	var target_y: float = FLOOR_27_Y if target_floor == 27 else FLOOR_28_Y
	var start_y: float = cabin.position.y if cabin != null else 0.0

	var tween: Tween = create_tween()
	if cabin != null:
		tween.tween_property(cabin, "position:y", target_y, TRANSIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.tween_callback(func() -> void:
		current_floor = target_floor
		state = ElevatorState.AT_27 if current_floor == 27 else ElevatorState.AT_28
		is_moving = false
		_update_floor_indicator(current_floor)
		_set_pedestal_lights_status(Color(0.2, 0.9, 0.3)) # Green when arrived
		_play_sfx("res://audio/sfx_gate_lock.wav", 40.0)
		_open_doors()
		elevator_arrived.emit(current_floor)
		print("SGCElevator: Arrived at Level %d." % current_floor)
	)


func _close_doors(on_closed: Callable) -> void:
	var tween: Tween = create_tween()
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", DOOR_CLOSED_LEFT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", DOOR_CLOSED_RIGHT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(on_closed)


func _open_doors() -> void:
	var tween: Tween = create_tween()
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", DOOR_OPEN_LEFT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", DOOR_OPEN_RIGHT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _update_floor_indicator(fl: int) -> void:
	if indicator_label != null:
		indicator_label.text = "[ %d ]" % fl


func _set_pedestal_lights_status(color: Color) -> void:
	if pedestal_light_28 != null:
		pedestal_light_28.light_color = color
	if pedestal_light_27 != null:
		pedestal_light_27.light_color = color


func _on_ride_area_entered(body: Node3D) -> void:
	var player: CharacterBody3D = body as CharacterBody3D
	if player != null and not riders.has(player):
		riders.append(player)


func _on_ride_area_exited(body: Node3D) -> void:
	var player: CharacterBody3D = body as CharacterBody3D
	if player != null:
		riders.erase(player)


func _play_sfx(res_path: String, max_dist: float) -> void:
	if ResourceLoader.exists(res_path):
		var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio.stream = load(res_path) as AudioStream
		audio.max_distance = max_dist
		audio.unit_size = 12.0
		add_child(audio)
		audio.global_position = cabin.global_position if cabin != null else global_position
		audio.finished.connect(audio.queue_free)
		audio.play()
