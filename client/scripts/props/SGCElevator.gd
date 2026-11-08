class_name SGCElevator
extends Node3D
## SGC Hydraulic Freight Elevator connecting Sublevels 28, 27 and 26.
## Provides automated vertical transit, animated sliding doors, multiplayer RPC synchronization,
## dynamic floor indicator displays, dual-pedestal call stations, and arrival audio cues.

signal elevator_started(from_floor: int, to_floor: int)
signal elevator_arrived(floor_num: int)

enum ElevatorState { AT_28, MOVING_UP, AT_27, MOVING_DOWN, AT_26, AT_25 }

const FLOOR_28_Y: float = SGCMapDefinition.FLOOR_HEIGHTS[28]
const FLOOR_27_Y: float = SGCMapDefinition.FLOOR_HEIGHTS[27]
const FLOOR_26_Y: float = SGCMapDefinition.FLOOR_HEIGHTS[26]
const SUPPORTED_FLOORS: Array[int] = [28, 27, 26]
const TRANSIT_DURATION: float = 3.0

const DOOR_CLOSED_LEFT_X: float = -0.8
const DOOR_CLOSED_RIGHT_X: float = 0.8
const DOOR_OPEN_OFFSET: float = 1.6
const DOOR_OPEN_LEFT_X: float = -2.4
const DOOR_OPEN_RIGHT_X: float = 2.4

@export var current_floor: int = 28
var state: ElevatorState = ElevatorState.AT_28
var is_moving: bool = false
var is_doors_open: bool = false
var riders: Array[CharacterBody3D] = []
var destination_floor: int = 28
var pending_calls: Array[int] = []
var arrival_dwell: float = 0.0
var landing_gates: Dictionary = {}
var travel_elapsed: float = 0.0
var travel_started: bool = false
var transit_tween: Tween
var door_tween: Tween

@onready var cabin: AnimatableBody3D = $Cabin if has_node("Cabin") else null
@onready var door_left: Node3D = $Cabin/DoorLeft if has_node("Cabin/DoorLeft") else null
@onready var door_right: Node3D = $Cabin/DoorRight if has_node("Cabin/DoorRight") else null
@onready var indicator_label: Label3D = $Cabin/IndicatorLabel if has_node("Cabin/IndicatorLabel") else null
@onready var cabin_light: OmniLight3D = $Cabin/CabinLight if has_node("Cabin/CabinLight") else null
@onready var ride_area: Area3D = $Cabin/RideArea if has_node("Cabin/RideArea") else null

# Left and Right call pedestals for Floor 28 and Floor 27
@onready var call_pedestal_28: Node3D = $CallPedestal28 if has_node("CallPedestal28") else null
@onready var call_pedestal_28_right: Node3D = $CallPedestal28Right if has_node("CallPedestal28Right") else null
@onready var call_pedestal_27: Node3D = $CallPedestal27 if has_node("CallPedestal27") else null
@onready var call_pedestal_27_right: Node3D = $CallPedestal27Right if has_node("CallPedestal27Right") else null

@onready var pedestal_light_28: OmniLight3D = $CallPedestal28/PedestalLight if has_node("CallPedestal28/PedestalLight") else null
@onready var pedestal_light_28_right: OmniLight3D = $CallPedestal28Right/PedestalLight if has_node("CallPedestal28Right/PedestalLight") else null
@onready var pedestal_light_27: OmniLight3D = $CallPedestal27/PedestalLight if has_node("CallPedestal27/PedestalLight") else null
@onready var pedestal_light_27_right: OmniLight3D = $CallPedestal27Right/PedestalLight if has_node("CallPedestal27Right/PedestalLight") else null


func _ready() -> void:
	add_to_group("interactable")

	if ride_area != null:
		ride_area.body_entered.connect(_on_ride_area_entered)
		ride_area.body_exited.connect(_on_ride_area_exited)

	_update_floor_indicator(current_floor)
	_set_pedestal_lights_status(Color(0.2, 0.9, 0.3))
	if cabin != null:
		cabin.position.y = get_floor_y(current_floor)
	_build_landing_gates()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_elevator_snapshot.rpc_id(1)


