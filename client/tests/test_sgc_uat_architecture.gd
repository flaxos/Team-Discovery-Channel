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
	var table := room.get_node(^"Level27Complex/BriefingRoom/ConferenceTable") as CSGBox3D
	var desk := room.get_node(^"Level27Complex/GeneralsOffice/HammondsDesk") as CSGBox3D
	var wood := table.material as StandardMaterial3D
	check(table.use_collision and table.size == Vector3(2.4, 0.8, 5.5), "Briefing table retains its cover volume")
	check(desk.use_collision and desk.size == Vector3(2.8, 0.8, 1.6), "Command desk retains its cover volume")
	check(wood != null and desk.material == wood and wood.uv1_triplanar, "Both fixtures use one fitted wood material")
	check(wood != null and wood.albedo_texture != null and wood.normal_enabled and wood.normal_texture != null
		and wood.ao_texture == wood.roughness_texture and wood.ao_texture != null, "Wood uses source colour, normal and packed surface data")
	if wood != null:
		for texture: Texture2D in [wood.albedo_texture, wood.normal_texture, wood.ao_texture]:
			check(texture != null and texture.get_size() == Vector2(1024, 1024) and texture.get_image().has_mipmaps(),
				"The shared wood maps need 1K resolution and mipmaps")
	check_furniture_profile(table, table.size)
	check_furniture_profile(desk, desk.size)
	for side: String in ["West", "East"]:
		for i in range(1, 4):
			var chair := room.get_node("Level27Complex/BriefingRoom/Chair%s%d" % [side, i]) as CSGBox3D
			check_furniture_profile(chair, Vector3(0.6, 0.6, 0.6))
	check_furniture_profile(room.get_node(^"Level27Complex/GeneralsOffice/ExecutiveChair") as CSGBox3D,
		Vector3(0.7, 1, 0.7))
	await check_furniture_fade(table)
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
	var briefing_console := room.get_node(^"Level27Complex/BriefingRoom/BriefingBlastDoorConsole") as BlastDoorConsole
	var status := room.get_node(^"Level27Complex/BriefingRoom/ObservationBoard/ShutterStatus") as Label3D
	var glass := room.find_child("BriefingGateRoomOverlook", true, false) as CSGBox3D
	check(status.text.ends_with("OPEN"), "Briefing board shows open at load")
	for side: float in [-1.0, 1.0]:
		var p := glass.global_position + Vector3(0.13, 0.09, 0)
		var through := Vector3(0, 0, side * 0.65)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + through, p - through, 1))
		check(hit.get("collider") == glass, "The open-shutter pane remains sealed from both sides")
	console.interact()
	await frames(90)
	check(room.is_control_window_closed, "Control console must close its shutter")
	check(status.text.ends_with("OPEN"), "Control shutter leaves the briefing readout alone")
	briefing_console.interact()
	await frames(90)
	check(status.text.ends_with("SEALED"), "Briefing readout follows the existing shutter command")
	var shutter := room.find_child("BriefingBlastShutters", true, false) as CSGBox3D
	check(
		shutter.position.z - shutter.size.z / 2 > glass.position.z + glass.size.z / 2,
		"Shutter and glass must not overlap"
	)
	check(absf(shutter.position.y - 7.4) < 0.01, "Shutter must align with its window")
	briefing_console.interact()
	await frames(90)
	check(status.text.ends_with("OPEN") and room.is_control_window_closed, "Briefing opens independently")
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
	# Retire lift-floor and call-area overlaps before disposing the exported world.
	pawn.collision_layer = 0
	await frames(3)
	pawn.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)


func check_furniture_profile(body: CSGBox3D, size: Vector3) -> void:
	var visual := body.get_node_or_null(^"ReplacementVisual") as MeshInstance3D
	check(body.use_collision and body.size == size and body.transparency == 1.0, "Authored furniture collider retains its envelope")
	check(visual != null and visual.mesh != null and visual.material_override != null, "Fitted furniture is present")
	if visual != null and visual.mesh != null:
		check(AABB(-size / 2.0, size).grow(0.002).encloses(visual.transform * visual.get_aabb()), "Furniture must fit its authored collider")


func check_furniture_fade(table: CSGBox3D) -> void:
	var visual := table.get_node(^"ReplacementVisual") as MeshInstance3D
	var finish := visual.material_override
	var operative := preload("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	operative.name = "1"
	room.players_container.add_child(operative)
	operative.set_physics_process(false)
	operative.is_crouch_toggled = true
	for side: float in [-1.0, 1.0]:
		operative.global_position = table.global_position + Vector3(side * 2.25, -0.4, 1.05)
		operative._process_cover_and_peeking(0.1, Vector3.ZERO)
		await physics_frame
		operative.camera.global_position = table.global_position + Vector3(-side * 2.5, 0.17, 1.05)
		operative._update_wall_occlusion()
		check(operative.occluded_nodes.has(visual) and visual.material_override != finish, "The visible table fades from either aisle")
		operative.camera.global_position = table.global_position + Vector3(side * 3.0, 0.17, 1.05)
		operative._update_wall_occlusion()
		check(visual.material_override == finish, "Clearing occlusion restores the exact finish")
	operative.collision_layer = 0
	await frames(3)
	operative.queue_free()
	await process_frame
