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


## Nearest reachable room `cover` marker on the actor's deck that keeps distance from the
## threat. The fallback when no cover prop qualifies (prop_cover). Vector3.INF when the level
## offers none; callers then hold their position.
static func cover_position(assembly: LevelAssembly, body: Node3D, threat: Vector3) -> Vector3:
	var best := Vector3.INF
	var here := body.global_position
	for item in assembly.layout.instances:
		var marker := assembly.get_node_or_null(str(item.id) + "/Markers/cover") as Node3D
		if marker == null:
			continue
		var spot := marker.global_position
		if (
			absf(spot.y - here.y) > 1.5
			or spot.distance_to(threat) < 4.0
			or spot.distance_to(here) > 24.0
			or spot.distance_to(here) >= best.distance_to(here)
		):
			continue
		var path := assembly.local_path(here, spot)
		if not path.is_empty() and path[-1].distance_to(spot) < 1.0:
			best = spot
	return best


## Height range of a solid room attachment that works as low cover: a crouched Jaffa is hidden
## behind it and can stand to fire over it.
const LOW_COVER_MIN := 0.9
const LOW_COVER_MAX := 1.3
## Height of the line a crouched actor must have blocked, and of a standing threat's torso.
const CROUCHED_TORSO := 0.8
const THREAT_TORSO := 1.0
## Closest a cover spot may be to the threat. Chambers are 7.6 m across, so more would leave
## most props unusable against an intruder inside the room; melee range is 2.2 m.
const PROP_COVER_MIN_RANGE := 3.0


## Solid low-cover attachments of the level: `cover` components, and `prop` or `equipment`
## pieces whose bounds are low cover (LOW_COVER_MIN..MAX high, at least 0.9 m deep each way).
static func cover_props(assembly: LevelAssembly) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for item in assembly.layout.instances:
		var module := assembly.get_node_or_null(str(item.id))
		if module == null:
			continue
		for attachment in LevelRoomComposer.resolved(item):
			var size := attachment.bounds.size
			if attachment.placeholder_size == Vector3.ZERO and attachment.scene == null:
				continue  # A marker, not something solid.
			var low := size.y >= LOW_COVER_MIN and size.y <= LOW_COVER_MAX
			var broad := minf(size.x, size.z) >= 0.9
			if attachment.component == &"cover" or (
				attachment.component in [&"prop", &"equipment"] and low and broad
			):
				var node := module.get_node_or_null(LevelRoomComposer.node_path(attachment)) as Node3D
				if node != null:
					result.append(node)
	return result


## True when `prop` blocks the line from a crouched actor at `spot` to a standing threat at
## `threat`: the first thing that line hits is part of the prop. Heights are measured from the
## floor the prop stands on, not from `spot`, which may be a navigation-mesh point above it.
static func prop_blocks(prop: Node3D, spot: Vector3, threat: Vector3) -> bool:
	var floor_y := prop.global_position.y
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spot.x, floor_y + CROUCHED_TORSO, spot.z), threat + Vector3(0, THREAT_TORSO, 0), 1
	)
	var hit := prop.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and prop.is_ancestor_of(hit["collider"] as Node)


## The nearest reachable spot behind a cover prop, on the side away from `threat`, where the
## prop blocks the line to the threat at crouched height and the spot keeps
## PROP_COVER_MIN_RANGE from it. Only
## props on the actor's deck and within `max_walk` metres of walking count, and spots within
## 1 m of `taken` are skipped. Returns {"spot": Vector3, "prop": Node3D}, or {} if none.
static func prop_cover(
	assembly: LevelAssembly,
	body: Node3D,
	threat: Vector3,
	max_walk: float = 20.0,
	taken: Array[Vector3] = []
) -> Dictionary:
	var best := {}
	var best_walk := max_walk
	var here := body.global_position
	for prop in cover_props(assembly):
		var centre := prop.global_position
		if absf(centre.y - here.y) > 1.5 or Vector2(centre.x - here.x, centre.z - here.z).length() > max_walk:
			continue
		var away := Vector3(centre.x - threat.x, 0.0, centre.z - threat.z)
		if away.length() < 2.0:
			continue
		away = away.normalized()
		var bounds: AABB = prop.get_meta("attachment_bounds", AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE))
		var reach := maxf(bounds.size.x, bounds.size.z) * 0.5 + 0.55
		for turn: float in [0.0, 0.45, -0.45, 0.9, -0.9]:
			var wanted := centre + away.rotated(Vector3.UP, turn) * reach
			var spot := NavigationServer3D.map_get_closest_point(assembly.navigation_map, wanted)
			if spot.distance_to(wanted) > 0.6 or spot.distance_to(threat) < PROP_COVER_MIN_RANGE:
				continue
			var free := true
			for other in taken:
				free = free and other.distance_to(spot) > 1.0
			if not free or not prop_blocks(prop, spot, threat):
				continue
			var path := assembly.local_path(here, spot)
			if path.is_empty() or path[-1].distance_to(spot) > 1.0:
				continue
			var walk := 0.0
			for i in range(1, path.size()):
				walk += path[i - 1].distance_to(path[i])
			if walk < best_walk:
				best_walk = walk
				best = {"spot": spot, "prop": prop}
			break
	return best


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
