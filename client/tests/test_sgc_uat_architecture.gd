extends SceneTree
var pawn: PlayerController3D
var room: GateRoom
var lift: SGCElevator


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func ride(floor_number: int) -> void:
	lift.select_floor(floor_number)
	var max_gap := 0.0
	for i in range(600):
		await physics_frame
		max_gap = maxf(max_gap, absf(pawn.global_position.y - lift.cabin.global_position.y))
		if not lift.is_moving and lift.current_floor == floor_number:
			break
	check(lift.current_floor == floor_number, "Lift must reach selected floor")
	check(
		max_gap < 0.15,
		"Live controller must remain grounded throughout travel, max gap=" + str(max_gap)
	)


func run() -> void:
	room = load("res://scenes/main/SGCUATBase.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	check(
		map.definition.region(&"CONTROL_ROOM").floor_offset == 1.5,
		"Operations must overlook embarkation floor"
	)
	check(
		map.definition.region(&"GATE_ROOM").footprint.size.x == 24,
		"Atrium must use corrected scale"
	)
	for connection in map.definition.connections:
		check(
			connection.from_region != &"GATE_ROOM" or connection.to_region != &"CONTROL_ROOM",
			"No direct gate/control doorway"
		)

	check(
		get_nodes_in_group("sgc_ceiling").size() >= map.definition.regions.size(),
		"Every region needs a ceiling"
	)
	for r in map.definition.regions:
		if r.id in [&"SERVICE_STAIRWELL", &"SERVICE_ROOM"]:
			continue
		var from := r.anchor + Vector3(0, 2.0, 0)
		var hit := room.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 15, 0), 129)
		)
		check(not hit.is_empty(), "Missing physical ceiling above " + str(r.id))
	var space := room.get_world_3d().direct_space_state
	check(
		not (
			space
			. intersect_ray(
				PhysicsRayQueryParameters3D.create(Vector3(5, 1, 6), Vector3(5, 1, 10), 1)
			)
			. is_empty()
		),
		"Control front must be sealed"
	)
	var console := (
		room.get_node("Level28Complex/ControlRoomMezzanine/ControlWindowConsole")
		as BlastDoorConsole
	)
	console.interact()
	await frames(90)
	check(room.is_control_window_closed, "Control console must close its shutter")
	room.toggle_observation_shutters(true)
	await frames(90)
	var glass := room.find_child("BriefingGateRoomOverlook", true, false) as CSGBox3D
	var shutter := room.find_child("BriefingBlastShutters", true, false) as CSGBox3D
	check(
		shutter.position.z - shutter.size.z / 2 > glass.position.z + glass.size.z / 2,
		"Shutter and glass must not overlap"
	)
	check(absf(shutter.position.y - 7.4) < 0.01, "Shutter must align with its window")
	pawn = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	pawn.name = "1"
	room.get_node("Players").add_child(pawn)
	lift = room.get_node("SGCElevator") as SGCElevator
	pawn.position = lift.cabin.global_position + Vector3(0, 0.02, 0)
	lift.call_elevator(28)
	await frames(70)
	lift.interact(pawn)
	check(
		is_instance_valid(pawn.lift_floor_dialog) and pawn.lift_floor_dialog.visible,
		"E in cabin must expose floor selection"
	)
	var floor_button: Button
	for candidate in pawn.lift_floor_dialog.find_children("*", "Button", true, false):
		if candidate.text == "Level 26":
			floor_button = candidate
	check(floor_button != null and not floor_button.disabled, "Picker must offer Level 26")
	floor_button.pressed.emit()
	check(lift.destination_floor == 26 and lift.is_moving, "Picker must dispatch the chosen floor")
	check(not pawn.lift_floor_dialog.visible, "Picker must close after selection")
	await ride(26)
	await frames(70)
	lift.interact(pawn)
	for candidate in pawn.lift_floor_dialog.find_children("*", "Button", true, false):
		if candidate.text == "Level 28":
			candidate.pressed.emit()
	check(lift.destination_floor == 28 and lift.is_moving, "Picker must dispatch Level 28 independently")
	await ride(28)
	check(pawn.is_on_floor(), "Rider must finish grounded")
	# Aim at the middle button while standing in the same cabin position.
	var button := lift.get_node("Cabin/CabinControlPanel27") as Node3D
	pawn.camera.global_position = pawn.position + Vector3(0, 1.6, 0)
	pawn.camera.look_at(button.global_position)
	check(pawn.aimed_interactable() == button, "Sightline must select the intended floor button")
	pawn._try_interact()
	check(
		lift.destination_floor == 27 and lift.is_moving,
		"Aimed E interaction must dispatch chosen floor"
	)
	print(
		"PASS roof coverage, sealed raised operations, shutter alignment, dynamic buttons and continuous live lift grounding"
	)
	await preload("res://tests/support/finish.gd").success(self)
