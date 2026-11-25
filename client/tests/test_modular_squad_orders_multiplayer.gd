extends "res://tests/test_mission_countdown_multiplayer.gd"
## Four operatives, a real wheel command, native cover and rally movement, late join and retry.
const Wheel := preload("res://scripts/ui/RadialCommandWheel.gd")


func port() -> int:
	return 19976 if is_dedicated else 19975


func client_script() -> String:
	return "res://tests/test_modular_squad_orders_multiplayer.gd"


func park_hostiles(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy: JaffaAI in room.enemies.get_children():
		if enemy.is_physics_processing():
			enemy.stand_down()


func supports(room: ModularMission) -> Array[SGCAirmanAI]:
	var result: Array[SGCAirmanAI] = []
	if room.allies_container != null:
		for airman: SGCAirmanAI in room.allies_container.get_children():
			result.append(airman)
	return result


func wait_until(condition: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 35000
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return
		await frames(1)
	require(false, message)


func cover_reached(room: ModularMission) -> bool:
	for airman: SGCAirmanAI in supports(room):
		if airman.current_state == SGCAirmanAI.State.HOLD_CORNER and airman.is_in_cover:
			return room.get_current_sector(airman.global_position) == "CHECKPOINT"
	return false


func rally_reached(room: ModularMission) -> bool:
	var team := supports(room)
	if team.size() != 2 or team[0].global_position.distance_to(team[1].global_position) < 0.85:
		return false
	for airman: SGCAirmanAI in team:
		if airman.current_state != SGCAirmanAI.State.ORDER_MOVE or room.get_current_sector(airman.global_position) != "APPROACH2":
			return false
	return true


func cover_goal(room: ModularMission) -> Vector3:
	var attachment := room.definition.room_attachment(&"checkpoint", &"cover_left")
	var node := room.level.get_node("checkpoint/" + str(LevelRoomComposer.node_path(attachment))) as Node3D
	return node.global_transform * attachment.approach


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/squad-orders-" + str(OS.get_process_id()))
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
	print("PASS modular Airman orders (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	require(supports(room).size() == 2)
	var entry := room.level.marker(&"gate", &"entry")
	for airman: SGCAirmanAI in supports(room):
		require(airman.current_state == SGCAirmanAI.State.STAGING)
		require(airman.global_position.distance_to(entry) < 2.3)
	spawn_child(1)
	require(await marked("ready_1"))
	var issuer := room.players_container.get_node(str(int(read_mark("ready_1")))) as PlayerController3D
	await wait_until(func() -> bool: return room.get_current_sector(issuer.global_position) == "APPROACH2", "Owner's position reaches host")
	mark("cover")
	await wait_until(func() -> bool:
		return supports(room).any(func(airman: SGCAirmanAI) -> bool: return airman.current_state == SGCAirmanAI.State.HOLD_CORNER),
		"Remote Hold Corner reaches server"
	)
	var walker: SGCAirmanAI
	for airman: SGCAirmanAI in supports(room):
		if airman.current_state == SGCAirmanAI.State.HOLD_CORNER:
			walker = airman
	require(walker.current_anchor_type == "cover" and walker.current_anchor_position.distance_to(cover_goal(room)) < 0.45)
	require(walker.global_position.distance_to(walker.current_anchor_position) > 10.0, "Order must start a walk from staging")
	# Keep the order en route until the remaining peers have loaded the world.
	Engine.time_scale = 0.02
	var count := 4 if is_dedicated else 3
	for index in range(2, count + 1):
		spawn_child(index)
	for index in range(2, count + 1):
		require(await marked("ready_%d" % index))
	Engine.time_scale = 1.0
	await wait_until(func() -> bool: return cover_reached(room), "The Airman walks to the cover attachment")
	var door := room.level.get_node("Door_002") as ModularDoor
	require(door.is_open, "The route walks through the native checkpoint door")
	await all_marked("saw_cover", count)
	require(room.players_container.get_child_count() == 4)
	mark("rally")
	await wait_until(func() -> bool: return rally_reached(room), "Both Airmen regroup to distinct rally positions")
	await all_marked("saw_rally", count)
	room.conclude(false)
	require(supports(room).all(func(airman: SGCAirmanAI) -> bool: return not airman.is_physics_processing() and airman.health_component.frozen))
	await all_marked("saw_result", count)
	var previous := room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	await all_marked("fresh", count)
	require(supports(room).size() == 2 and supports(room)[0].current_state == SGCAirmanAI.State.STAGING)
	mark("done")
	for index in range(1, count + 1):
		require(await marked("exit_%d" % index))
	await frames(40)
	for index in range(1, count + 1):
		var log := FileAccess.get_file_as_string(output_dir.path_join("client_%d.log" % index))
		require(log.contains("PASS modular Airman orders") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Support %d" % slot
	net.selected_class_id = CLASSES[slot - 1]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	await wait_until(func() -> bool: return supports(room).size() == 2, "Both Airman actors replicate")
	var callsigns: Array[String] = []
	for airman: SGCAirmanAI in supports(room):
		callsigns.append(airman.airman_callsign)
	require("AIRMAN REYES" in callsigns and "AIRMAN CHEN" in callsigns, "Support callsigns replicate")
	var issuer := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	if slot == 1:
		Fixture.place(issuer, room.level.marker(&"approach2", &"entry"))
	else:
		require(supports(room).any(func(airman: SGCAirmanAI) -> bool: return airman.current_state == SGCAirmanAI.State.HOLD_CORNER),
			"A late join sees an already ordered Airman")
	mark("ready_%d" % slot, net.local_peer_id)
	if slot == 1:
		require(await marked("cover"))
		issuer.execute_squad_radial_command(Wheel.CMD_HOLD_CORNER, cover_goal(room))
		await wait_until(func() -> bool: return room.hud.squad_toast_label.text.contains("HOLD COVER"), "Owner receives the accepted anchor")
	await wait_until(func() -> bool: return cover_reached(room), "Client sees the Airman take cover")
	mark("saw_cover_%d" % slot)
	require(await marked("rally"))
	if slot == 1:
		issuer.issue_squad_regroup()
	await wait_until(func() -> bool: return rally_reached(room), "Client sees both Airmen rally")
	mark("saw_rally_%d" % slot)
	await wait_until(func() -> bool: return room.mission_result >= 0, "Result arrives")
	require(supports(room).all(func(airman: SGCAirmanAI) -> bool: return not airman.is_physics_processing()), "Clients retire Airman tactics at results")
	mark("saw_result_%d" % slot)
	room = await mission(room.get_instance_id())
	await wait_until(func() -> bool: return supports(room).size() == 2, "Support spawns on retry")
	require(supports(room)[0].current_state == SGCAirmanAI.State.STAGING)
	mark("fresh_%d" % slot)
	require(await marked("done"))
