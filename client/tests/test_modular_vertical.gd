extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")
const Canvas = preload("res://addons/modular_editor/canvas.gd")


func _init() -> void:
	call_deferred("run")


func fixture(turn: int = 0, elevation: float = 0) -> LevelLayout:
	var model := Model.new()
	model.restore(model.deck_changed("deck0", elevation))
	model.restore(model.deck_changed("upper", elevation + 4))
	var ramp := load("res://resources/level_modules/Room14Ramp4m.tres") as LevelModuleDefinition
	model.restore(model.placed(ramp, Vector2.ZERO, turn))
	var corridor := (
		load("res://resources/level_modules/Room01Straight.tres") as LevelModuleDefinition
	)
	var rotation := Basis(Vector3.UP, turn * PI / 2)
	var lower := rotation * Vector3(0, 0, -8)
	model.restore(model.placed(corridor, Vector2(lower.x, lower.z), turn))
	model.active_deck = &"upper"
	var upper := rotation * Vector3(0, 0, 16)
	model.restore(model.placed(corridor, Vector2(upper.x, upper.z), turn))
	model.layout.entry_instance = &"room_002"
	model.layout.destination_instance = &"room_003"
	assert(model.layout.connections.size() == 2)
	return model.layout


func run() -> void:
	var catalogue_ids := {}
	for name: String in LevelCatalogue.all_modules():
		var module := (
			load("res://resources/level_modules/" + name + ".tres") as LevelModuleDefinition
		)
		assert(module.id != &"" and not catalogue_ids.has(module.id))
		catalogue_ids[module.id] = true
	for turn in range(4):
		var layout := fixture(turn, -12.5 if turn % 2 else 0)
		assert(LevelLayoutValidator.validate(layout).is_empty())
		var copy := Model.copy(layout)
		copy.instances[0].socket_decks["upper"] = "deck0"
		assert("room_001/upper" in str(LevelLayoutValidator.validate(copy)))
		assert(
			layout.instances[0].socket_decks["upper"] == "upper",
			"Undo snapshots must not share bindings"
		)
		copy = Model.copy(layout)
		copy.decks["upper"] += 1
		assert("elevation mismatch" in str(LevelLayoutValidator.validate(copy)))
		var model := Model.new()
		model.restore(layout)
		assert(not model.accepted(model.redecked(&"room_003", &"deck0")))
		assert(model.layout.connections.size() == 2)
		# The same snap calculation joins upper endpoints across different base decks.
		var upper := layout.instances[2]
		var edge_count := layout.connections.size()
		layout.connections.remove_at(edge_count - 1)
		upper.position = Vector2(100, 100)
		assert(LevelAssembler.snap(layout, upper.id, &"north", &"room_001", &"upper").is_empty())
		var before := upper.position
		upper.socket_decks["north"] = "deck0"
		assert(
			not LevelAssembler.snap(layout, upper.id, &"north", &"room_001", &"upper").is_empty()
		)
		assert(upper.position == before and layout.connections.size() == edge_count)
		upper.socket_decks.clear()
		var assembly := LevelAssembly.new()
		assembly.layout = layout
		root.add_child(assembly)
		await assembly.navigation_ready
		assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
		for surface: String in ["Floor1", "Roof1", "Wall-1"]:
			var body := assembly.get_node("room_001/Structure/Collision/" + surface) as StaticBody3D
			var layer := body.collision_layer
			body.collision_layer = 0
			await physics_frame
			await physics_frame
			assert(
				"room_001" in str(LevelEnclosureValidator.validate(assembly)),
				"Missing ramp boundary must fail: " + surface
			)
			body.collision_layer = layer
			await physics_frame
			await physics_frame
		assert(LevelEnclosureValidator.validate(assembly).is_empty())
		var start := assembly.marker(layout.entry_instance, &"entry")
		var goal := assembly.marker(layout.destination_instance, &"entry")
		for scene: String in ["Player", "SGCAirman", "JaffaGuard"]:
			var pawn := (
				load("res://scenes/entities/" + scene + ".tscn").instantiate() as CharacterBody3D
			)
			pawn.name = "1"
			assembly.add_child(pawn)
			pawn.set_process(false)
			pawn.set_physics_process(false)
			pawn.floor_snap_length = .4
			await walk(pawn, assembly, start, goal)
			await walk(pawn, assembly, goal, start)
			pawn.queue_free()
			await process_frame
		assert(ResourceSaver.save(layout, "user://vertical_roundtrip.tres") == OK)
		var reopened := (
			ResourceLoader.load(
				"user://vertical_roundtrip.tres", "", ResourceLoader.CACHE_MODE_IGNORE
			)
			as LevelLayout
		)
		assert(LevelLayoutValidator.validate(reopened).is_empty())
		assert(reopened.instances[0].module.scene.resource_path.ends_with("Room14Ramp4m.tscn"))
		assembly.queue_free()
		await process_frame
	await test_tall_shells()
	await test_transport_contract()
	await test_demo_export()
	var incomplete := LevelLayout.new()
	var item := LevelModuleInstance.new()
	item.id = &"unbound"
	item.module = load("res://resources/level_modules/Room14Ramp4m.tres")
	incomplete.instances.append(item)
	incomplete.entry_instance = item.id
	incomplete.destination_instance = item.id
	assert(LevelLayoutValidator.validate(incomplete, false).is_empty())
	assert("Unbound socket deck: unbound/upper" in LevelLayoutValidator.validate(incomplete))
	# A tall shell reserves the volume through intermediate decks.
	var tall := Model.new()
	tall.restore(
		tall.placed(
			load("res://resources/level_modules/Room15TransportChamber.tres"), Vector2.ZERO, 0
		)
	)
	tall.restore(tall.deck_changed("upper", 4))
	tall.active_deck = &"upper"
	assert(
		not tall.accepted(
			tall.placed(load("res://resources/level_modules/Room01Straight.tres"), Vector2.ZERO, 0)
		)
	)
	print(
		"PASS four ramp orientations, arbitrary deck datum, every production capsule both ways, sloped enclosure negatives, tall equipment clearances, transport pairing and save/reload"
	)
	await preload("res://tests/support/finish.gd").success(self)


