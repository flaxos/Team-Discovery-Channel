extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")
const SOURCE = "res://resources/levels/modular_integration_demo.tres"


func _init() -> void:
	call_deferred("run")


func build(layout: LevelLayout) -> LevelAssembly:
	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
	return assembly


func verify_routes(assembly: LevelAssembly) -> void:
	var start := assembly.marker(assembly.layout.entry_instance, assembly.layout.entry_marker)
	for item in assembly.layout.instances:
		var module := assembly.get_node(str(item.id)) as LevelModule
		assert(module.scene_file_path == item.module.scene.resource_path, "Keep external PackedScene identity")
		var goal := assembly.marker(item.id, &"entry")
		for reverse: bool in [false, true]:
			var path := assembly.local_path(goal if reverse else start, start if reverse else goal)
			assert(not path.is_empty() and path[-1].distance_to(start if reverse else goal) < .5, "Reachable room: " + str(item.id))
	assert(LevelEnclosureValidator.validate(assembly).is_empty())
	var lower := assembly.get_node("lower_rings/Attachments/Interactions/transport/Rings") as TransportRings
	var upper := assembly.get_node("upper_rings/Attachments/Interactions/transport/Rings") as TransportRings
	assert(lower.paired_rings == upper and upper.paired_rings == lower)
	for ring: TransportRings in [lower, upper]:
		assert(ring.scene_file_path == "res://scenes/props/TransportRings.tscn")
		assert(not ring.spawn_enemies_on_beam and ring.current_state == TransportRings.RingState.INACTIVE)
	assert(assembly.find_children("*", "CharacterBody3D", true, false).is_empty(), "Fixture must not spawn actors")


func run() -> void:
	var layout := load(SOURCE) as LevelLayout
	assert(layout != null and layout.default_theme == &"neutral")
	assert(LevelLayoutValidator.validate(layout).is_empty())
	var modules := {}
	var roles := {}
	var types := {}
	for item in layout.instances:
		modules[item.module.id] = true
		if item.room_preset != null:
			roles[item.room_preset.id] = true
	for module in LevelCatalogue.module_definitions():
		assert(modules.has(module.id), "Missing structural archetype: " + str(module.id))
	for id: StringName in [&"cargo", &"jaffa_barracks", &"generator", &"security_control", &"ring_transport", &"command", &"cargo_hangar"]:
		assert(roles.has(id), "Missing functional demonstration: " + str(id))
	for edge in layout.connections:
		types[edge.state] = true
	for type: String in ["open", "door", "security_door"]:
		assert(types.has(type))
	assert(layout.decks.upper - layout.decks.deck0 == 4.0)
	assert(layout.instance(&"ramp").socket_deck(&"upper") == &"upper")
	# Recover all the authored adjacency with the same automatic-join operation as the editor.
	var recovered := Model.copy(layout)
	recovered.connections.clear()
	assert(LevelAssembler.connect_touching(recovered).is_empty())
	assert(recovered.connections.size() == layout.connections.size())
	var edited := LevelAuthoring.transact(layout, {"operations": [{"op":"move", "id":"cargo", "at":[0,0]}]})
	assert(not edited.ok and layout.instance(&"cargo").position != Vector2.ZERO)
	var cloned := LevelAuthoring.transact(null, {"create":{"decks":{"deck0":0,"upper":4}}, "operations":[{"op":"composite", "composite_id":"integration_lab", "prefix":"qa", "at":[0,0], "turn":1}]})
	assert(cloned.ok, str(cloned.get("errors")))
	assert(cloned.layout.instances.size() == layout.instances.size())
	assert(cloned.layout.instance(&"qa_lower_rings").transport_endpoints[0].target_id == &"qa_rings_upper")
	var assembly := await build(layout)
	verify_routes(assembly)
	var doors: Array[ModularDoor] = []
	var security: ModularDoor
	for i in range(layout.connections.size()):
		var door := assembly.get_node_or_null("Door_%03d" % i) as ModularDoor
		if layout.connections[i].state == "open":
			assert(door == null, "Open passages must have no blocker")
		else:
			assert(door != null and not door.is_open and door.collision_layer == 1)
			doors.append(door)
			if door.is_security:
				security = door
	assert(security != null and security.security_id == &"crew_quarters" and not security.locked)
	var player := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "1"
	assembly.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.position = security.position - security.basis.z * 1.2 + Vector3(0,.03,0)
	player.camera.global_position = player.global_position + Vector3(0,1.6,0)
	player.camera.look_at(security.global_position + Vector3(0,1.2,0))
	await physics_frame
	player._try_interact()
	assert(security.is_open and security.collision_layer == 0, "Existing player interaction must operate security door")
	player.queue_free()
	await process_frame
	for door in doors:
		door.sync_open(true)
	await physics_frame
	for scene: String in ["Player", "SGCAirman", "JaffaGuard"]:
		var pawn := load("res://scenes/entities/" + scene + ".tscn").instantiate() as CharacterBody3D
		pawn.name = "1"
		assembly.add_child(pawn)
		pawn.set_process(false)
		pawn.set_physics_process(false)
		pawn.floor_snap_length = .4
		# Physical routes combine real presets, mixed portals, width adapters and both decks.
		for route: Array in [[&"hub", &"command"], [&"hub", &"lower_rings"], [&"cargo", &"barracks"]]:
			var a := assembly.marker(route[0], &"entry")
			var b := assembly.marker(route[1], &"entry")
			await walk(pawn, assembly, a, b)
			await walk(pawn, assembly, b, a)
		pawn.queue_free()
		await process_frame
		print("PASS integrated physical traversal: ", scene)
	assert(ResourceSaver.save(layout, "user://integration_roundtrip.tres") == OK)
	var saved := ResourceLoader.load("user://integration_roundtrip.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as LevelLayout
	assert(LevelLayoutValidator.validate(saved).is_empty() and saved.connections.size() == layout.connections.size())
	assert(saved.instance(&"lower_rings").transport_endpoints[0].target_id == &"rings_upper")
	var errors := LevelBuildPipeline.export(assembly, "user://integration_test.tscn", "user://integration_test_nav.tres")
	assert(errors.is_empty(), str(errors))
	assembly.queue_free()
	await process_frame
	var reopened := load("user://integration_test.tscn").instantiate() as LevelAssembly
	root.add_child(reopened)
	while not reopened.ready_for_navigation and reopened.last_errors.is_empty():
		await process_frame
	assert(reopened.last_errors.is_empty(), str(reopened.last_errors))
	verify_routes(reopened)
	reopened.queue_free()
	await process_frame
	print("PASS integrated catalogue, automatic joining, presets, security interaction, deck traversal, neutral exploration, native persistence and scene rebuild")
	await preload("res://tests/support/finish.gd").success(self)


func walk(pawn: CharacterBody3D, assembly: LevelAssembly, start: Vector3, goal: Vector3) -> void:
	pawn.position = start + Vector3(0,.03,0)
	pawn.velocity = Vector3.ZERO
	await physics_frame
	var path := assembly.local_path(start, goal)
	assert(not path.is_empty() and path[-1].distance_to(goal) < .5)
	var index := 0
	var grounded := 0
	var steps := 0
	for tick in range(3600):
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
		steps += 1
		if pawn.is_on_floor():
			grounded += 1
		assert(pawn.position.y > minf(start.y, goal.y) - 1, "No falls through module joins")
		await physics_frame
		if pawn.position.distance_to(goal) < .45:
			assert(grounded > steps * .9, "Stay grounded through composed routes")
			return
	assert(false, "Integrated capsule route stuck: " + str(pawn.position) + " -> " + str(goal))
