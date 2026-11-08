class_name SGCNavigator
extends RefCounted
## Stateful traversal shared by both factions. Never changes actor position or invents vertical velocity.
var actor: CharacterBody3D
var map: SGCMap
var destination := Vector3.INF
var steps: Array[Dictionary] = []
var status: String = "idle"
var blocked: Array[StringName] = []
var last_position := Vector3.INF
var stall_time: float = 0.0
var held_passage: StringName = &""
var local_points := PackedVector3Array()
var local_goal := Vector3.INF
var retry_time: float = 0.0
var lift_phase: int = 0


func _init(body: CharacterBody3D) -> void:
	actor = body
	actor.floor_snap_length = 0.4


func _find_map() -> bool:
	if not is_instance_valid(map):
		var parent := actor.get_parent()
		while parent != null:
			if parent.has_node("SGCMap"):
				map = parent.get_node("SGCMap") as SGCMap
				break
			parent = parent.get_parent()
	return map != null and map.ready_for_navigation


func _release() -> void:
	if map != null and held_passage != &"":
		map.release_passage(held_passage, actor)
	held_passage = &""


func reset() -> void:
	_release()
	steps.clear()
	local_points.clear()
	destination = Vector3.INF
	lift_phase = 0


func _plan(goal: Vector3) -> void:
	_release()
	steps.clear()
	local_points.clear()
	local_goal = Vector3.INF
	destination = goal
	lift_phase = 0
	var here := map.definition.region_at(actor.global_position)
	var there := map.definition.region_at(goal)
	if here == &"" or there == &"":
		status = "unreachable"
		return
	var route := map.definition.route(here, there, blocked)
	if here != there and route.is_empty():
		status = "unreachable"
		return
	for c in route:
		var points := c.oriented_points(here)
		if c.kind == "lift":
			steps.append(
				{
					"point": points[0],
					"connection": c,
					"kind": "lift",
					"from": here,
					"to": c.other(here)
				}
			)
		elif c.kind in ["stairs", "spiral"]:
			var approach := points[0]
			if c.kind == "spiral" and here == c.to_region:
				approach += Vector3(0, 0, 1.4)
			elif c.kind == "stairs":
				var away := points[0] - points[-1]
				away.y = 0
				approach += away.normalized() * 0.8
			steps.append({"point": approach, "connection": c, "kind": "approach"})
			for p in points:
				steps.append({"point": p, "connection": c, "kind": "surface"})
			var exit := points[-1]
			if c.kind == "spiral":
				exit += Vector3(0, 0, 1.4) if here == c.from_region else Vector3(0, 0, -1.0)
			else:
				var dir := points[-1] - points[0]
				dir.y = 0
				exit += dir.normalized() * 0.6
			steps.append({"point": exit, "connection": c, "kind": "surface_exit"})
		else:
			var next := map.definition.region(c.other(here))
			var direction := next.anchor - points[0]
			direction.y = 0
			steps.append(
				{"point": points[0] + direction.normalized() * 0.8, "connection": c, "kind": "walk"}
			)
		here = c.other(here)
	steps.append({"point": goal, "kind": "goal"})
	status = "moving"


