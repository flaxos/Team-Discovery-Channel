extends SceneTree
## Milestone TA-3 verification:
## 1. Locked-door rerouting across looped modular layouts (and blocked_door when all routes locked)
## 2. Head-on NPC corridor yielding / right-hand avoidance without stalling
## 3. Server-authoritative door auto-closing after an NPC passes 2.5m beyond the doorway
const Model = preload("res://addons/modular_editor/model.gd")
const JAFFA_SCENE = "res://scenes/entities/JaffaGuard.tscn"


func _init() -> void:
	call_deferred("run")


func tick() -> void:
	await physics_frame


func until(condition: Callable, seconds: float, description: String) -> void:
	for _i in range(int(seconds * 60.0)):
		if condition.call():
			return
		await tick()
	assert(false, "Timed out: " + description)


## Builds a 4-room corridor loop:
##   room_001 (0,0)  ---  room_002 (8,0)
##      |                    |
##   room_004 (0,8)  ---  room_003 (8,8)
## In Godot (+X east, +Z south):
## Room02Corner has sockets `north` (0,0,-4) and `east` (4,0,0).
## - turn 0: north=(-Z), east=(+X)  -> bottom-left (0, 8): connects north to (0,0) and east to (8,8)
## - turn 1:rot(+90 deg Y): north=(-X), east=(-Z) -> bottom-right (8, 8): connects north to (0,8) and east to (8,0)
## - turn 2:rot(180 deg Y): north=(+Z), east=(-X) -> top-right (8, 0): connects north to (8,8) and east to (0,0)
## - turn 3:rot(-90 deg Y): north=(+X), east=(+Z) -> top-left (0, 0): connects north to (8,0) and east to (0,8)
func build_loop_layout() -> LevelLayout:
	var model := Model.new()
	var corner := load("res://resources/level_modules/Room02Corner.tres") as LevelModuleDefinition
	model.restore(model.placed(corner, Vector2(0, 0), 3))
	model.restore(model.placed(corner, Vector2(8, 0), 2))
	model.restore(model.placed(corner, Vector2(8, 8), 1))
	model.restore(model.placed(corner, Vector2(0, 8), 0))
	assert(model.layout.connections.size() == 4, "Expected 4 loop connections, got %d" % model.layout.connections.size())
	for i in range(model.layout.connections.size()):
		model.layout.connections[i].state = "security_door"
		model.layout.connections[i].security_id = StringName("sec_%d" % i)
		model.layout.connections[i].initially_locked = false
	return model.layout


func build_straight_corridor_layout() -> LevelLayout:
	var model := Model.new()
	var straight := load("res://resources/level_modules/Room01Straight.tres") as LevelModuleDefinition
	model.restore(model.placed(straight, Vector2(0, 0), 0))
	model.restore(model.placed(straight, Vector2(0, 8), 0))
	model.restore(model.placed(straight, Vector2(0, 16), 0))
	model.layout.connections[0].state = "open"
	model.layout.connections[1].state = "door"
	return model.layout


func spawn_assembly(source: LevelLayout) -> LevelAssembly:
	var level := LevelAssembly.new()
	level.layout = source
	root.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	assert(level.last_errors.is_empty(), "Level build errors: " + str(level.last_errors))
	return level


func door_between(level: LevelAssembly, a: StringName, b: StringName) -> ModularDoor:
	for i in range(level.layout.connections.size()):
		var edge := level.layout.connections[i]
		if [edge.from_instance, edge.to_instance] in [[a, b], [b, a]]:
			return level.get_node_or_null("Door_%03d" % i) as ModularDoor
	return null


func spawn_jaffa(parent: Node3D, pos: Vector3, actor_name: String) -> JaffaAI:
	var jaffa := load(JAFFA_SCENE).instantiate() as JaffaAI
	jaffa.name = actor_name
	jaffa.position = parent.to_local(pos) + Vector3(0, 0.05, 0)
	parent.add_child(jaffa, true)
	return jaffa


