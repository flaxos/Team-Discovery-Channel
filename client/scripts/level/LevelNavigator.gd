class_name LevelNavigator
extends RefCounted
## Route following on a LevelAssembly navigation map. Steers only: it never moves the
## actor, never edits door collision and never unlocks anything. Server-side use only.
signal status_changed(status: String)
const DOOR_REACH := 2.5
const STALL_SECONDS := 3.0
const MAX_REPLANS := 3
## idle, waiting_for_navigation, moving, waiting_for_door, arrived,
## unreachable, blocked_door, stuck
var status := "idle":
	set(value):
		if status != value:
			status = value
			status_changed.emit(value)
var actor: CharacterBody3D
var level: LevelAssembly
var destination := Vector3.INF
var points := PackedVector3Array()
var index := 0
## Doors the planned path crosses, in travel order: {door, segment}.
var doors: Array[Dictionary] = []
var blocked_door: ModularDoor
var last_position := Vector3.INF
var stall_time := 0.0
var retry_time := 0.0
var replans := 0


func _init(body: CharacterBody3D, assembly: LevelAssembly) -> void:
	actor = body
	level = assembly


## Nearest assembly sharing an ancestor with the actor (the actor may be inside it).
static func find_level(body: Node) -> LevelAssembly:
	var parent := body.get_parent()
	while parent != null:
		if parent is LevelAssembly:
			return parent
		for child in parent.get_children():
			if child is LevelAssembly:
				return child
		parent = parent.get_parent()
	return null


func reset() -> void:
	points.clear()
	doors.clear()
	index = 0
	destination = Vector3.INF
	blocked_door = null
	replans = 0
	stall_time = 0.0
	status = "idle"


func _plan(goal: Vector3) -> void:
	destination = goal
	index = 0
	doors.clear()
	blocked_door = null
	last_position = Vector3.INF
	stall_time = 0.0
	points = level.local_path(actor.global_position, goal)
	if points.is_empty() or points[-1].distance_to(goal) > 1.0:
		points.clear()
		status = "unreachable"
		return
	var candidates := actor.get_tree().get_nodes_in_group("modular_door")
	for segment in range(points.size() - 1):
		for node in candidates:
			var door := node as ModularDoor
			if door != null and level.is_ancestor_of(door) and _crosses(door, segment):
				if doors.is_empty() or doors[-1]["door"] != door:
					doors.append({"door": door, "segment": segment})
	if _locked_ahead():
		return
	status = "moving"


func _locked_ahead() -> bool:
	for entry in doors:
		var door := entry["door"] as ModularDoor
		if is_instance_valid(door) and door.locked:
			blocked_door = door
			status = "blocked_door"
			return true
	return false


func _crosses(door: ModularDoor, segment: int) -> bool:
	var a := door.to_local(points[segment])
	var b := door.to_local(points[segment + 1])
	if a.z * b.z > 0.0 or is_equal_approx(a.z, b.z):
		return false
	var hit := a.lerp(b, a.z / (a.z - b.z))
	return absf(hit.x) <= door.width / 2 + 0.3 and hit.y > -1.0 and hit.y < door.height + 1.0


func next_position(goal: Vector3, delta: float = 1.0 / 60.0) -> Vector3:
	var here := actor.global_position
	if not is_instance_valid(level) or not level.ready_for_navigation:
		status = "waiting_for_navigation"
		return here
	if destination == Vector3.INF or destination.distance_to(goal) > 0.5:
		replans = 0
		_plan(goal)
	if status in ["unreachable", "blocked_door", "stuck"]:
		# Hold in place and re-check; a door may be unlocked or an obstacle may clear.
		retry_time += delta
		if retry_time < 1.0:
			return here
		retry_time = 0.0
		var held := status
		_plan(goal)
		if status != "moving":
			return here
		if held == "stuck":
			replans = 0
	if here.distance_to(goal) < 0.5:
		status = "arrived"
		return here
	if status == "moving":
		if last_position == Vector3.INF or here.distance_to(last_position) > 0.15:
			last_position = here
			stall_time = 0.0
		else:
			stall_time += delta
		if stall_time > STALL_SECONDS:
			replans += 1
			if replans > MAX_REPLANS:
				status = "stuck"
				return here
			_plan(goal)
			if status != "moving":
				return here
	while index < points.size() - 1:
		var offset := points[index] - here
		if Vector2(offset.x, offset.z).length() > 0.25 or absf(offset.y) > 1.0:
			break
		index += 1
	while not doors.is_empty() and index > int(doors[0]["segment"]) + 1:
		doors.pop_front()
	if _locked_ahead():
		return here
	if not doors.is_empty():
		var door := doors[0]["door"] as ModularDoor
		if is_instance_valid(door) and not door.is_open:
			if here.distance_to(door.global_position) <= DOOR_REACH and not door.open_for(actor):
				status = "waiting_for_door"
				return here
	status = "moving"
	return points[index]
