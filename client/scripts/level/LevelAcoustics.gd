class_name LevelAcoustics
extends RefCounted
## Wall, floor and doorway acoustic attenuation for sentry hearing on modular levels.
## Named without self-references so GDScript never holds a static exit cycle.

const WALL_ATTENUATION := 12.0
const CLOSED_DOOR_ATTENUATION := 6.0
const PARTITION_MERGE_DISTANCE := 0.75
const MAX_RAY_STEPS := 8


static func effective_distance(world: World3D, level: LevelAssembly, origin: Vector3, listener: Vector3) -> float:
	var report := analyze(world, level, origin, listener)
	return float(report["effective"])


static func analyze(world: World3D, level: LevelAssembly, origin: Vector3, listener: Vector3) -> Dictionary:
	var direct := origin.distance_to(listener)
	var start_room := _room_at(level, origin)
	var end_room := _room_at(level, listener)
	if start_room != &"" and start_room == end_room:
		return {
			"direct": direct,
			"direct_effective": direct,
			"corridor_effective": direct,
			"effective": direct,
			"wall_count": 0,
			"closed_door_count": 0
		}

	var barriers := _trace_direct_barriers(world, origin + Vector3.UP * 1.1, listener + Vector3.UP * 1.4)
	var wall_count: int = int(barriers["walls"])
	var closed_door_count: int = int(barriers["closed_doors"])
	var direct_effective := direct + wall_count * WALL_ATTENUATION + closed_door_count * CLOSED_DOOR_ATTENUATION
	var corridor_effective := _corridor_distance(level, origin, listener, start_room, end_room)
	var effective := minf(direct_effective, corridor_effective)
	return {
		"direct": direct,
		"direct_effective": direct_effective,
		"corridor_effective": corridor_effective,
		"effective": effective,
		"wall_count": wall_count,
		"closed_door_count": closed_door_count
	}


static func _room_at(level: LevelAssembly, world_pos: Vector3) -> StringName:
	if level == null or level.layout == null:
		return &""
	var sample := world_pos + Vector3.UP * 0.5
	for item in level.layout.instances:
		if item == null or item.module == null:
			continue
		var mod := level.get_node_or_null(str(item.id)) as Node3D
		if mod != null and item.module.occupied.grow(0.05).has_point(mod.to_local(sample)):
			return item.id
	return &""


static func _is_prop_collider(node: Node) -> bool:
	var cur := node
	for _i in range(4):
		if cur == null:
			return false
		if cur is LevelPlaceholderProp or cur is DeployableShield:
			return true
		cur = cur.get_parent()
	return false


static func _trace_direct_barriers(world: World3D, from_pt: Vector3, to_pt: Vector3) -> Dictionary:
	if world == null:
		return {"walls": 0, "closed_doors": 0}
	var space := world.direct_space_state
	if space == null:
		return {"walls": 0, "closed_doors": 0}
	var delta := to_pt - from_pt
	var total_len := delta.length()
	if total_len < 0.05:
		return {"walls": 0, "closed_doors": 0}
	var dir := delta / total_len
	var cur_from := from_pt
	var exclude: Array[RID] = []
	var walls := 0
	var closed_doors := 0
	var last_wall_pos := Vector3.INF
	for _step in range(MAX_RAY_STEPS):
		var query := PhysicsRayQueryParameters3D.create(cur_from, to_pt, 1, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var rid: RID = hit.get("rid", RID())
		if rid.is_valid():
			exclude.append(rid)
		var collider := hit.get("collider") as Node
		var hit_pos: Vector3 = hit.get("position", cur_from)
		if collider is ModularDoor:
			closed_doors += 1
		elif not _is_prop_collider(collider):
			if last_wall_pos == Vector3.INF or hit_pos.distance_to(last_wall_pos) >= PARTITION_MERGE_DISTANCE:
				walls += 1
				last_wall_pos = hit_pos
		cur_from = hit_pos + dir * 0.05
		if cur_from.distance_to(to_pt) < 0.05 or cur_from.distance_to(from_pt) >= total_len:
			break
	return {"walls": walls, "closed_doors": closed_doors}


static func _find_portal_door(level: LevelAssembly, index: int, portal_pos: Vector3) -> ModularDoor:
	var by_index := level.get_node_or_null("Door_%03d" % index) as ModularDoor
	if by_index != null:
		return by_index
	for child in level.get_children():
		var door := child as ModularDoor
		if door != null:
			var offset := door.global_position - portal_pos
			if Vector2(offset.x, offset.z).length() <= 1.5 and absf(offset.y) <= 2.0:
				return door
	return null


static func _corridor_distance(
	level: LevelAssembly,
	origin: Vector3,
	listener: Vector3,
	start_room: StringName,
	end_room: StringName
) -> float:
	if level == null or level.layout == null or start_room == &"" or end_room == &"":
		return INF
	if start_room == end_room:
		return origin.distance_to(listener)

	var adj := {}
	for item in level.layout.instances:
		if item != null:
			adj[item.id] = []
	for i in range(level.layout.connections.size()):
		var conn := level.layout.connections[i]
		if conn == null or not adj.has(conn.from_instance) or not adj.has(conn.to_instance):
			continue
		var mod_a := level.get_node_or_null(str(conn.from_instance)) as Node3D
		var mod_b := level.get_node_or_null(str(conn.to_instance)) as Node3D
		var item_a := level.layout.instance(conn.from_instance)
		var sock_a := item_a.module.socket(conn.from_socket) if (item_a != null and item_a.module != null) else null
		var portal_pos := origin
		if mod_a != null and sock_a != null:
			portal_pos = mod_a.global_transform * sock_a.local_transform.origin
		elif mod_a != null and mod_b != null:
			portal_pos = (mod_a.global_position + mod_b.global_position) * 0.5
		var door := _find_portal_door(level, i, portal_pos)
		var penalty := CLOSED_DOOR_ATTENUATION if (door != null and not door.is_open) else 0.0
		adj[conn.from_instance].append({"to": conn.to_instance, "pos": portal_pos, "penalty": penalty})
		adj[conn.to_instance].append({"to": conn.from_instance, "pos": portal_pos, "penalty": penalty})

	var best_cost := {start_room: 0.0}
	var best_pos := {start_room: origin}
	var visited := {}
	var best_goal := INF
	var room_count: int = adj.size()
	for _iter in range(room_count):
		var u: StringName = &""
		var u_cost := INF
		for room_id: StringName in best_cost:
			if visited.has(room_id):
				continue
			var c := float(best_cost[room_id])
			if c < u_cost:
				u_cost = c
				u = room_id
		if u == &"" or u_cost >= best_goal:
			break
		visited[u] = true
		var u_pos: Vector3 = best_pos[u]
		for edge: Dictionary in adj.get(u, []):
			var v: StringName = edge["to"]
			var p: Vector3 = edge["pos"]
			var step_cost := u_pos.distance_to(p) + float(edge["penalty"])
			var next_cost := u_cost + step_cost
			if v == end_room:
				best_goal = minf(best_goal, next_cost + p.distance_to(listener))
			elif next_cost < float(best_cost.get(v, INF)):
				best_cost[v] = next_cost
				best_pos[v] = p
	return best_goal
