extends "res://tests/test_modular_navigation_ta3.gd"
## Reuse TA-3's existing native-model loop fixture. Positive combat starts use real sight.
var world: Node3D
var level: LevelAssembly
var enemies: Node3D
var players: Node3D
var target: PlayerController3D
var lead: JaffaAI
var trailing: JaffaAI


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, point: Vector3) -> void:
	actor.global_position = point + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func setup_encounter(open_passages: bool = false) -> void:
	world = Node3D.new()
	world.name = "FlankWorld"
	world.add_to_group(MissionWorld.GROUP)
	root.add_child(world)
	enemies = Node3D.new()
	enemies.name = "Enemies"
	world.add_child(enemies)
	players = Node3D.new()
	players.name = "Players"
	world.add_child(players)
	level = LevelAssembly.new()
	level.layout = build_loop_layout()
	if open_passages:
		for edge in level.layout.connections:
			edge.state = "open"
	world.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	assert(level.last_errors.is_empty(), str(level.last_errors))
	target = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	target.name = "1"
	players.add_child(target)
	target.set_physics_process(false)
	target.health_component.frozen = true
	place(target, level.marker(&"room_004", &"entry"))
	lead = spawn_jaffa(enemies, level.marker(&"room_001", &"entry") + Vector3(0.65, 0, 0), "Lead")
	trailing = spawn_jaffa(enemies, level.marker(&"room_001", &"entry") - Vector3(0.65, 0, 0), "Trailing")
	for guard: JaffaAI in [lead, trailing]:
		guard.set_physics_process(false)
		guard.fire_timer = 100000.0
		guard.notice_time_near = 0.05
		guard.notice_time_far = 0.05
		var offset := target.global_position - guard.global_position
		guard.rotation.y = atan2(-offset.x, -offset.z)
		guard.start_patrol([guard.global_position])
	trailing.formation_rank = 1
	var direct := door_between(level, &"room_001", &"room_004")
	if direct != null:
		var probe := Node3D.new()
		world.add_child(probe)
		probe.global_position = direct.global_position + Vector3(0, 0, 1)
		assert(direct.open_for(probe))
		probe.queue_free()
	await frames(3)


func begin() -> void:
	lead.set_physics_process(true)
	trailing.set_physics_process(true)
	await until(func() -> bool: return trailing.is_tactical_flanking, 5.0, "A visible threat earns an alternate-route flank")
	assert(lead.current_state in [JaffaAI.State.COMBAT, JaffaAI.State.COVER])
	assert(not lead.is_tactical_flanking)
	assert(trailing._flank_navigation.flank_rooms == PackedStringArray(["room_001", "room_002", "room_003", "room_004"]))


func cleanup() -> void:
	world.queue_free()
	await frames(4)


