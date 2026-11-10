extends SceneTree
## Production Jaffa and airman controllers navigating the integrated modular fixture.
const DEMO = "res://scenes/level/ModularNpcDemo.tscn"
var tracked: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func open_demo() -> ModularNpcDemo:
	var demo := load(DEMO).instantiate() as ModularNpcDemo
	demo.unlock_after = 0.0
	root.add_child(demo)
	while not demo.is_started:
		assert(demo.level.last_errors.is_empty(), str(demo.level.last_errors))
		await process_frame
	return demo


func track(actor: CharacterBody3D) -> void:
	tracked[actor] = {"last": actor.global_position, "frames": 0, "grounded": 0, "top": -INF, "moved": 0.0}


## One physics tick with movement integrity checks for every tracked actor.
func tick() -> void:
	await physics_frame
	for actor: CharacterBody3D in tracked:
		var data: Dictionary = tracked[actor]
		var step := actor.global_position.distance_to(data.last)
		assert(step < 0.35, "%s moved %.2f m in one tick: teleport" % [actor.name, step])
		assert(actor.global_position.y > -0.5, "%s fell through the level" % actor.name)
		data.moved += step
		data.last = actor.global_position
		data.frames += 1
		data.grounded += int(actor.is_on_floor())
		data.top = maxf(data.top, actor.global_position.y)


func until(condition: Callable, seconds: float, what: String) -> void:
	for i in range(int(seconds * 60)):
		if condition.call():
			return
		await tick()
	assert(false, "Timed out: " + what)


func grounded(actor: CharacterBody3D) -> float:
	return float(tracked[actor].grounded) / maxf(1.0, tracked[actor].frames)