# PlayerController3D routes interact once; a second input listener would double-call the lift.
func interact(player: Node = null) -> void:
	if _can_interact_with_elevator(player):
		_handle_interaction(player)


func _find_local_player() -> CharacterBody3D:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var local_id: int = 1
	if net != null and net.multiplayer.has_multiplayer_peer():
		local_id = net.multiplayer.get_unique_id()

	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container != null:
		var p_by_id: CharacterBody3D = players_container.get_node_or_null(str(local_id)) as CharacterBody3D
		if p_by_id != null:
			return p_by_id
		var p_by_name: CharacterBody3D = players_container.get_node_or_null("Player") as CharacterBody3D
		if p_by_name != null:
			return p_by_name
		for child: Node in players_container.get_children():
			var cb: CharacterBody3D = child as CharacterBody3D
			if cb != null:
				return cb

	var group_players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in group_players:
		var cb: CharacterBody3D = p as CharacterBody3D
		if cb != null:
			return cb

	return null


func _can_interact_with_elevator(player: Node = null) -> bool:
	if is_moving:
		return false

	var target_player: CharacterBody3D = player as CharacterBody3D
	if target_player == null:
		target_player = _find_local_player()

	if target_player == null:
		return false

	# Check if operative is riding inside cabin or inside ride area
	if riders.has(target_player):
		return true
	if ride_area != null and ride_area.overlaps_body(target_player):
		return true

	# Check proximity to pedestals (both left and right on Floor 28 and 27)
	var p_pos: Vector3 = target_player.global_position
	if call_pedestal_28 != null and p_pos.distance_to(call_pedestal_28.global_position) < 3.5:
		return true
	if call_pedestal_28_right != null and p_pos.distance_to(call_pedestal_28_right.global_position) < 3.5:
		return true
	if call_pedestal_27 != null and p_pos.distance_to(call_pedestal_27.global_position) < 3.5:
		return true
	if call_pedestal_27_right != null and p_pos.distance_to(call_pedestal_27_right.global_position) < 3.5:
		return true

	var upper_call := get_node_or_null("CallPedestal26") as Node3D
	if upper_call != null and p_pos.distance_to(upper_call.global_position) < 3.5: return true

	# Proximity to cabin itself if standing in doorway
	if cabin != null and p_pos.distance_to(cabin.global_position) < 3.0:
		return true

	return false


func _handle_interaction(player: Node = null) -> void:
	if is_moving:
		return

	var target_player: CharacterBody3D = player as CharacterBody3D
	if target_player == null:
		target_player = _find_local_player()

	# If riding inside the cabin or inside ride area, toggle destination floor
	if target_player != null:
		if riders.has(target_player) or (ride_area != null and ride_area.overlaps_body(target_player)):
			toggle_elevator()
			return

		var p_pos: Vector3 = target_player.global_position
		if p_pos.y > 9.0:
			call_elevator(26)
			return
		var dist_28: float = INF
		if call_pedestal_28 != null:
			dist_28 = minf(dist_28, p_pos.distance_to(call_pedestal_28.global_position))
		if call_pedestal_28_right != null:
			dist_28 = minf(dist_28, p_pos.distance_to(call_pedestal_28_right.global_position))

		var dist_27: float = INF
		if call_pedestal_27 != null:
			dist_27 = minf(dist_27, p_pos.distance_to(call_pedestal_27.global_position))
		if call_pedestal_27_right != null:
			dist_27 = minf(dist_27, p_pos.distance_to(call_pedestal_27_right.global_position))

		if dist_28 < 3.5 and dist_28 <= dist_27:
			call_elevator(28)
		elif dist_27 < 3.5 and dist_27 < dist_28:
			call_elevator(27)
		else:
			toggle_elevator()
	else:
		toggle_elevator()


func toggle_elevator() -> void:
	var target_floor: int = 27 if current_floor == 28 else 28
	_dispatch_elevator(target_floor)


func get_floor_y(fl: int) -> float:
	match fl:
		28: return FLOOR_28_Y
		27: return FLOOR_27_Y
		26: return FLOOR_26_Y
		_: return FLOOR_28_Y