func run() -> void:
	await setup_encounter()
	var route := LevelNavigator.new(trailing, level)
	assert(not route.plan_flank(target.global_position).is_empty())
	assert(route.plan_flank(target.global_position, 1.0).is_empty(), "Reject excessive walking cost")
	assert(route.plan_flank(trailing.global_position).is_empty(), "A shared room has no second room approach")
	assert(route.plan_flank(Vector3.INF).is_empty() and route.plan_flank(Vector3(999, 0, 999)).is_empty())
	await begin()
	var extra := spawn_jaffa(enemies, level.marker(&"room_001", &"entry") + Vector3(0, 0, -0.8), "OtherTrailing")
	extra.formation_rank = 2
	extra.fire_timer = 100000.0
	extra.notice_time_near = 0.05
	extra.notice_time_far = 0.05
	var facing := target.global_position - extra.global_position
	extra.rotation.y = atan2(-facing.x, -facing.z)
	extra.start_patrol([extra.global_position])
	await frames(20)
	assert(extra._flank_navigation == null and not extra.is_tactical_flanking, "Only one nearby guard takes the flank")
	extra.queue_free()
	var walked := LevelNavigator.new(trailing, level)
	var saw_second := false
	var saw_third := false
	for i in range(1200):
		saw_second = saw_second or walked._room_at(trailing.global_position) == &"room_002"
		saw_third = saw_third or walked._room_at(trailing.global_position) == &"room_003"
		if trailing.flank_status == "arrived":
			break
		await frames(1)
	assert(saw_second and saw_third and trailing.flank_status == "arrived", "Walk the alternate branch rather than cutting through the direct doorway: " + trailing.flank_status)
	assert(not trailing.is_tactical_flanking and trailing._flank_navigation == null)
	assert(trailing.global_position.distance_to(trailing.flank_route_target) < 0.8)
	await cleanup()

	await setup_encounter()
	var alternate := door_between(level, &"room_001", &"room_002")
	assert(alternate.set_locked(true))
	route = LevelNavigator.new(trailing, level)
	assert(route.plan_flank(target.global_position).is_empty(), "One usable route is ordinary combat, not a flank")
	lead.set_physics_process(true)
	trailing.set_physics_process(true)
	await frames(120)
	assert(not trailing.is_tactical_flanking and trailing._flank_navigation == null)
	assert(alternate.locked and not alternate.is_open)
	await cleanup()

	await setup_encounter()
	await begin()
	assert(door_between(level, &"room_002", &"room_003").set_locked(true))
	await frames(3)
	assert(trailing._flank_navigation == null and trailing.flank_status == "blocked_door")
	assert(not trailing.is_tactical_flanking, "A new lock cancels instead of replanning into the direct approach")
	await cleanup()

	await setup_encounter(true)
	await begin()
	var known := trailing._flank_known
	# Concealed movement must not retarget the committed route with an unseen live transform.
	place(target, Vector3(200, 0, 200))
	await until(func() -> bool: return trailing._flank_navigation == null, 20.0, "Bounded last-sighting route completes")
	assert(trailing._flank_known == known and trailing.flank_status == "arrived")
	assert(trailing.investigating and trailing.perception.target == null)
	await cleanup()

	await setup_encounter()
	await begin()
	place(target, NavigationServer3D.map_get_closest_point(level.navigation_map, level.marker(&"room_001", &"entry") + Vector3(0, 0, 2.5)))
	await until(func() -> bool: return trailing._flank_navigation == null, 2.0, "A newly seen moved threat invalidates the old approach")
	assert(trailing.flank_status == "target_changed")
	await cleanup()
	await setup_encounter()
	await begin()
	trailing.set_physics_process(false)
	# A held body models an obstructed corridor: steering cannot move it through collision.
	for i in range(240):
		trailing._process_modular_flank(1.0 / 60.0)
		if trailing._flank_navigation == null:
			break
	assert(trailing.flank_status == "stuck" and not trailing.is_tactical_flanking)
	await cleanup()
	await setup_encounter()
	await begin()
	await frames(3)
	assert(trailing._flank_cooldown < JaffaAI.FLANK_COOLDOWN)
	trailing.run_to(level.marker(&"room_002", &"entry"), level.marker(&"room_002", &"entry"))
	assert(not trailing.is_tactical_flanking and trailing._flank_navigation == null, "Alarm errand preempts a flank")
	assert(trailing._flank_cooldown == JaffaAI.FLANK_COOLDOWN, "Preemption restarts the cooldown even after time spent flanking")
	await cleanup()
	await setup_encounter()
	await begin()
	trailing._process_modular_flank(JaffaAI.FLANK_LIMIT)
	assert(trailing.flank_status == "timeout" and not trailing.is_tactical_flanking)
	await cleanup()
	await setup_encounter()
	await begin()
	target.queue_free()
	await frames(3)
	assert(trailing._flank_navigation == null and trailing.flank_status == "target_gone")
	await cleanup()
	await setup_encounter()
	await begin()
	trailing._on_stunned(1.0)
	assert(not trailing.is_tactical_flanking and trailing._flank_navigation == null)
	await cleanup()
	await setup_encounter()
	await begin()
	place(target, NavigationServer3D.map_get_closest_point(level.navigation_map, level.marker(&"room_001", &"entry") + Vector3(0, 0, 1.5)))
	await until(func() -> bool: return trailing._flank_navigation == null, 2.0, "A nearby visible opponent preempts a flank")
	assert(trailing.flank_status == "close_threat")
	await cleanup()
	await setup_encounter()
	await begin()
	trailing.current_state = JaffaAI.State.DOWNED
	await frames(2)
	assert(trailing._flank_navigation == null and not trailing.is_tactical_flanking)
	await cleanup()
	await setup_encounter()
	await begin()
	trailing.stand_down()
	assert(not trailing.is_tactical_flanking and trailing._flank_navigation == null)
	await cleanup()
	print("PASS modular flanking: real perception, alternate entrance traversal, locks, open passages, cost/no-route fallback, last sighting, alarm preemption, timeout, departure, stun and stand-down")
	await preload("res://tests/support/finish.gd").success(self)