func run() -> void:
	var demo := await open_demo()
	var level := demo.level
	var jaffa := demo.jaffa
	var runner := demo.runner
	var sentry := demo.sentry
	var door := demo.security_door
	# Real production scenes with their own controllers running; nothing is driven by the test.
	assert(jaffa.scene_file_path == ModularNpcDemo.JAFFA and jaffa.is_physics_processing())
	assert(runner.scene_file_path == ModularNpcDemo.AIRMAN and runner.is_physics_processing())
	assert(jaffa.get_multiplayer_authority() == 1 and runner.get_multiplayer_authority() == 1)
	assert(level.find_children("*", "SGCMap", true, false).is_empty())
	var hub_door := door_between(level, &"hub", &"width_adapter")
	var wide_door := door_between(level, &"width_adapter", &"wide_straight")
	var command_door := door_between(level, &"upper_junction", &"command")
	var cargo_door := door_between(level, &"stores_approach", &"cargo")
	for closed: ModularDoor in [hub_door, wide_door, command_door, cargo_door]:
		assert(not closed.is_open and closed.collision_layer == 1)
	assert(door.locked and not door.is_open)
	for actor: CharacterBody3D in [jaffa, runner, sentry]:
		track(actor)
	var reached: Array[int] = []
	jaffa.patrol_waypoint_reached.connect(func(i: int) -> void: reached.append(i))
	var sentry_start := sentry.global_position

	# Friendly commanded to the saved destination marker on the upper deck, through a door.
	var command := level.marker(level.layout.destination_instance, level.layout.destination_marker)
	await until(func() -> bool: return runner.global_position.distance_to(command) < 1.3, 60, "runner reaches command")
	assert(command.y > 3.9 and tracked[runner].top > 3.9, "Runner climbed the ramp physically")
	assert(command_door.is_open and command_door.collision_layer == 0, "Runner opened the command door")
	assert(grounded(runner) > 0.95, "Runner grounded: %.2f" % grounded(runner))
	print("PASS airman commanded to upper-deck marker via ramp and standard door, grounded %.2f" % grounded(runner))

	# Jaffa patrols five rooms: wide junction, wide corner, both width transitions, X junction.
	await until(func() -> bool: return jaffa.patrol_laps >= 1 and jaffa.patrol_index == 1, 120, "jaffa completes a lap and loops")
	# Waypoint 0 is the spawn marker, already passed before this listener connected.
	assert(reached.slice(0, 5) == [1, 2, 3, 4, 0], "Ordered waypoints: " + str(reached))
	assert(hub_door.is_open and wide_door.is_open, "Jaffa opened both adapter doors")
	assert(grounded(jaffa) > 0.95, "Jaffa grounded: %.2f" % grounded(jaffa))
	assert(tracked[jaffa].moved > 30.0, "Jaffa walked: %.1f m" % tracked[jaffa].moved)
	print("PASS jaffa patrol lap through %d waypoints, %.0f m, grounded %.2f" % [reached.size(), tracked[jaffa].moved, grounded(jaffa)])

	# Locked security door: recognised from the route, held in place, never opened or unlocked.
	assert(sentry.navigator.status == "blocked_door")
	assert(sentry.navigator.level_route.blocked_door == door)
	assert(sentry.global_position.distance_to(sentry_start) < 0.3, "Sentry holds instead of pushing the door")
	assert(door.locked and not door.is_open and door.collision_layer == 1)
	assert(not cargo_door.is_open, "No speculative opening on a blocked route")
	assert(not door.open_for(sentry), "AI interaction cannot open a locked door")
	# Door permissions: reach, authority and lock all apply to AI requests.
	assert(not cargo_door.open_for(runner), "Out of reach")
	var foreign := CharacterBody3D.new()
	foreign.set_multiplayer_authority(2)
	level.add_child(foreign)
	foreign.global_position = cargo_door.global_position + cargo_door.global_basis.z
	assert(not cargo_door.open_for(foreign) and not cargo_door.is_open, "Only server-owned actors")
	foreign.free()
	assert(door.set_locked(false))
	var barracks := level.marker(&"barracks", &"entry")
	await until(func() -> bool: return sentry.global_position.distance_to(barracks) < 1.3, 60, "sentry resumes after unlock")
	assert(cargo_door.is_open and door.is_open and grounded(sentry) > 0.95)
	print("PASS locked security door held and reported, then traversed after server unlock")

	# Objective off the navigation mesh: reported, actor holds.
	var hold := runner.global_position
	runner.order_move_to(Vector3(200, 0, 200))
	await until(func() -> bool: return runner.navigator.status == "unreachable", 5, "unreachable reported")
	for i in range(180):
		await tick()
	assert(runner.navigator.status == "unreachable" and runner.global_position.distance_to(hold) < 0.3)

	# Geometry added after the bake blocks a corridor: bounded replans, then a stuck report.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(8, 3, 0.4)
	shape.position.y = 1.5
	wall.add_child(shape)
	level.add_child(wall)
	wall.global_position = level.marker(&"entry", &"entry")
	var scout := demo.spawn(ModularNpcDemo.JAFFA, demo.hostiles, &"elbow", &"entry") as JaffaAI
	track(scout)
	var beyond: Array[Vector3] = [level.marker(&"hub", &"entry")]
	scout.start_patrol(beyond, false)
	await until(func() -> bool: return scout.navigator.status == "stuck", 30, "stuck reported")
	assert(scout.global_position.z < wall.global_position.z, "Scout stays on its side of the obstruction")
	wall.free()
	await until(func() -> bool: return scout.patrol_laps == 1, 30, "scout recovers when the route clears")
	print("PASS unreachable objective and post-bake obstruction reported without teleport; recovery after clearing")

	# Scene reload: a fresh instance rebuilds navigation and the patrol runs again.
	tracked.clear()
	demo.free()
	await process_frame
	demo = await open_demo()
	assert(demo.jaffa != jaffa and demo.security_door.locked)
	track(demo.jaffa)
	var again := demo.jaffa
	await until(func() -> bool: return again.patrol_index >= 2, 60, "patrol after reload")
	tracked.clear()
	demo.free()
	await process_frame
	print("PASS modular NPC navigation, patrol, doors, failure handling and scene reload")
	await preload("res://tests/support/finish.gd").success(self)


func door_between(level: LevelAssembly, a: StringName, b: StringName) -> ModularDoor:
	for i in range(level.layout.connections.size()):
		var edge := level.layout.connections[i]
		if [edge.from_instance, edge.to_instance] in [[a, b], [b, a]]:
			return level.get_node("Door_%03d" % i) as ModularDoor
	return null
