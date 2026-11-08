extends SceneTree
var room: GateRoom
var lift: SGCElevator
var pawn: CharacterBody3D


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(
			(
				message
				+ " position="
				+ str(pawn.position)
				+ " collision="
				+ str(
					(
						pawn.get_last_slide_collision().get_collider()
						if pawn.get_slide_collision_count() > 0
						else null
					)
				)
			)
		)
		quit(1)


func frames(count: int) -> void:
	for i in range(count):
		if pawn != null:
			if not pawn.is_on_floor():
				pawn.velocity.y -= 9.8 / 60.0
			pawn.velocity.x = 0
			pawn.velocity.z = 0
			pawn.move_and_slide()
		await physics_frame


func walk(goal: Vector3) -> bool:
	for i in range(400):
		var dir := goal - pawn.position
		dir.y = 0
		if dir.length() < 0.15:
			return true
		dir = dir.normalized()
		pawn.velocity.x = dir.x * 2
		pawn.velocity.z = dir.z * 2
		if not pawn.is_on_floor():
			pawn.velocity.y -= 9.8 / 60.0
		else:
			pawn.velocity.y = 0
		pawn.move_and_slide()
		await physics_frame
	return false


func run() -> void:
	room = load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	lift = room.get_node("SGCElevator") as SGCElevator
	pawn = load("res://scenes/entities/Player.tscn").instantiate() as CharacterBody3D
	room.add_child(pawn)
	pawn.set_physics_process(false)
	pawn.set_process(false)
	pawn.position = Vector3(33, 0.03, 18)
	pawn.floor_snap_length = 0.4
	lift.call_elevator(28)
	await frames(70)
	check(await walk(Vector3(37, 0, 18)), "Startup cabin lip must be passable")
	for floor_number: int in [27, 26, 28]:
		lift.select_floor(floor_number)
		await frames(300)
		check(lift.current_floor == floor_number, "Lift must arrive on requested floor")
		check(
			absf(pawn.position.y - lift.get_floor_y(floor_number)) < 0.12,
			"Moving cabin must physically carry rider"
		)
		check(
			await walk(Vector3(33, lift.get_floor_y(floor_number), 17.5)),
			"Diagonal exit must clear landing"
		)
		check(
			await walk(Vector3(37, lift.get_floor_y(floor_number), 18)),
			"Landing entry must be flush"
		)
	lift.select_floor(27)
	lift.call_elevator(26)
	await frames(650)
	check(lift.current_floor == 26, "Calls made during transit must be queued")
	lift.select_floor(25)
	await frames(3)
	check(not lift.is_moving, "Level 25 must be excluded")
	print("PASS three-level lift entry, carrying, exits, call queue and excluded floor")
	await preload("res://tests/support/finish.gd").success(self)