func test_tall_shells() -> void:
	for name: String in ["Room15TransportChamber", "Room16HangarShell"]:
		for turn in range(4):
			var model := Model.new()
			model.restore(
				model.placed(
					load("res://resources/level_modules/" + name + ".tres"), Vector2.ZERO, turn
				)
			)
			assert(LevelLayoutValidator.validate(model.layout).is_empty())
			var assembly := LevelAssembly.new()
			assembly.layout = model.layout
			root.add_child(assembly)
			await assembly.navigation_ready
			assert(assembly.last_errors.is_empty())
			var item := model.layout.instances[0]
			for socket in item.module.sockets:
				var goal := item.placement(0) * socket.approach
				var path := assembly.local_path(assembly.marker(item.id, &"entry"), goal)
				assert(not path.is_empty() and path[-1].distance_to(goal) < .5)
			# Structural obstruction in reserved equipment space must fail.
			var slot: String = item.module.equipment_clearances.keys()[0]
			var box: AABB = item.module.equipment_clearances[slot]
			var obstacle := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			collider.shape = BoxShape3D.new()
			obstacle.add_child(collider)
			assembly.get_node(str(item.id) + "/Structure/Collision").add_child(obstacle)
			obstacle.position = box.get_center()
			await physics_frame
			await physics_frame
			assert(
				(
					"Blocked equipment clearance: %s/%s" % [item.id, slot]
					in LevelEnclosureValidator.validate(assembly)
				)
			)
			assembly.queue_free()
			await process_frame


func test_transport_contract() -> void:
	var layout := LevelLayout.new()
	layout.decks["upper"] = 4.0
	for i in range(2):
		var item := LevelModuleInstance.new()
		item.id = StringName("rings_%d" % i)
		item.module = load("res://resources/level_modules/Room15TransportChamber.tres")
		item.position = Vector2(i * 16, 0)
		item.deck = &"deck0" if i == 0 else &"upper"
		var endpoint := LevelTransportEndpoint.new()
		endpoint.id = item.id
		endpoint.target_id = StringName("rings_%d" % (1 - i))
		endpoint.node_path = NodePath("Attachments/Interactions/transport/Rings")
		item.transport_endpoints.append(endpoint)
		layout.instances.append(item)
	assert(LevelLayoutValidator.validate_transports(layout, true).is_empty())
	var assembly := LevelAssembly.new()
	root.add_child(assembly)
	assembly.layout = layout
	LevelAssembler.assemble(layout, assembly)
	var rigs: Array[TransportRings] = []
	for item in layout.instances:
		var rig := load("res://scenes/props/TransportRings.tscn").instantiate() as TransportRings
		rig.name = "Rings"
		assembly.get_node(str(item.id) + "/Attachments/Interactions/transport").add_child(rig)
		# Existing retracted rings reach above 10 m; verify the tall shell fits the actual asset.
		for mesh: MeshInstance3D in rig.get_node("RingsStack").get_children():
			var local := (
				rig.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			)
			assert(local.end.y < 10.4 and local.position.x > -2.5 and local.end.x < 2.5)
		rigs.append(rig)
	assert(LevelTransportBindings.bind_rings(layout, assembly).is_empty())
	assert(rigs[0].paired_rings == rigs[1] and rigs[1].paired_rings == rigs[0])
	assert(
		(
			not rigs[0].spawn_enemies_on_beam
			and rigs[0].scene_file_path == "res://scenes/props/TransportRings.tscn"
		)
	)
	var model := Model.new()
	model.restore(layout)
	var isolated := model.room_layout(layout.instances[0].id)
	assert(LevelLayoutValidator.validate(isolated).is_empty())
	assert(
		(
			isolated.instances[0].transport_endpoints.is_empty()
			and not model.layout.instances[0].transport_endpoints.is_empty()
		)
	)
	var snapshot := Model.copy(layout)
	snapshot.instances[0].transport_endpoints[0].target_id = &"missing"
	assert(not LevelTransportBindings.bind_rings(snapshot, assembly).is_empty())
	assert(
		(
			rigs[0].paired_rings == rigs[1]
			and layout.instances[0].transport_endpoints[0].target_id == &"rings_1"
		)
	)
	assert(ResourceSaver.save(layout, "user://transport_roundtrip.tres") == OK)
	var reloaded := load("user://transport_roundtrip.tres") as LevelLayout
	assert(LevelLayoutValidator.validate_transports(reloaded, true).is_empty())
	assembly.queue_free()
	await process_frame