func call_elevator(target_floor: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_request_call.rpc_id(1, target_floor)
	else:
		server_request_call(target_floor)


@rpc("any_peer", "call_local", "reliable")
func server_request_call(target_floor: int) -> void:
	if not _request_allowed():
		return
	if not multiplayer.is_server() or target_floor not in SUPPORTED_FLOORS: return
	if is_moving:
		if target_floor != destination_floor and target_floor not in pending_calls: pending_calls.append(target_floor)
		return
	if target_floor == current_floor:
		if multiplayer.has_multiplayer_peer(): sync_open_doors.rpc()
		else: sync_open_doors()
	else:
		server_request_elevator(target_floor)


@rpc("authority", "call_local", "reliable")
func sync_open_doors() -> void:
	_open_doors()


func _dispatch_elevator(destination_floor: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_request_elevator.rpc_id(1, destination_floor)
	else:
		server_request_elevator(destination_floor)


@rpc("any_peer", "call_local", "reliable")
func server_request_elevator(target_floor: int) -> void:
	if not _request_allowed():
		return
	if not multiplayer.is_server() or is_moving or target_floor not in SUPPORTED_FLOORS or target_floor == current_floor:
		return
	if multiplayer.has_multiplayer_peer():
		sync_move_elevator.rpc(target_floor)
	else:
		sync_move_elevator(target_floor)


@rpc("call_local", "reliable")
func sync_move_elevator(target_floor: int) -> void:
	if is_moving:
		return

	is_moving = true
	destination_floor = target_floor
	travel_elapsed = 0.0
	travel_started = false
	var from_floor: int = current_floor
	var target_y: float = get_floor_y(target_floor)
	var current_y: float = get_floor_y(from_floor)
	if target_y > current_y:
		state = ElevatorState.MOVING_UP
	else:
		state = ElevatorState.MOVING_DOWN
	elevator_started.emit(from_floor, target_floor)
	print("SGCElevator: Transit initiated from Level %d to Level %d" % [from_floor, target_floor])

	_set_pedestal_lights_status(Color(1.0, 0.65, 0.1)) # Amber during transit
	_play_sfx("res://audio/sfx_door_hydraulic.wav", 40.0)

	# 1. Close doors first
	_close_doors(func() -> void:
		_animate_cabin_transit(target_floor)
	)


func _animate_cabin_transit(target_floor: int, duration: float = TRANSIT_DURATION) -> void:
	var target_y: float = get_floor_y(target_floor)
	travel_started = true
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	transit_tween = tween
	if cabin != null:
		tween.tween_property(cabin, "position:y", target_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.tween_callback(func() -> void:
		current_floor = target_floor
		arrival_dwell = 2.0
		state = _arrival_state()
		is_moving = false
		travel_started = false
		_update_floor_indicator(current_floor)
		_set_pedestal_lights_status(Color(0.2, 0.9, 0.3)) # Green when arrived
		_play_sfx("res://audio/sfx_gate_lock.wav", 40.0)
		_open_doors()
		elevator_arrived.emit(current_floor)
		print("SGCElevator: Arrived at Level %d." % current_floor)
	)


func _close_doors(on_closed: Callable) -> void:
	is_doors_open = false
	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	var tween: Tween = create_tween()
	door_tween = tween
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", DOOR_CLOSED_LEFT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", DOOR_CLOSED_RIGHT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(on_closed)


func _open_doors() -> void:
	is_doors_open = true
	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_send_elevator_snapshot()
	var tween: Tween = create_tween()
	door_tween = tween
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", DOOR_OPEN_LEFT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", DOOR_OPEN_RIGHT_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _update_floor_indicator(fl: int) -> void:
	if indicator_label != null:
		indicator_label.text = "[ %d ]" % fl


func _set_pedestal_lights_status(color: Color) -> void:
	if pedestal_light_28 != null:
		pedestal_light_28.light_color = color
	if pedestal_light_28_right != null:
		pedestal_light_28_right.light_color = color
	if pedestal_light_27 != null:
		pedestal_light_27.light_color = color
	if pedestal_light_27_right != null:
		pedestal_light_27_right.light_color = color


func _on_ride_area_entered(body: Node3D) -> void:
	var player: CharacterBody3D = body as CharacterBody3D
	if player != null and not riders.has(player):
		riders.append(player)


func _on_ride_area_exited(body: Node3D) -> void:
	var player: CharacterBody3D = body as CharacterBody3D
	if player != null:
		riders.erase(player)


func _play_sfx(res_path: String, max_dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(res_path):
		var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio.stream = load(res_path) as AudioStream
		audio.max_distance = max_dist
		audio.unit_size = 12.0
		add_child(audio)
		audio.global_position = cabin.global_position if cabin != null else global_position
		audio.finished.connect(audio.queue_free)
		audio.play()


func _request_allowed() -> bool:
	if not multiplayer.is_server():
		return false
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		return true
	var room: Node = get_parent()
	var player: Node = room.get_node_or_null("Players/" + str(sender))
	return player != null and _can_interact_with_elevator(player)


func _process(delta: float) -> void:
	_update_landing_gates()
	arrival_dwell = maxf(0.0, arrival_dwell-delta)
	if multiplayer.is_server() and not is_moving and arrival_dwell <= 0.0 and not pending_calls.is_empty():
		server_request_call(pending_calls.pop_front())
	if is_moving and travel_started:
		travel_elapsed += delta


@rpc("any_peer", "call_remote", "reliable")
func request_elevator_snapshot() -> void:
	if multiplayer.is_server():
		_send_elevator_snapshot(multiplayer.get_remote_sender_id())


func _send_elevator_snapshot(peer: int = 0) -> void:
	var y: float = cabin.position.y if cabin != null else get_floor_y(current_floor)
	var remaining: float = maxf(0.01, TRANSIT_DURATION - travel_elapsed)
	if peer > 0:
		sync_elevator_snapshot.rpc_id(peer, current_floor, destination_floor, is_moving, is_doors_open, y, remaining)
	else:
		sync_elevator_snapshot.rpc(current_floor, destination_floor, is_moving, is_doors_open, y, remaining)


@rpc("authority", "call_remote", "reliable")
func sync_elevator_snapshot(floor_number: int, destination: int, moving: bool, opened: bool, y: float, remaining: float) -> void:
	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	if transit_tween != null and transit_tween.is_valid():
		transit_tween.kill()
	current_floor = floor_number
	destination_floor = destination
	is_moving = moving
	is_doors_open = opened
	if cabin != null:
		# Snapshot correction is a teleport, not an animated-body velocity update.
		cabin.sync_to_physics = false
		cabin.position.y = y
		cabin.sync_to_physics = true
	if door_left != null:
		door_left.position.x = DOOR_OPEN_LEFT_X if opened else DOOR_CLOSED_LEFT_X
	if door_right != null:
		door_right.position.x = DOOR_OPEN_RIGHT_X if opened else DOOR_CLOSED_RIGHT_X
	_update_floor_indicator(current_floor)
	if moving:
		state = ElevatorState.MOVING_UP if get_floor_y(destination) > y else ElevatorState.MOVING_DOWN
		_animate_cabin_transit(destination, remaining)
	else:
		travel_started = false
		state = _arrival_state()


func select_floor(floor_number: int) -> void:
	if floor_number in SUPPORTED_FLOORS: _dispatch_elevator(floor_number)

func _arrival_state() -> ElevatorState:
	match current_floor:
		26: return ElevatorState.AT_26
		27: return ElevatorState.AT_27
		_: return ElevatorState.AT_28

func _build_landing_gates() -> void:
	for fl in SUPPORTED_FLOORS:
		var body := StaticBody3D.new(); body.name="LandingGate"+str(fl)
		body.position=Vector3(0,get_floor_y(fl)+1.35,1.65)
		var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(3.2,2.7,0.10);collider.shape=shape;body.add_child(collider)
		var visual:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=shape.size;visual.mesh=box
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.24,0.28,0.30);mat.metallic=0.5;visual.material_override=mat;body.add_child(visual)
		add_child(body);landing_gates[fl]=body

func _update_landing_gates() -> void:
	for fl: int in landing_gates:
		var closed: bool=is_moving or current_floor!=fl or not is_doors_open
		var body:StaticBody3D=landing_gates[fl]
		body.visible=closed
		(body.get_child(0) as CollisionShape3D).set_deferred("disabled",not closed)
