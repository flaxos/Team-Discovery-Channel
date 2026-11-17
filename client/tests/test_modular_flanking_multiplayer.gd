extends "res://tests/test_mission_countdown_multiplayer.gd"
## Four real ENet operatives in the existing compound. Late peers join a held flank;
## then the production controller walks it, retries, and cancels another at mission end.
const Encounter = preload("res://tests/support/modular_flank_encounter.gd")


func port() -> int:
	return 19942 if is_dedicated else 19941


func client_script() -> String:
	return "res://tests/test_modular_flanking_multiplayer.gd"


func park_hostiles(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy: JaffaAI in room.enemies.get_children():
		if enemy.name not in ["FlankLead", "FlankTrail"]:
			enemy.stand_down()
	for actor: PlayerController3D in room.players_container.get_children():
		actor.health_component.frozen = true


func xyz(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func round_positions(room: ModularMission, encounter: Dictionary, round_id: int) -> void:
	if not is_dedicated:
		Fixture.place(room.players_container.get_node("1") as PlayerController3D, encounter.park)
	mark("positions_%d" % round_id, {"target": xyz(encounter.known), "park": xyz(encounter.park), "rooms": Array(encounter.rooms)})


func positioned(room: ModularMission, encounter: Dictionary, round_id: int, count: int) -> void:
	await all_marked("positioned_%d" % round_id, count)
	var deadline := Time.get_ticks_msec() + 15000
	var target_id := int(read_mark("ready_1"))
	while Time.get_ticks_msec() < deadline:
		var actor := room.players_container.get_node_or_null(str(target_id)) as PlayerController3D
		if actor != null and actor.global_position.distance_to(encounter.known) < 0.4:
			return
		await frames(1)
	require(false, "Owner placement did not reach host")


func started(room: ModularMission, encounter: Dictionary) -> Array[JaffaAI]:
	var guards := Encounter.spawn(room, encounter)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if guards[1].is_tactical_flanking:
			guards[1].set_physics_process(false)
			return guards
		await frames(1)
	require(false, "Real sentry detection did not begin the native compound flank")
	return guards


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/flanking-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	if slot > 0:
		await run_client()
	else:
		await run_host()
	net.disconnect_game()
	await frames(5)
	mark("exit_%d" % slot)
	print("PASS modular flanking four-operative replication, late join, traversal, result cancellation and two retries (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	var encounter := await Encounter.choose(room)
	require(not encounter.is_empty(), "The native compound has a valid bounded alternate approach")
	var count := 4 if is_dedicated else 3
	spawn_child(1)
	require(await marked("ready_1"))
	await round_positions(room, encounter, 1)
	await positioned(room, encounter, 1, 1)
	var guards := await started(room, encounter)
	# Hold the real plan only for deterministic late-loading inspection, then release it.
	for index in range(2, count + 1):
		spawn_child(index)
		require(await marked("ready_%d" % index))
	await positioned(room, encounter, 1, count)
	require(room.players_container.get_child_count() == 4 and (not is_dedicated or not room.players_container.has_node("1")))
	mark("observe_1")
	await all_marked("seen_start_1", count)
	var follower := guards[1]
	var checker := LevelNavigator.new(follower, room.level)
	var visited: Array[String] = []
	guards[1].set_physics_process(true)
	var deadline := Time.get_ticks_msec() + 20000
	while follower.is_tactical_flanking and Time.get_ticks_msec() < deadline:
		var id := str(checker._room_at(follower.global_position))
		if not visited.has(id):
			visited.append(id)
		await frames(1)
	require(follower.flank_status == "arrived", "The server completes the alternate approach: " + follower.flank_status)
	for id: String in encounter.rooms:
		require(visited.has(id) or id == encounter.rooms[-1], "Server visited the authored alternate branch: " + id)
	for guard in guards:
		guard.set_physics_process(false)
	mark("arrived", xyz(follower.global_position))
	await all_marked("seen_arrival", count)
	var previous := room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	await all_marked("fresh_2", count)
	require(not room.enemies.has_node("FlankTrail"), "Retry removes old plans and actors")
	encounter = await Encounter.choose(room)
	require(not encounter.is_empty())
	await round_positions(room, encounter, 2)
	await positioned(room, encounter, 2, count)
	guards = await started(room, encounter)
	mark("observe_2")
	await all_marked("seen_start_2", count)
	room.conclude(false)
	require(not guards[1].is_tactical_flanking and guards[1]._flank_navigation == null)
	await all_marked("seen_result", count)
	previous = room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	await all_marked("fresh_3", count)
	require(not room.enemies.has_node("FlankTrail"))
	net.disconnect_game()
	await lobby()
	await all_marked("lobby", count)
	for index in range(1, count + 1):
		require(await marked("exit_%d" % index))
	await frames(40)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log := FileAccess.get_file_as_string(output_dir.path_join(file))
			require(log.contains("PASS modular flanking") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func owner_position(room: ModularMission, round_id: int) -> Dictionary:
	require(await marked("positions_%d" % round_id))
	var data: Dictionary = read_mark("positions_%d" % round_id)
	Fixture.place(room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D, vector(data.target if slot == 1 else data.park))
	mark("positioned_%d_%d" % [round_id, slot])
	return data


func see_start(room: ModularMission, round_id: int) -> JaffaAI:
	require(await marked("observe_%d" % round_id))
	var follower: JaffaAI
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		follower = room.enemies.get_node_or_null("FlankTrail") as JaffaAI
		if follower != null and follower.is_tactical_flanking and room.players_container.get_child_count() == 4:
			break
		await frames(1)
	require(follower != null and follower.is_tactical_flanking)
	require(follower._flank_navigation == null, "Clients receive state, not authoritative path planners")
	var position := follower.global_position
	follower.break_formation_and_engage()
	require(not follower._try_modular_flank())
	var query := LevelNavigator.new(follower, room.level)
	require(query.plan_flank(Vector3.ZERO).is_empty(), "A client cannot plan a tactical route")
	await frames(20)
	require(follower.is_tactical_flanking and follower.global_position.distance_to(position) < 0.1,
		"A held server pose is not advanced by client AI")
	mark("seen_start_%d_%d" % [round_id, slot])
	return follower


func run_client() -> void:
	net.player_name = "Flank observer %d" % slot
	net.selected_class_id = CLASSES[(slot - 1) % CLASSES.size()]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	mark("ready_%d" % slot, net.local_peer_id)
	var data := await owner_position(room, 1)
	var follower := await see_start(room, 1)
	var checker := LevelNavigator.new(follower, room.level)
	var visited: Array[String] = []
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var id := str(checker._room_at(follower.global_position))
		if not visited.has(id):
			visited.append(id)
		if exists("arrived") and not follower.is_tactical_flanking and follower.global_position.distance_to(vector(read_mark("arrived"))) < 0.2:
			break
		await frames(1)
	require(exists("arrived") and not follower.is_tactical_flanking)
	require(follower.global_position.distance_to(vector(read_mark("arrived"))) < 0.2)
	for id: String in data.rooms:
		require(visited.has(id), "Client observes physical alternate-route traversal: " + id)
	mark("seen_arrival_%d" % slot)
	var previous := room.get_instance_id()
	room = await mission(previous)
	require(not room.enemies.has_node("FlankTrail"))
	mark("fresh_2_%d" % slot)
	await owner_position(room, 2)
	follower = await see_start(room, 2)
	await result(room, 0)
	deadline = Time.get_ticks_msec() + 10000
	while follower.is_tactical_flanking and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(not follower.is_tactical_flanking and follower._flank_navigation == null)
	mark("seen_result_%d" % slot)
	previous = room.get_instance_id()
	room = await mission(previous)
	require(not room.enemies.has_node("FlankTrail"))
	mark("fresh_3_%d" % slot)
	await lobby()
	mark("lobby_%d" % slot)
