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
	var candidates := MissionWorld.in_group(actor, &"modular_door")
	doors = _doors_along(points, candidates)
	if _has_locked_door(doors):
		if _reroute_around_locked_doors(goal, candidates):
			return
		_locked_ahead()
		return
	status = "moving"


func _doors_along(path_points: PackedVector3Array, candidates: Array[Node]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for segment in range(path_points.size() - 1):
		for node in candidates:
			var door := node as ModularDoor
			if door != null and level.is_ancestor_of(door) and _segment_crosses(door, path_points[segment], path_points[segment + 1]):
				if found.is_empty() or found[-1]["door"] != door:
					found.append({"door": door, "segment": segment})
	# A single navmesh leg can cross several doors; open the closest one first.
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.segment != b.segment:
			return a.segment < b.segment
		var origin := path_points[int(a.segment)]
		return origin.distance_squared_to(a.door.global_position) < origin.distance_squared_to(b.door.global_position)
	)
	return found


func _has_locked_door(door_list: Array[Dictionary]) -> bool:
	for entry in door_list:
		var door := entry["door"] as ModularDoor
		if is_instance_valid(door) and door.locked:
			return true
	return false


func _locked_ahead() -> bool:
	for entry in doors:
		var door := entry["door"] as ModularDoor
		if is_instance_valid(door) and door.locked:
			blocked_door = door
			status = "blocked_door"
			return true
	return false


func _segment_crosses(door: ModularDoor, pt_a: Vector3, pt_b: Vector3) -> bool:
	var a := door.to_local(pt_a)
	var b := door.to_local(pt_b)
	if a.z * b.z > 0.0 or is_equal_approx(a.z, b.z):
		return false
	var hit := a.lerp(b, a.z / (a.z - b.z))
	return absf(hit.x) <= door.width / 2 + 0.3 and hit.y > -1.0 and hit.y < door.height + 1.0


func _reroute_around_locked_doors(goal: Vector3, candidates: Array[Node]) -> bool:
	if level == null or level.layout == null:
		return false
	var from_room := _room_at(actor.global_position)
	var to_room := _room_at(goal)
	if from_room == &"" or to_room == &"" or from_room == to_room:
		return false
	# Use the authored walking graph with current door locks, never mutate the layout.
	var links := {}
	for item in level.layout.instances:
		links[str(item.id)] = []
	for i in range(level.layout.connections.size()):
		if _is_connection_locked(i):
			continue
		var edge := level.layout.connections[i]
		var a := str(edge.from_instance)
		var b := str(edge.to_instance)
		links[a].append({"to": b, "connection": i})
		links[b].append({"to": a, "connection": i})
	var room_seq := LevelTopology.path(links, str(from_room), str(to_room))
	if room_seq.is_empty():
		return false
	var conn_seq: Array[int] = []
	for i in range(room_seq.size() - 1):
		for edge: Dictionary in links[room_seq[i]]:
			if edge.to == room_seq[i + 1]:
				conn_seq.append(edge.connection)
				break
	# First try stitching through intermediate room entry/patrol markers.
	var room_waypoints: Array[Vector3] = [actor.global_position]
	for i in range(1, room_seq.size() - 1):
		room_waypoints.append(_room_waypoint(room_seq[i]))
	room_waypoints.append(goal)
	if _try_apply_stitched_route(room_waypoints, candidates):
		return true
	# Fallback: include connection socket approach points so tight loops cannot shortcut back.
	var detailed_waypoints: Array[Vector3] = [actor.global_position]
	for i in range(conn_seq.size()):
		for pt in _connection_approach_points(conn_seq[i], room_seq[i]):
			detailed_waypoints.append(pt)
		if i + 1 < room_seq.size() - 1:
			detailed_waypoints.append(_room_waypoint(room_seq[i + 1]))
	detailed_waypoints.append(goal)
	return _try_apply_stitched_route(detailed_waypoints, candidates)


func _try_apply_stitched_route(waypoints: Array[Vector3], candidates: Array[Node]) -> bool:
	if waypoints.size() < 2:
		return false
	var stitched := _stitch_waypoints(waypoints)
	if stitched.is_empty():
		return false
	var stitched_doors := _doors_along(stitched, candidates)
	if _has_locked_door(stitched_doors):
		return false
	points = stitched
	doors = stitched_doors
	index = 0
	blocked_door = null
	status = "moving"
	return true


func _stitch_waypoints(waypoints: Array[Vector3]) -> PackedVector3Array:
	var stitched := PackedVector3Array()
	for i in range(waypoints.size() - 1):
		var a := waypoints[i] if stitched.is_empty() else stitched[-1]
		var b := waypoints[i + 1]
		if a.distance_to(b) < 0.2:
			continue
		var leg := level.local_path(a, b)
		if leg.is_empty() or leg[-1].distance_to(b) > 1.0:
			return PackedVector3Array()
		var start_idx := 0 if stitched.is_empty() else 1
		for j in range(start_idx, leg.size()):
			stitched.append(leg[j])
	return stitched


func _is_connection_locked(conn_index: int) -> bool:
	# LevelAssembler names runtime doors by their native layout connection index.
	var door := level.get_node_or_null("Door_%03d" % conn_index) as ModularDoor
	return door != null and door.locked


