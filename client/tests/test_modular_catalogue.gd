extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")
const Canvas = preload("res://addons/modular_editor/canvas.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var ids := {}
	var canvas := Canvas.new()
	root.add_child(canvas)
	for name: String in LevelCatalogue.MODULES:
		var module := (
			load("res://resources/level_modules/" + name + ".tres") as LevelModuleDefinition
		)
		assert(module != null and not ids.has(module.id))
		ids[module.id] = true
		for turn in range(4):
			var layout := LevelLayout.new()
			var item := LevelModuleInstance.new()
			item.id = &"tested"
			item.module = module
			item.quarter_turn = turn
			layout.instances.append(item)
			layout.entry_instance = item.id
			layout.destination_instance = item.id
			assert(LevelLayoutValidator.validate(layout).is_empty())
			var rect := canvas.footprint(item, item.position)
			var expected := Vector2(module.occupied.size.x, module.occupied.size.z)
			if turn % 2 == 1:
				expected = Vector2(expected.y, expected.x)
			assert(rect.size.is_equal_approx(expected))
			# Every archetype and orientation must have a real enclosed navigable shell.
			var assembly := LevelAssembly.new()
			assembly.layout = layout
			root.add_child(assembly)
			await assembly.navigation_ready
			assert(assembly.last_errors.is_empty(), name + str(assembly.last_errors))
			for socket in module.sockets:
				var approach := item.placement(0) * socket.approach
				var path := assembly.local_path(assembly.marker(item.id, &"entry"), approach)
				assert(
					not path.is_empty() and path[-1].distance_to(approach) < .5,
					name + "/" + str(socket.id)
				)
			assembly.queue_free()
			await process_frame
		# Attach a matching corridor to every socket without occupying the chamber.
		for socket in module.sockets:
			var layout := LevelLayout.new()
			var a := LevelModuleInstance.new()
			a.id = &"a"
			a.module = module
			var b := LevelModuleInstance.new()
			b.id = &"b"
			b.module = load(
				(
					"res://resources/level_modules/Room06WideStraight.tres"
					if socket.width == 6
					else "res://resources/level_modules/Room01Straight.tres"
				)
			)
			b.position = Vector2(100, 100)
			layout.instances.assign([a, b])
			layout.entry_instance = a.id
			layout.destination_instance = b.id
			assert(LevelAssembler.snap(layout, b.id, &"north", a.id, socket.id).is_empty())
			var assembly := LevelAssembly.new()
			assembly.layout = layout
			root.add_child(assembly)
			await assembly.navigation_ready
			assert(assembly.last_errors.is_empty())
			var start := assembly.marker(a.id, &"entry")
			var goal := assembly.marker(b.id, &"entry")
			var path := assembly.local_path(start, goal)
			assert(not path.is_empty() and path[-1].distance_to(goal) < .5)
			for scene: String in ["Player", "SGCAirman", "JaffaGuard"]:
				var pawn := (
					load("res://scenes/entities/" + scene + ".tscn").instantiate()
					as CharacterBody3D
				)
				pawn.name = "1"
				assembly.add_child(pawn)
				pawn.set_physics_process(false)
				pawn.set_process(false)
				pawn.floor_snap_length = .4
				await walk(pawn, assembly, start, goal)
				await walk(pawn, assembly, goal, start)
				pawn.queue_free()
				await process_frame
			assembly.queue_free()
			await process_frame
	# Adjacent small modules connect independently along a long wall.
	var model := Model.new()
	var long_room := (
		load("res://resources/level_modules/Room10LongChamber.tres") as LevelModuleDefinition
	)
	var straight := (
		load("res://resources/level_modules/Room01Straight.tres") as LevelModuleDefinition
	)
	model.restore(model.placed(long_room, Vector2.ZERO, 0))
	model.restore(model.placed(straight, Vector2(8, 0), 1))
	model.restore(model.placed(straight, Vector2(8, 8), 1))
	assert(
		(
			model.layout.connections.size() == 2
			and LevelLayoutValidator.validate(model.layout).is_empty()
		)
	)
	canvas.model = model
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = canvas.screen(Vector2(0, 8))
	canvas._gui_input(click)
	assert(
		canvas.selected == model.layout.instances[0].id, "Select the far cell of a multi-cell room"
	)
	var original := Model.copy(model.layout)
	assert(not model.accepted(model.placed(long_room, Vector2(0, 8), 1)))
	assert(model.layout.instances.size() == 3)
	original.connections[0].state = "open"
	assert(
		(
			LevelAssembler.connect_touching(original).is_empty()
			and original.connections[0].state == "open"
		)
	)
	assert(ResourceSaver.save(original, "user://catalogue_roundtrip.tres") == OK)
	var reopened := load("user://catalogue_roundtrip.tres") as LevelLayout
	assert(LevelLayoutValidator.validate(reopened).is_empty())
	canvas.free()
	print(
		"PASS catalogue shells, rotations, every socket navigation, multi-cell joins, overlap rollback and preserved connection choices"
	)
	await preload("res://tests/support/finish.gd").success(self)


func walk(pawn: CharacterBody3D, assembly: LevelAssembly, start: Vector3, goal: Vector3) -> void:
	pawn.position = start + Vector3(0, .03, 0)
	pawn.velocity = Vector3.ZERO
	await physics_frame
	var path := assembly.local_path(start, goal)
	var index := 0
	for tick in range(2400):
		var direction := path[index] - pawn.position
		direction.y = 0
		if direction.length() < .15 and index < path.size() - 1:
			index += 1
			continue
		direction = direction.normalized()
		pawn.velocity = Vector3(direction.x * 4, -.5, direction.z * 4)
		pawn.move_and_slide()
		await physics_frame
		if pawn.position.distance_to(goal) < .45:
			return
	assert(false, "Production capsule blocked at " + str(pawn.position) + " toward " + str(goal))