func test_locked_door_rerouting() -> void:
	var world := Node3D.new()
	world.name = "RerouteWorld"
	world.add_to_group(MissionWorld.GROUP)
	root.add_child(world)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	world.add_child(enemies)

	var level := LevelAssembly.new()
	level.layout = build_loop_layout()
	world.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	assert(level.last_errors.is_empty(), str(level.last_errors))

	var direct_door := door_between(level, &"room_001", &"room_004")
	var alt_door := door_between(level, &"room_001", &"room_002")
	assert(direct_door != null and alt_door != null)

	# Lock the direct connection between room_001 and room_004.
	assert(direct_door.set_locked(true))
	assert(direct_door.locked and not direct_door.is_open)

	var jaffa := spawn_jaffa(enemies, level.marker(&"room_001", &"entry"), "RerouteSentry")
	var goal := level.marker(&"room_004", &"entry")
	var waypoints: Array[Vector3] = [goal]
	jaffa.start_patrol(waypoints, false)

	await tick()
	await tick()
	assert(
		jaffa.navigator.status == "moving",
		"Expected status 'moving' via unlocked loop branch, got '%s'" % jaffa.navigator.status
	)
	assert(jaffa.navigator.level_route.blocked_door == null)

	var alt_opened_during_walk := false
	for _i in range(int(35.0 * 60.0)):
		if alt_door.is_open:
			alt_opened_during_walk = true
		if jaffa.global_position.distance_to(goal) < 1.1:
			break
		await tick()
	assert(
		jaffa.global_position.distance_to(goal) < 1.1,
		"Jaffa reroutes around locked door via room_002 -> room_003 -> room_004"
	)
	assert(not direct_door.is_open and direct_door.locked, "Locked direct door was never opened")
	assert(alt_opened_during_walk, "Alternate route door was opened during traversal")

	# Now lock ALL routes out of room_004 (both room_001<->room_004 and room_003<->room_004)
	var back_door := door_between(level, &"room_003", &"room_004")
	assert(back_door.set_locked(true))
	var return_goal := level.marker(&"room_001", &"entry")
	var nav := LevelNavigator.new(jaffa, level)
	nav.next_position(return_goal, 1.0 / 60.0)
	assert(
		nav.status == "blocked_door" and nav.blocked_door != null,
		"Expected blocked_door when all loop branches are locked, got '%s'" % nav.status
	)

	# The same route resumes after unlocking, then replans when that door locks in flight.
	assert(direct_door.set_locked(false))
	nav.next_position(return_goal, 1.1)
	assert(nav.status == "moving" and nav.blocked_door == null)
	assert(direct_door.set_locked(true))
	assert(back_door.set_locked(false))
	nav.next_position(return_goal)
	assert(nav.status == "moving" and nav.blocked_door == null)
	for entry in nav.doors:
		assert(entry.door != direct_door, "An in-flight lock switches to the alternate route")
	world.free()
	await process_frame

	# Also verify rerouting on the canonical Goa'uld Infiltration looped layout.
	var inf_layout := load("res://resources/levels/goauld_infiltration_01.tres") as LevelLayout
	var inf_copy := Model.copy(inf_layout)
	for edge in inf_copy.connections:
		if [edge.from_instance, edge.to_instance] in [[&"approach2", &"checkpoint"], [&"checkpoint", &"approach2"]]:
			edge.state = "security_door"
			edge.security_id = &"checkpoint_lock"
			edge.initially_locked = false
	var inf_level := await spawn_assembly(inf_copy)
	var cp_door := door_between(inf_level, &"approach2", &"checkpoint")
	assert(cp_door != null and cp_door.set_locked(true))
	var probe := CharacterBody3D.new()
	inf_level.add_child(probe)
	probe.global_position = inf_level.marker(&"approach2", &"entry")
	var inf_nav := LevelNavigator.new(probe, inf_level)
	var step_pos := inf_nav.next_position(inf_level.marker(&"checkpoint", &"entry"), 1.0 / 60.0)
	assert(
		inf_nav.status == "moving" and inf_nav.blocked_door == null and step_pos != probe.global_position,
		"Expected goauld_infiltration_01 reroute status 'moving', got '%s'" % inf_nav.status
	)
	inf_level.free()
	await process_frame
	print("PASS TA-3 locked-door rerouting on looped layouts and blocked_door when all routes locked")


