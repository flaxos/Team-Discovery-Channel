extends "res://tests/test_mission_countdown_multiplayer.gd"
## Four ENet operatives use the authored compound rings, including a mid-cycle join.
const State := TransportRings.RingState


func port() -> int:
	return 19974 if is_dedicated else 19973


func client_script() -> String:
	return "res://tests/test_ring_transport_multiplayer.gd"


func park_hostiles(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy: JaffaAI in room.enemies.get_children():
		if enemy.is_physics_processing():
			enemy.stand_down()


func rings(room: ModularMission, deck: String) -> TransportRings:
	return room.level.get_node("ring_" + deck + "/Attachments/Interactions/transport/Rings")


func pawn(room: ModularMission, index: int) -> PlayerController3D:
	var id := 1 if index == 0 else int(read_mark("ready_%d" % index))
	return room.players_container.get_node_or_null(str(id)) as PlayerController3D


func spot(rig: TransportRings, index: int) -> Vector3:
	return rig.to_global(Vector3(0.8 if index % 2 else -0.8, 0.08, 0.8 if index >= 2 else -0.8))


func wait_for_pawn(room: ModularMission, index: int, position: Vector3) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var actor := pawn(room, index)
		if actor != null and actor.global_position.distance_to(position) < 0.16:
			return
		await frames(1)
	require(false, "Pawn %d did not arrive at %s" % [index, position])


func wait_for_cycle(room: ModularMission, expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if rings(room, "lower").current_state == expected and rings(room, "upper").current_state == expected:
			return
		await frames(1)
	require(false, "Both ring ends should reach phase %d" % expected)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/rings-" + str(OS.get_process_id()))
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
	print("PASS ring transport (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	var lower := rings(room, "lower")
	var upper := rings(room, "upper")
	require(lower.paired_rings == upper and upper.paired_rings == lower, "The authored pair is reciprocal")
	require(lower.is_in_group("interactable") and upper.is_in_group("interactable"), "Each pad accepts interaction")
	require(is_equal_approx(upper.global_position.y - lower.global_position.y, 4.0), "The pair connects separate decks")
	for index: int in [1, 2]:
		spawn_child(index)
		require(await marked("ready_%d" % index))
	await wait_for_pawn(room, 1, spot(lower, 1))
	await wait_for_pawn(room, 2, spot(upper, 2))
	mark("try_blocked")
	require(await marked("blocked_sent"))
	await frames(60)
	require(lower.current_state == State.INACTIVE and upper.current_state == State.INACTIVE, "An occupied destination blocks activation")
	mark("clear")
	await wait_for_pawn(room, 2, spot(lower, 2))
	# Keep the telegraph open until the test's late peers finish loading. With
	# fixed FPS, loading time and simulation time advance independently.
	Engine.time_scale = 0.01
	mark("start")
	await wait_for_cycle(room, State.TELEGRAPH)
	var count := 4 if is_dedicated else 3
	for index in range(3, count + 1):
		spawn_child(index)
	for index in range(3, count + 1):
		require(await marked("ready_%d" % index))
	Engine.time_scale = 1.0
	await wait_for_pawn(room, 1, spot(upper, 1))
	await wait_for_pawn(room, 2, spot(upper, 2))
	await wait_for_cycle(room, State.INACTIVE)
	await all_marked("first_seen", count)
	if not is_dedicated:
		pawn(room, 0).apply_transport_arrival(spot(upper, 0))
	mark("prepare_return")
	for index in range(0 if not is_dedicated else 1, count + 1):
		await wait_for_pawn(room, index, spot(upper, index % 4))
	mark("return")
	for index in range(0 if not is_dedicated else 1, count + 1):
		await wait_for_pawn(room, index, spot(lower, index % 4))
	await wait_for_cycle(room, State.INACTIVE)
	await all_marked("return_seen", count)
	require(room.players_container.get_child_count() == 4 and net._player_pauses.is_empty())
	var previous := room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	await all_marked("retry_seen", count)
	require(rings(room, "lower").current_state == State.INACTIVE and rings(room, "upper").current_state == State.INACTIVE)
	mark("done")
	for index in range(1, count + 1):
		require(await marked("exit_%d" % index))
	await frames(40)
	for index in range(1, count + 1):
		var log := FileAccess.get_file_as_string(output_dir.path_join("client_%d.log" % index))
		require(log.contains("PASS ring transport") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Rings %d" % slot
	net.selected_class_id = CLASSES[slot - 1]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	var mine := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	var lower := rings(room, "lower")
	var upper := rings(room, "upper")
	var initial_id := mine.get_instance_id()
	var initial_health := mine.health_component.current_health
	var initial_ammo := mine.current_weapon.current_ammo
	if slot < 3:
		mine.apply_transport_arrival(spot(lower if slot == 1 else upper, slot))
	else:
		await wait_for_cycle(room, State.TELEGRAPH)
		require(lower.telegraph_light.visible and upper.telegraph_light.visible, "Late join sees both ends of the active cycle")
	mark("ready_%d" % slot, net.local_peer_id)
	if slot == 1:
		require(await marked("try_blocked"))
		mine._try_interact()
		mark("blocked_sent")
		require(await marked("start"))
		mine._try_interact()
	elif slot == 2:
		require(await marked("clear"))
		mine.apply_transport_arrival(spot(lower, slot))
	await wait_for_cycle(room, State.TELEGRAPH)
	await wait_for_pawn(room, 1, spot(upper, 1))
	await wait_for_pawn(room, 2, spot(upper, 2))
	await wait_for_cycle(room, State.INACTIVE)
	mark("first_seen_%d" % slot)
	require(await marked("prepare_return"))
	if slot >= 3:
		mine.apply_transport_arrival(spot(upper, slot % 4))
	require(await marked("return"))
	if slot == 1:
		mine._try_interact()
	var count := 4 if is_dedicated else 3
	for index in range(0 if not is_dedicated else 1, count + 1):
		await wait_for_pawn(room, index, spot(lower, index % 4))
	await wait_for_cycle(room, State.INACTIVE)
	require(mine.get_instance_id() == initial_id and mine.health_component.current_health == initial_health)
	require(mine.current_weapon.current_ammo == initial_ammo and net._paused_actors.is_empty())
	require(mine.synchronizer.public_visibility, "The owner publishes movement again after transport")
	mark("return_seen_%d" % slot)
	room = await mission(room.get_instance_id())
	require(rings(room, "lower").current_state == State.INACTIVE and rings(room, "upper").current_state == State.INACTIVE)
	mark("retry_seen_%d" % slot)
	require(await marked("done"))
