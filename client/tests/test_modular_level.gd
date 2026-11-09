extends SceneTree
var level: LevelAssembly


func _init() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func run() -> void:
	var source := load("res://resources/levels/modular_smoke.tres") as LevelLayout
	assert(LevelLayoutValidator.validate(source).is_empty())
	assert(source.instances.size() == 8)
	# All pairs and rotations share one socket calculation, and failures are transactional.
	for turn in range(4):
		for module_name: String in [
			"Room01Straight", "Room02Corner", "Room03TJunction", "Room04Chamber"
		]:
			var module := (
				load("res://resources/level_modules/" + module_name + ".tres")
				as LevelModuleDefinition
			)
			for socket in module.sockets:
				var layout := LevelLayout.new()
				var a := LevelModuleInstance.new()
				a.id = &"a"
				a.module = module
				a.quarter_turn = turn
				var b := LevelModuleInstance.new()
				b.id = &"b"
				b.module = module
				b.position = Vector2(100, 100)
				layout.instances.assign([a, b])
				layout.entry_instance = &"a"
				layout.destination_instance = &"b"
				assert(LevelAssembler.snap(layout, b.id, socket.id, a.id, socket.id).is_empty())
				assert(LevelLayoutValidator.validate(layout).is_empty())
				var old := b.position
				assert(not LevelAssembler.snap(layout, b.id, socket.id, a.id, socket.id).is_empty())
				assert(b.position == old and layout.connections.size() == 1)
	var bad := (
		ResourceLoader.load(
			"res://resources/levels/modular_smoke.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	bad.instances[1].id = bad.instances[0].id
	assert(not LevelLayoutValidator.validate(bad).is_empty())
	bad = (
		ResourceLoader.load(
			"res://resources/levels/modular_smoke.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	bad.instances[1].position = bad.instances[0].position
	assert(not LevelLayoutValidator.validate(bad).is_empty())
	bad = (
		ResourceLoader.load(
			"res://resources/levels/modular_smoke.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	bad.connections[0].from_socket = &"missing"
	assert("missing" in str(LevelLayoutValidator.validate(bad)))
	bad = (
		ResourceLoader.load(
			"res://resources/levels/modular_smoke.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	bad.connections.clear()
	assert("Disconnected" in str(LevelLayoutValidator.validate(bad)))
	bad = (
		ResourceLoader.load(
			"res://resources/levels/modular_smoke.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	bad.connections[0].state = "locked"
	assert(not LevelLayoutValidator.validate(bad).is_empty())
	assert(ResourceSaver.save(source, "user://modular_roundtrip.tres") == OK)
	var roundtrip := (
		ResourceLoader.load(
			"user://modular_roundtrip.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		as LevelLayout
	)
	assert(LevelLayoutValidator.validate(roundtrip).is_empty())
	for i in range(source.instances.size()):
		assert(source.instances[i].position == roundtrip.instances[i].position)
	level = LevelAssembly.new()
	level.layout = roundtrip
	root.add_child(level)
	await level.navigation_ready
	await frames(3)
	assert(level.last_errors.is_empty())
	# Unused caps must actually obstruct a ray; remove one and enclosure must reject it.
	var used := {}
	for c in source.connections:
		used[str(c.from_instance) + "/" + str(c.from_socket)] = true
		used[str(c.to_instance) + "/" + str(c.to_socket)] = true
	var tested := false
	for item in source.instances:
		var node := level.get_node(str(item.id)) as LevelModule
		assert(not node.scene_file_path.is_empty(), "Archetypes must remain scene instances")
		for socket in item.module.sockets:
			var cap := node.get_node("Structure/PortalClosures/" + str(socket.id)) as StaticBody3D
			assert((cap.collision_layer == 0) == used.has(str(item.id) + "/" + str(socket.id)))
			if not tested and cap.collision_layer == 1:
				cap.collision_layer = 0
				await frames(2)
				assert(not LevelEnclosureValidator.validate(level).is_empty())
				cap.collision_layer = 1
				await frames(2)
				tested = true
	assert(tested and LevelEnclosureValidator.validate(level).is_empty())
	# Missing floors and ceilings must fail with the owning instance ID.
	for surface: String in ["Floor0", "Roof0"]:
		var body := level.get_node("room_0/Structure/Collision/" + surface) as StaticBody3D
		var old_layer := body.collision_layer
		body.collision_layer = 0
		await frames(2)
		assert("room_0" in str(LevelEnclosureValidator.validate(level)))
		body.collision_layer = old_layer
		await frames(2)
	# Exercise the same capture/snap/rebuild actions exposed in the editor Inspector.
	level.capture_destination = "user://captured_layout.tres"
	level.capture()
	assert(level.last_errors.is_empty())
	var captured := load("user://captured_layout.tres") as LevelLayout
	assert(LevelLayoutValidator.validate(captured).is_empty())
	assert(captured.instances.size() == source.instances.size())
	# Geometry independent of visual materials.
	var visual := level.get_node("room_0/Visuals/Floor0") as MeshInstance3D
	visual.material_override = StandardMaterial3D.new()
	assert(LevelEnclosureValidator.validate(level).is_empty())
	# Pack/reopen without losing external PackedScene identity or closures.
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(ResourceSaver.save(packed, "user://modular_scene.tscn") == OK)
	var reopened := load("user://modular_scene.tscn").instantiate() as LevelAssembly
	assert(
		(
			reopened.get_node("room_0").scene_file_path
			== "res://scenes/level/modules/Room01Straight.tscn"
		)
	)
	reopened.free()
	for path: String in [
		"res://scenes/entities/Player.tscn",
		"res://scenes/entities/SGCAirman.tscn",
		"res://scenes/entities/JaffaGuard.tscn"
	]:
		var pawn := load(path).instantiate() as CharacterBody3D
		pawn.name = "1"
		level.add_child(pawn)
		pawn.set_physics_process(false)
		pawn.set_process(false)
		pawn.floor_snap_length = 0.4
		for connection in source.connections:
			for reverse: bool in [false, true]:
				var from_id := connection.to_instance if reverse else connection.from_instance
				var to_id := connection.from_instance if reverse else connection.to_instance
				var start := level.marker(from_id, &"entry")
				var goal := level.marker(to_id, &"entry")
				pawn.position = start + Vector3(0, 0.03, 0)
				pawn.velocity = Vector3.ZERO
				await frames(2)
				var points := level.local_path(start, goal)
				assert(
					not points.is_empty() and points[-1].distance_to(goal) < 0.5,
					"Navigation must cross the requested portal"
				)
				var index := 0
				var arrived := false
				for tick in range(700):
					var p := points[index]
					var dir := p - pawn.position
					dir.y = 0
					if dir.length() < 0.15 and index < points.size() - 1:
						index += 1
						continue
					dir = dir.normalized()
					pawn.velocity.x = dir.x * 3
					pawn.velocity.z = dir.z * 3
					pawn.velocity.y = 0 if pawn.is_on_floor() else pawn.velocity.y - 9.8 / 60
					pawn.move_and_slide()
					await physics_frame
					if pawn.position.distance_to(goal) < 0.45:
						arrived = true
						break
				assert(
					arrived,
					(
						"Capsule stuck: "
						+ path
						+ " "
						+ str(from_id)
						+ " -> "
						+ str(to_id)
						+ " at "
						+ str(pawn.position)
					)
				)
		pawn.queue_free()
		await process_frame
	print(
		"PASS modular contracts, rotation, rollback, save/reload, enclosure and all production capsule routes"
	)
	await preload("res://tests/support/finish.gd").success(self)