func _room_at(pos: Vector3) -> StringName:
	var best_inside := &""
	var best_inside_dist := INF
	var best_near := &""
	var best_near_dist := INF
	for item in level.layout.instances:
		var mod := level.get_node_or_null(str(item.id)) as Node3D
		if mod == null or item.module == null:
			continue
		var local_pos := mod.to_local(pos)
		var box := item.module.occupied
		var center_dist := local_pos.distance_to(box.get_center())
		if box.grow(0.3).has_point(local_pos):
			if center_dist < best_inside_dist:
				best_inside_dist = center_dist
				best_inside = item.id
		elif absf(local_pos.y - box.get_center().y) <= box.size.y * 0.5 + 1.5:
			if center_dist < best_near_dist:
				best_near_dist = center_dist
				best_near = item.id
	return best_inside if best_inside != &"" else best_near


func _room_waypoint(room_id: StringName) -> Vector3:
	for marker_name: String in ["entry", "patrol", "destination"]:
		var marker := level.get_node_or_null(str(room_id) + "/Markers/" + marker_name) as Node3D
		if marker != null:
			return NavigationServer3D.map_get_closest_point(level.navigation_map, marker.global_position)
	var mod := level.get_node_or_null(str(room_id)) as Node3D
	if mod != null:
		return NavigationServer3D.map_get_closest_point(level.navigation_map, mod.global_position)
	return actor.global_position


func _connection_approach_points(conn_index: int, from_room: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var edge := level.layout.connections[conn_index]
	var a_id := edge.from_instance if edge.from_instance == from_room else edge.to_instance
	var a_sock_id := edge.from_socket if edge.from_instance == from_room else edge.to_socket
	var b_id := edge.to_instance if edge.from_instance == from_room else edge.from_instance
	var b_sock_id := edge.to_socket if edge.from_instance == from_room else edge.from_socket
	for pair: Array in [[a_id, a_sock_id], [b_id, b_sock_id]]:
		var mod := level.get_node_or_null(str(pair[0])) as Node3D
		var item := level.layout.instance(pair[0])
		if mod != null and item != null and item.module != null:
			var sock := item.module.socket(pair[1])
			if sock != null:
				var world_pt := mod.to_global(sock.approach)
				result.append(NavigationServer3D.map_get_closest_point(level.navigation_map, world_pt))
	return result


func _nearby_npcs(here: Vector3) -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return result
	var containers: Array[Node] = []
	for group_name: String in ["Enemies", "Allies"]:
		var found := MissionWorld.find(actor, group_name)
		if found != null and not containers.has(found):
			containers.append(found)
	var parent := actor.get_parent()
	if parent != null and not containers.has(parent):
		containers.append(parent)
	for container in containers:
		for child in container.get_children():
			var other := child as CharacterBody3D
			if (
				other == null
				or other == actor
				or not is_instance_valid(other)
				or not other.is_inside_tree()
				or other.collision_layer == 0
			):
				continue
			if absf(other.global_position.y - here.y) > 1.0:
				continue
			var flat := Vector2(other.global_position.x - here.x, other.global_position.z - here.z).length()
			if flat <= 3.2 and not result.has(other):
				result.append(other)
	return result


func _avoid_corridor_npc(here: Vector3, target: Vector3) -> Vector3:
	var to_next := Vector3(target.x - here.x, 0.0, target.z - here.z)
	if to_next.length_squared() < 0.0001:
		return target
	var dir := to_next.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	for other in _nearby_npcs(here):
		var rel := Vector3(other.global_position.x - here.x, 0.0, other.global_position.z - here.z)
		var dist := rel.length()
		if dist > 3.0:
			continue
		var forward_dist := dir.dot(rel)
		# Only yield to actors ahead of us along our travel heading
		if forward_dist <= 0.2:
			continue
		# Squadmates on the same patrol route do not pass each other head-on
		if "patrol_points" in other and "patrol_points" in actor:
			var other_patrol: Array = other.get("patrol_points")
			var my_patrol: Array = actor.get("patrol_points")
			if not my_patrol.is_empty() and other_patrol == my_patrol:
				continue
		# Actors moving in our travel direction are marching ahead, not oncoming
		var other_vel := other.velocity
		other_vel.y = 0.0
		if other_vel.length_squared() > 0.05 and dir.dot(other_vel.normalized()) > 0.1:
			continue
		# Lateral offset: only pass if other is within the corridor width and not already to our right
		var lat_dist := right.dot(rel)
		if lat_dist > 0.35 or lat_dist < -1.5:
			continue
		var ahead := 0.5 if dist < 1.5 else 0.8
		var wanted := here + dir * ahead + right * 0.45
		var spot := NavigationServer3D.map_get_closest_point(level.navigation_map, wanted)
		if absf(spot.y - here.y) <= 1.0 and Vector2(spot.x - here.x, spot.z - here.z).length() > 0.1:
			return spot
	return target


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
	var look_point := points[min(index + 1, points.size() - 1)] if index < points.size() - 1 and Vector2(points[index].x - here.x, points[index].z - here.z).length() < 0.9 else points[index]
	var avoiding := _avoid_corridor_npc(here, look_point) != look_point
	while index < points.size() - 1:
		var offset := points[index] - here
		var reach := 0.55 if avoiding else 0.25
		if Vector2(offset.x, offset.z).length() > reach or absf(offset.y) > 1.0:
			break
		index += 1
	while not doors.is_empty() and index > int(doors[0]["segment"]) + 1:
		doors.pop_front()
	if _locked_ahead():
		_plan(goal)
		if status != "moving":
			return here
	if not doors.is_empty():
		var door := doors[0]["door"] as ModularDoor
		if is_instance_valid(door) and here.distance_to(door.global_position) <= DOOR_REACH:
			if not door.open_for(actor):
				status = "waiting_for_door"
				return here
	status = "moving"
	return _avoid_corridor_npc(here, points[index])