func test_corridor_npc_avoidance_and_door_auto_close() -> void:
	var world := Node3D.new()
	world.name = "CorridorWorld"
	world.add_to_group(MissionWorld.GROUP)
	root.add_child(world)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	world.add_child(enemies)

	var level := LevelAssembly.new()
	level.layout = build_straight_corridor_layout()
	world.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	assert(level.last_errors.is_empty(), str(level.last_errors))

	# Enable Jaffa-to-Jaffa body collision mask so head-on collision would block without avoidance.
	var start_a := level.marker(&"room_001", &"entry")
	var start_b := level.marker(&"room_002", &"entry")
	var jaffa_a := spawn_jaffa(enemies, start_a, "SentryNorth")
	var jaffa_b := spawn_jaffa(enemies, start_b, "SentrySouth")
	jaffa_a.collision_mask |= 4
	jaffa_b.collision_mask |= 4

	var route_a: Array[Vector3] = [start_b]
	var route_b: Array[Vector3] = [start_a]
	jaffa_a.start_patrol(route_a, false)
	jaffa_b.start_patrol(route_b, false)

	var max_lat_a := 0.0
	var max_lat_b := 0.0
	for _i in range(int(20.0 * 60.0)):
		await tick()
		max_lat_a = maxf(max_lat_a, absf(jaffa_a.global_position.x))
		max_lat_b = maxf(max_lat_b, absf(jaffa_b.global_position.x))
		if jaffa_a.global_position.distance_to(start_b) < 1.0 and jaffa_b.global_position.distance_to(start_a) < 1.0:
			break

	assert(
		jaffa_a.global_position.distance_to(start_b) < 1.0 and jaffa_b.global_position.distance_to(start_a) < 1.0,
		"Both oncoming Jaffa sentries must pass each other and reach opposite waypoints"
	)
	assert(
		max_lat_a > 0.25 and max_lat_b > 0.25,
		"Oncoming Jaffa sentries must yield laterally to their right (lat_a=%.2f, lat_b=%.2f)" % [max_lat_a, max_lat_b]
	)
	assert(jaffa_a.navigator.status != "stuck" and jaffa_b.navigator.status != "stuck")
	print("PASS TA-3 head-on corridor NPC yielding/avoidance (max lateral offset %.2fm / %.2fm)" % [max_lat_a, max_lat_b])

	# Now test door auto-closing after an NPC opens a ModularDoor and walks > 2.5m past it.
	jaffa_b.free()
	await process_frame

	var door := door_between(level, &"room_002", &"room_003")
	assert(door != null and not door.is_open)
	door.auto_close_delay = 1.0

	var room3_goal := level.marker(&"room_003", &"destination") + Vector3(0, 0, 2.0)
	var through_door_route: Array[Vector3] = [room3_goal]
	jaffa_a.start_patrol(through_door_route, false)

	await until(func() -> bool: return door.is_open, 10.0, "Jaffa opens closed door via open_for")
	assert(door.is_open and door.collision_layer == 0, "Door opened for Jaffa")

	await until(
		func() -> bool: return jaffa_a.global_position.distance_to(door.global_position) > 2.6 and not door.is_open,
		15.0,
		"Door auto-closes after Jaffa moves > 2.5m past doorway and auto_close_delay elapses"
	)
	assert(not door.is_open and door.collision_layer == 1, "Door returned to closed collision state")
	print("PASS TA-3 door auto-close after NPC passes beyond 2.5m")

	world.free()
	await process_frame


func test_door_closing_policy() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var door := ModularDoor.new()
	door.auto_close_delay = 0.1
	world.add_child(door)
	var opener := Node3D.new()
	world.add_child(opener)
	opener.position.z = 1.0
	assert(door.open_for(opener))
	opener.position.z = 4.0
	# A player still occupying the doorway must prevent closure after the AI has left.
	var occupant := CharacterBody3D.new()
	occupant.collision_layer = 2
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	occupant.add_child(shape)
	world.add_child(occupant)
	for _i in range(30):
		await tick()
	assert(door.is_open, "Door cannot close on a player occupying the doorway")
	occupant.position.x = 4.0
	await until(func() -> bool: return not door.is_open, 2.0, "door closes once the player clears it")
	# The explicit zero setting disables automatic closure.
	door.auto_close_delay = 0.0
	opener.position.z = 1.0
	assert(door.open_for(opener))
	opener.position.z = 4.0
	for _i in range(30):
		await tick()
	assert(door.is_open, "Zero delay leaves an AI-opened door open")
	door.interact(occupant) # Out of reach: no change.
	assert(door.is_open)
	# AI passing through a door that a player opened must not adopt it for auto-closing.
	door.sync_open(false)
	door.auto_close_delay = 0.1
	opener.position.z = 1.0
	door.interact(opener)
	assert(door.is_open and door.open_for(opener))
	opener.position.z = 4.0
	for _i in range(30):
		await tick()
	assert(door.is_open, "A manually opened door stays open after an AI passes")
	world.free()
	await process_frame
	print("PASS TA-3 occupied doorway, disabled auto-close and manually opened door policy")


func run() -> void:
	await test_locked_door_rerouting()
	await test_corridor_npc_avoidance_and_door_auto_close()
	await test_door_closing_policy()
	await preload("res://tests/support/finish.gd").success(self)
