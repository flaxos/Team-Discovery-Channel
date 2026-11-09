extends SceneTree
## Traverse production collision continuously; only route setup places an actor.
var room: GateRoom
var map: SGCMap
var pawn: CharacterBody3D


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)


func run() -> void:
	room = load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	map = room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	check(map.definition.validate().is_empty(), "Invalid map schema")
	check(map.definition.regions.size() == 26, "All three floors must be defined")
	for scene_path: String in [
		"res://scenes/entities/Player.tscn",
		"res://scenes/entities/SGCAirman.tscn",
		"res://scenes/entities/JaffaGuard.tscn"
	]:
		pawn = load(scene_path).instantiate() as CharacterBody3D
		room.add_child(pawn)
		pawn.set_physics_process(false)
		pawn.set_process(false)
		pawn.floor_snap_length = 0.4
		for c in map.definition.connections:
			if c.kind == "lift":
				continue
			if "--vertical" in OS.get_cmdline_user_args() and c.kind == "walk":
				continue
			for reverse: bool in [false, true]:
				var origin := map.definition.region(c.to_region if reverse else c.from_region)
				var target := map.definition.region(c.from_region if reverse else c.to_region)
				pawn.position = origin.anchor + Vector3(0, 0.03, 0)
				pawn.velocity = Vector3.ZERO
				await physics_frame
				var nav := SGCNavigator.new(pawn)
				# Pin to the connection under test; other regions remain traversable for approach.
				for edge in map.definition.connections:
					edge.enabled = edge == c or edge.kind == "walk"
				print("ROUTE ", scene_path, " ", c.id, " reverse=", reverse)
				var success := await walk_to(nav, target.anchor, 1500)
				if not success:
					check(
						false,
						(
							"%s %s reverse=%s stuck at %s status=%s next=%s"
							% [
								scene_path,
								c.id,
								reverse,
								pawn.position,
								(
									nav.status
									+ " collision="
									+ str(
										(
											[
												pawn.get_last_slide_collision().get_collider(),
												pawn.get_last_slide_collision().get_normal(),
												pawn.get_last_slide_collision().get_position(),
												pawn.is_on_floor(),
												pawn.velocity
											]
											if pawn.get_slide_collision_count() > 0
											else []
										)
									)
								),
								nav.steps.front() if not nav.steps.is_empty() else {}
							]
						)
					)
					return
				nav.reset()
				for edge in map.definition.connections:
					edge.enabled = true
		print("PASS continuous portal/stair routes: ", scene_path)
		pawn.queue_free()
		await process_frame
	await preload("res://tests/support/finish.gd").success(self)


func walk_to(nav: SGCNavigator, goal: Vector3, limit: int) -> bool:
	for i in range(limit):
		var next := nav.next_position(goal)
		var dir := next - pawn.position
		dir.y = 0
		if dir.length() > 0.01:
			dir = dir.normalized()
		pawn.velocity.x = dir.x * 3.0
		pawn.velocity.z = dir.z * 3.0
		if not pawn.is_on_floor():
			pawn.velocity.y -= 9.8 / 60.0
		else:
			pawn.velocity.y = 0
		pawn.move_and_slide()
		await physics_frame
		if pawn.position.distance_to(goal) < 0.65:
			return true
		if pawn.position.y < -3:
			return false
	return false
