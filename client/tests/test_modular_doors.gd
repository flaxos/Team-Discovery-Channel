extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	call_deferred("run")


func verify_mixed_doorways() -> void:
	# A loop with mixed north/east/west joins reproduced the user's default-map
	# failure. Keep this fixture independent of their mutable editor_demo resource.
	var arrangement := [
		["Room01Straight", Vector2(56, -16), 3],
		["Room01Straight", Vector2(64, -16), 3],
		["Room01Straight", Vector2(48, -16), 3],
		["Room02Corner", Vector2(40, -16), 3],
		["Room02Corner", Vector2(72, -16), 2],
		["Room02Corner", Vector2(72, -8), 1],
		["Room02Corner", Vector2(40, -8), 0],
		["Room03TJunction", Vector2(56, 0), 0],
		["Room02Corner", Vector2(48, -8), 1],
		["Room02Corner", Vector2(48, 0), 0],
		["Room02Corner", Vector2(56, -8), 3],
		["Room02Corner", Vector2(64, 0), 1],
		["Room03TJunction", Vector2(64, -8), 2],
	]
	var model := Model.new()
	for pose: Array in arrangement:
		var module := (
			load("res://resources/level_modules/" + pose[0] + ".tres") as LevelModuleDefinition
		)
		var candidate := model.placed(module, pose[1], pose[2])
		assert(model.accepted(candidate))
		model.restore(candidate)
	assert(model.layout.connections.size() == 13)
	assert(LevelLayoutValidator.validate(model.layout).is_empty())
	# The explicit recovery action on an older connection-free layout has the
	# same result as automatic placement, without moving or saving any room.
	var recovered := Model.copy(model.layout)
	recovered.connections.clear()
	assert(LevelAssembler.connect_touching(recovered).is_empty())
	assert(recovered.connections.size() == 13)
	assert(LevelLayoutValidator.validate(recovered).is_empty())
	var assembly := LevelAssembly.new()
	assembly.layout = recovered
	root.add_child(assembly)
	await assembly.navigation_ready
	assert(assembly.last_errors.is_empty())
	for edge in recovered.connections:
		var start := assembly.marker(edge.from_instance, &"entry")
		var goal := assembly.marker(edge.to_instance, &"entry")
		for reverse: bool in [false, true]:
			var path := assembly.local_path(goal if reverse else start, start if reverse else goal)
			assert(not path.is_empty())
			assert(path[-1].distance_to(start if reverse else goal) < 0.5)
	assembly.queue_free()
	await process_frame


func run() -> void:
	await verify_mixed_doorways()
	var module := load("res://resources/level_modules/Room01Straight.tres") as LevelModuleDefinition
	var model := Model.new()
	model.restore(model.placed(module, Vector2.ZERO, 0))
	model.restore(model.placed(module, Vector2(0, 8), 0))
	assert(model.layout.connections.size() == 1 and model.layout.connections[0].state == "open")
	assert(
		(
			LevelAssembler.connect_touching(model.layout).is_empty()
			and model.layout.connections.size() == 1
		),
		"Do not duplicate a shared door"
	)
	# Corridor joins default open; explicitly author a door for interaction coverage.
	model.layout.connections[0].state = "door"
	var before := Model.copy(model.layout)
	assert(
		not model.accepted(model.moved(model.layout.instances[1].id, Vector2(0, 16), 0)),
		"Existing links must not be discarded by moving"
	)
	assert(
		(
			model.layout.connections.size() == 1
			and model.layout.instances[1].position == before.instances[1].position
		)
	)
	# Placing the complete existing kit layout should create all eight matching door links (including the extra loop).
	var all_rooms := Model.new()
	var fixture := load("res://resources/levels/modular_smoke.tres") as LevelLayout
	for item in fixture.instances:
		all_rooms.restore(all_rooms.placed(item.module, item.position, item.quarter_turn))
	assert(all_rooms.layout.connections.size() == 8)
	for edge in all_rooms.layout.connections:
		assert(
			(
				edge.state
				== LevelAssembler.connection_default(
					all_rooms.layout.instance(edge.from_instance).module,
					all_rooms.layout.instance(edge.to_instance).module
				)
			)
		)
	assert(LevelLayoutValidator.validate(all_rooms.layout).is_empty())
	# Selecting/releasing a deliberately disconnected room must not reconnect it.
	var disconnected := Model.new()
	disconnected.restore(Model.copy(model.layout))
	disconnected.layout.connections.clear()
	var same := disconnected.layout.instances[0]
	assert(disconnected.moved(same.id, same.position, same.quarter_turn).connections.is_empty())
	var assembly := LevelAssembly.new()
	assembly.layout = model.layout
	root.add_child(assembly)
	await assembly.navigation_ready
	var door := assembly.get_node("Door_000") as ModularDoor
	assert(not door.is_open and door.collision_layer == 1)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.2, 3), Vector3(0, 1.2, 5), 1)
	assert(assembly.get_world_3d().direct_space_state.intersect_ray(query).collider == door)
	var path := assembly.local_path(Vector3.ZERO, Vector3(0, 0, 8))
	assert(
		not path.is_empty() and path[-1].distance_to(Vector3(0, 0, 8)) < 0.5,
		"Closed operable doors cannot erase static navigation"
	)
	var pawn := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	pawn.name = "1"
	assembly.add_child(pawn)
	pawn.set_physics_process(false)
	pawn.set_process(false)
	pawn.position = Vector3(0, 0.03, 2.8)
	pawn.camera.global_position = pawn.position + Vector3(0, 1.6, 0)
	pawn.camera.look_at(door.global_position + Vector3(0, 1.2, 0))
	pawn._try_interact()
	assert(
		door.is_open and door.collision_layer == 0, "Existing E interaction opens the shared door"
	)
	await physics_frame
	assert(assembly.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	for i in range(130):
		pawn.velocity = Vector3(0, -0.5, 3)
		pawn.move_and_slide()
		await physics_frame
	assert(pawn.position.z > 8, "Production capsule must traverse the open doorway")
	pawn.position = door.global_position + Vector3(0, 0.03, 0)
	await physics_frame
	door.interact(pawn)
	assert(door.is_open, "Do not close through an occupied doorway")
	pawn.position = door.global_position + Vector3(0, 0, 1)
	await physics_frame
	await physics_frame
	door.interact(pawn)
	assert(not door.is_open, "Interaction closes again")
	door.interact(null)
	assert(not door.is_open, "Missing actor cannot toggle")
	pawn.position = Vector3(30, 0, 30)
	door.interact(pawn)
	assert(not door.is_open, "Distant actor cannot toggle")
	print(
		"PASS automatic touching connection, one operable door, preserved links, closed/open collision, E interaction and navigation"
	)
	await preload("res://tests/support/finish.gd").success(self)
