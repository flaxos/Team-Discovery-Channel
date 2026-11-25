extends RefCounted
## Resolve a player's order against the live layout and the Airmen in that world.

const MAX_ORDER_RANGE := 40.0
const NO_ROUTE := "NO REACHABLE SQUAD POSITION"


static func apply(
	world: GateRoom, level: LevelAssembly, issuer: PlayerController3D, command: int,
	aim: Vector3, target: Node
) -> Dictionary:
	var active: Array[SGCAirmanAI] = []
	if world.allies_container != null:
		for member: Node in world.allies_container.get_children():
			var airman := member as SGCAirmanAI
			if airman != null and airman.health_component != null and airman.is_physics_processing():
				var health := airman.health_component
				if not (health.is_dead or health.is_downed or health.is_stunned or health.frozen):
					active.append(airman)
	if active.is_empty():
		return {"message": "NO ACTIVE AIRMEN AVAILABLE"}
	if not aim.is_finite() or aim.distance_to(issuer.global_position) > MAX_ORDER_RANGE:
		return {"message": "SQUAD ORDER OUT OF RANGE"}
	active.sort_custom(func(a: SGCAirmanAI, b: SGCAirmanAI) -> bool:
		return a.global_position.distance_squared_to(issuer.global_position) < b.global_position.distance_squared_to(issuer.global_position)
	)
	var nearest := active[0]
	if command == RadialCommandWheel.CMD_REGROUP_ON_ME:
		var rally := Vector3.INF
		for airman: SGCAirmanAI in active:
			var spot := _anchor(world, level, airman, issuer.global_position, false, active)
			if not spot.is_empty():
				airman.order_move_to(spot.point)
				if not rally.is_finite():
					rally = spot.point
		return _ack(world, rally, "SQUAD RALLY") if rally.is_finite() else {"message": NO_ROUTE}

	if command == RadialCommandWheel.CMD_MAN_50_CAL or (command == RadialCommandWheel.CMD_CONTEXT_ORDER and target is DeployableTurret):
		var turret := _turret_at(world, aim)
		if turret == null:
			return {"message": "NO AVAILABLE TURRET AT THE PING"}
		nearest.order_mount_turret(turret)
		return _ack(world, turret.global_position, nearest.airman_callsign + " • MAN TURRET")

	if command == RadialCommandWheel.CMD_CONTEXT_ORDER and target is PlayerController3D and target.get_parent() == world.players_container:
		var health: HealthComponent = target.health_component
		if health != null and health.is_downed and not health.is_dead and target.global_position.distance_to(aim) <= 2.0:
			nearest.order_revive(target)
			return _ack(world, target.global_position, nearest.airman_callsign + " • REVIVE")

	if command == RadialCommandWheel.CMD_SUPPRESS_HALLWAY:
		var muzzle := nearest.global_position + Vector3.UP * 1.2
		var facing := _heading(muzzle, aim, -nearest.global_basis.z)
		var distance := Vector2(aim.x - muzzle.x, aim.z - muzzle.z).length()
		var muzzle_end := muzzle + facing * distance
		var query := PhysicsRayQueryParameters3D.create(muzzle, muzzle_end, 1 | 128)
		if distance < 1.0 or distance > nearest.combat_range or absf(muzzle.y - aim.y) > 2.5:
			return {"message": "AIRMAN HAS NO CLEAR FIRING LANE"}
		if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return {"message": "AIRMAN HAS NO CLEAR FIRING LANE"}
		nearest.hold_corner(nearest.global_position, facing, "position")
		nearest.suppress_hallway(facing, 3.0)
		return _ack(world, aim, nearest.airman_callsign + " • COVERING FIRE")

	var anchor := _anchor(world, level, nearest, aim, true, active)
	if anchor.is_empty():
		return {"message": NO_ROUTE}
	var label := "MOVE TO RALLY POINT"
	if anchor.kind == "cover":
		label = "MOVE TO COVER"
	if command == RadialCommandWheel.CMD_HOLD_CORNER:
		label = "HOLD RALLY POINT" if anchor.kind == "rally" else "HOLD COVER"
	if anchor.kind == "cover" or command == RadialCommandWheel.CMD_HOLD_CORNER:
		nearest.hold_corner(anchor.point, anchor.facing, anchor.kind)
	else:
		nearest.order_move_to(anchor.point)
	return _ack(world, anchor.point, nearest.airman_callsign + " • " + label)