func walk(pawn: CharacterBody3D, assembly: LevelAssembly, start: Vector3, goal: Vector3) -> void:
	pawn.position = start + Vector3(0, .03, 0)
	pawn.velocity = Vector3.ZERO
	await physics_frame
	var path := assembly.local_path(start, goal)
	assert(not path.is_empty() and path[-1].distance_to(goal) < .5, "Continuous ramp navigation")
	var index := 0
	var grounded := 0
	var movement_ticks := 0
	for tick in range(1800):
		var direction := path[index] - pawn.position
		direction.y = 0
		if direction.length() < .2 and index < path.size() - 1:
			index += 1
			continue
		direction = direction.normalized()
		pawn.velocity.x = direction.x * 3
		pawn.velocity.z = direction.z * 3
		pawn.velocity.y = 0 if pawn.is_on_floor() else pawn.velocity.y - 9.8 / 60
		pawn.move_and_slide()
		movement_ticks += 1
		if pawn.is_on_floor():
			grounded += 1
		assert(pawn.position.y > minf(start.y, goal.y) - 1, "No falling through ramp")
		await physics_frame
		if pawn.position.distance_to(goal) < .45:
			assert(
				grounded > 20 and grounded >= movement_ticks * .9,
				"Pawn must remain grounded through ramp travel"
			)
			return
	assert(false, "Capsule stuck on ramp at " + str(pawn.position) + " toward " + str(goal))


func test_demo_export() -> void:
	var source := load("res://resources/levels/vertical_kit_demo.tres") as LevelLayout
	assert(LevelLayoutValidator.validate(source).is_empty())
	var assembly := LevelAssembly.new()
	assembly.layout = source
	root.add_child(assembly)
	await assembly.navigation_ready
	for item in source.instances:
		var goal := assembly.marker(item.id, &"entry")
		var route := assembly.local_path(assembly.marker(source.entry_instance, &"entry"), goal)
		assert(not route.is_empty() and route[-1].distance_to(goal) < .5)
	# The existing gate scene fits the declared centre/operating volume and remains idle.
	var hangar := assembly.get_node("room_004") as LevelModule
	var gate := load("res://scenes/props/Stargate.tscn").instantiate() as StargateRing
	var anchor := hangar.get_node("Attachments/Interactions/gate") as Node3D
	anchor.add_child(gate)
	var zone: AABB = hangar.definition.equipment_clearances["gate"]
	var torus := gate.get_node("GateRingMesh") as MeshInstance3D
	var bounds := (
		hangar.global_transform.affine_inverse() * torus.global_transform * torus.get_aabb()
	)
	assert(zone.encloses(bounds))
	assert(gate.current_state == StargateRing.GateState.INACTIVE)
	gate.queue_free()
	await process_frame
	var packed := PackedScene.new()
	assert(packed.pack(assembly) == OK)
	assert(ResourceSaver.save(packed, "user://vertical_scene.tscn") == OK)
	assembly.queue_free()
	await process_frame
	var reopened := load("user://vertical_scene.tscn").instantiate() as LevelAssembly
	root.add_child(reopened)
	await reopened.navigation_ready
	assert(reopened.last_errors.is_empty())
	assert((reopened.get_node("room_001") as LevelModule).socket_decks["upper"] == "upper")
	reopened.queue_free()
	await process_frame