func next_position(goal: Vector3, delta: float = 1.0 / 60.0) -> Vector3:
	if not _find_map():
		status = "waiting_for_navigation"
		return actor.global_position
	if destination == Vector3.INF or destination.distance_to(goal) > 0.5:
		blocked.clear()
		_plan(goal)
	if status == "unreachable":
		retry_time += delta
		if retry_time > 1.0:
			retry_time = 0.0
			blocked.clear()
			_plan(goal)
		return actor.global_position
	if actor.global_position.distance_to(goal) < 0.5:
		status = "arrived"
		_release()
		return actor.global_position
	if last_position == Vector3.INF or actor.global_position.distance_to(last_position) > 0.15:
		last_position = actor.global_position
		stall_time = 0.0
	else:
		stall_time += delta
	if stall_time > 5.0 and not steps.is_empty():
		var c := steps[0].get("connection") as SGCConnection
		if c != null and steps[0]["kind"] in ["walk", "approach"]:
			blocked.append(c.id)
		stall_time = 0.0
		_plan(goal)
		if status == "unreachable":
			return actor.global_position
	while not steps.is_empty():
		var step := steps[0]
		var p: Vector3 = step["point"]
		var c := step.get("connection") as SGCConnection
		if c != null and not c.enabled:
			blocked.append(c.id)
			_plan(goal)
			return actor.global_position
		if step["kind"] == "lift":
			return _lift(step)
		var tolerance: float = 0.25 if step["kind"] == "surface" else 0.5
		if actor.global_position.distance_to(p) < tolerance:
			steps.pop_front()
			local_points.clear()
			local_goal = Vector3.INF
			if step["kind"] == "surface_exit":
				_release()
			continue
		if c != null and c.door and bool(map.room.get("is_blast_doors_closed")):
			status = "waiting_for_door"
			# Door controls are server-owned; opening is replicated before crossing.
			if not bool(map.room.get("is_animating_doors")):
				map.room.toggle_blast_doors()
			return actor.global_position
		if c != null and step["kind"] in ["approach", "surface"]:
			if held_passage != c.id:
				if not map.claim_passage(c.id, actor):
					status = "waiting_for_passage"
					return actor.global_position
				held_passage = c.id
		status = "moving"
		if step["kind"] in ["surface", "surface_exit"]:
			return p
		return _local_next(p)
	status = "arrived"
	_release()
	return actor.global_position


func _local_next(p: Vector3) -> Vector3:
	if local_goal == Vector3.INF or local_goal.distance_to(p) > 0.2 or local_points.is_empty():
		local_goal = p
		local_points = map.local_path(actor.global_position, p)
		if local_points.is_empty() or local_points[-1].distance_to(p) > 1.2:
			status = "unreachable_local"
			return actor.global_position
	while (
		local_points.size() > 1
		and (
			(
				Vector2(
					actor.global_position.x - local_points[0].x,
					actor.global_position.z - local_points[0].z
				)
				. length()
			)
			< 0.05
		)
		and absf(actor.global_position.y - local_points[0].y) < 0.5
	):
		local_points.remove_at(0)
	return local_points[0] if not local_points.is_empty() else actor.global_position


func _lift(step: Dictionary) -> Vector3:
	var c := step["connection"] as SGCConnection
	var lift := map.room.get_node("SGCElevator") as SGCElevator
	var from := map.definition.region(step["from"]).floor_number
	var to := map.definition.region(step["to"]).floor_number
	if held_passage != &"lift":
		if not map.claim_passage(&"lift", actor):
			status = "waiting_for_lift"
			return actor.global_position
		held_passage = &"lift"
	var lobby: Vector3 = step["point"]
	if lift_phase == 0:
		if actor.global_position.distance_to(lobby) > 0.6:
			return _local_next(lobby)
		lift.call_elevator(from)
		if not lift.is_moving and lift.current_floor == from and lift.is_doors_open:
			lift_phase = 1
		return actor.global_position
	var cabin := lift.cabin.global_position
	if lift_phase == 1:
		if actor.global_position.distance_to(cabin) > 0.45:
			return cabin
		lift.select_floor(to)
		lift_phase = 2
		return actor.global_position
	if lift_phase == 2:
		status = "riding_lift"
		if lift.is_moving or lift.current_floor != to or not lift.is_doors_open:
			return actor.global_position
		lift_phase = 3
	var exit := Vector3(lobby.x, map.definition.FLOOR_HEIGHTS[to], lobby.z)
	if actor.global_position.distance_to(exit) > 0.5:
		return exit
	steps.pop_front()
	lift_phase = 0
	_release()
	local_points.clear()
	return actor.global_position