static func _anchor(
	world: GateRoom, level: LevelAssembly, airman: SGCAirmanAI, aim: Vector3,
	prefer_cover: bool, teammates: Array[SGCAirmanAI]
) -> Dictionary:
	var floor_point := NavigationServer3D.map_get_closest_point(level.navigation_map, aim)
	if absf(floor_point.y - aim.y) > 3.0 or Vector2(floor_point.x - aim.x, floor_point.z - aim.z).length() > 1.4:
		return {}
	var room_id := StringName(world.get_current_sector(floor_point).to_lower())
	var item := level.layout.instance(room_id)
	if item == null:
		return {}
	var module := level.get_node(str(room_id)) as Node3D
	var options: Array[Dictionary] = []
	if prefer_cover:
		for attachment in LevelRoomComposer.resolved(item):
			if attachment.component != &"cover" or not attachment.reachable:
				continue
			var node := module.get_node_or_null(LevelRoomComposer.node_path(attachment)) as Node3D
			if node != null:
				var spot := node.global_transform * attachment.approach
				options.append({"point": spot, "kind": "cover", "facing": _heading(spot, node.global_position, -module.global_basis.z)})
	for id: String in ["entry", "patrol", "destination"]:
		var marker := module.get_node_or_null("Markers/" + id) as Node3D
		if marker != null:
			# Narrow corridors use the two positions along the lane.
			for offset: Vector3 in [Vector3.ZERO, Vector3.LEFT * 1.3, Vector3.RIGHT * 1.3, Vector3.FORWARD * 1.3, Vector3.BACK * 1.3]:
				var point := marker.to_global(offset)
				options.append({"point": point, "kind": "rally", "facing": _heading(point, aim, -marker.global_basis.z)})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kind != b.kind:
			return a.kind == "cover"
		return aim.distance_squared_to(a.point) < aim.distance_squared_to(b.point)
	)
	for option: Dictionary in options:
		var point: Vector3 = NavigationServer3D.map_get_closest_point(level.navigation_map, option.point)
		if point.distance_to(option.point) > 0.45 or world.get_current_sector(point).to_lower() != str(room_id):
			continue
		if _occupied(airman, point, teammates):
			continue
		if world.players_container.get_children().any(func(actor: Node) -> bool:
			return actor is Node3D and (actor as Node3D).global_position.distance_to(point) < 0.85
		):
			continue
		var path := level.local_path(airman.global_position, point)
		if not path.is_empty() and path[-1].distance_to(point) <= 0.5:
			option.point = point
			return option
	return {}


static func _occupied(airman: SGCAirmanAI, point: Vector3, teammates: Array[SGCAirmanAI]) -> bool:
	for other: SGCAirmanAI in teammates:
		if other == airman:
			continue
		if other.global_position.distance_to(point) < 1.0:
			return true
		if other.current_state == SGCAirmanAI.State.ORDER_MOVE and other.ordered_position.distance_to(point) < 1.0:
			return true
		if other.current_state == SGCAirmanAI.State.HOLD_CORNER and other.current_anchor_position.distance_to(point) < 1.0:
			return true
	return false


static func _turret_at(world: GateRoom, aim: Vector3) -> DeployableTurret:
	var nearest: DeployableTurret
	var reach := 2.5
	for node: Node in MissionWorld.in_group(world, &"turret"):
		var turret := node as DeployableTurret
		if turret != null and turret.mounted_player == null and MissionWorld.of(turret) == world:
			var distance := turret.global_position.distance_to(aim)
			if distance < reach:
				nearest = turret
				reach = distance
	return nearest


static func _heading(from: Vector3, to: Vector3, fallback: Vector3) -> Vector3:
	var direction := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	return fallback if direction.is_zero_approx() else direction


static func _ack(world: GateRoom, point: Vector3, message: String) -> Dictionary:
	var room := world.get_sector_display_name(world.get_current_sector(point))
	return {"point": point, "message": "%s  [%s]" % [message, room]}
