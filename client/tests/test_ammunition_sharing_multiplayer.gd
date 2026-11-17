extends "res://tests/test_mission_countdown_multiplayer.gd"
## Real ENet intent, forged sender/replay, late snapshots, competing donors and fresh retry.


func port() -> int:
	return 19944 if is_dedicated else 19943


func client_script() -> String:
	return "res://tests/test_ammunition_sharing_multiplayer.gd"


func actor(room: ModularMission, index: int) -> PlayerController3D:
	return room.players_container.get_node(str(int(read_mark("ready_%d" % index)))) as PlayerController3D


func reserves(room: ModularMission, first: int, second: int) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if actor(room, 1).current_weapon.reserve_ammo == first and actor(room, 2).current_weapon.reserve_ammo == second:
			return
		await frames(1)
	require(false, "Shared reserves did not converge: %d/%d expected %d/%d" % [actor(room, 1).current_weapon.reserve_ammo, actor(room, 2).current_weapon.reserve_ammo, first, second])


func prepare(room: ModularMission, round_id: int, count: int) -> void:
	for index in range(1, count + 1):
		var operative := actor(room, index)
		operative._equip_slot_local(1 if index in [1, 3] else 2)
		operative.current_weapon.reserve_ammo = 100 if index == 1 else (40 if index == 2 else 80)
		operative._next_ammo_share_ms = 0
		operative._broadcast_weapon_state()
	if not is_dedicated:
		var host := room.players_container.get_node("1") as PlayerController3D
		host.switch_slot(2)
		host.current_weapon.reserve_ammo = 80
		host.global_position = Vector3(-1, 50.05, 0)
		host._broadcast_weapon_state()
	mark("setup_%d" % round_id)
	await all_marked("positioned_%d" % round_id, count)
	# A file barrier can precede delivery of the owner's movement relay.
	for index in range(1, count + 1):
		var deadline := Time.get_ticks_msec() + 15000
		while actor(room, index).global_position.distance_to(Vector3(index - 1, 50.05, 0)) >= 0.1 and Time.get_ticks_msec() < deadline:
			await frames(1)
		require(actor(room, index).global_position.distance_to(Vector3(index - 1, 50.05, 0)) < 0.1, "Owner placement reaches server for operative %d" % index)


func position_owner(room: ModularMission, round_id: int) -> void:
	require(await marked("setup_%d" % round_id))
	var mine := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	Fixture.place(mine, Vector3(slot - 1, 50, 0))
	# Wait for the authoritative active-weapon snapshot, without predicting inventories.
	var expected := "mp5" if slot == 1 else ("staff_weapon" if slot == 3 else "m9")
	var deadline := Time.get_ticks_msec() + 15000
	while mine.current_weapon.weapon_id != expected and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(mine.current_weapon.weapon_id == expected and not mine.ammo_share_incarnation.is_empty())
	mark("positioned_%d_%d" % [round_id, slot])


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/ammunition-" + str(OS.get_process_id()))
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
	print("PASS ammunition sharing four-operative authority, late snapshots, competing donors, retry and disconnect (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	var count := 4 if is_dedicated else 3
	for index: int in [1, 2]:
		spawn_child(index)
		require(await marked("ready_%d" % index))
	await prepare(room, 1, 2)
	# The first transfer happens before the other operative(s) load this mission.
	mark("give_1")
	await reserves(room, 85, 55)
	for index in range(3, count + 1):
		spawn_child(index)
		require(await marked("ready_%d" % index))
	mark("four")
	await all_marked("seen_1", count)
	require(room.players_container.get_child_count() == 4 and (not is_dedicated or not room.players_container.has_node("1")))
	await prepare(room, 2, count)
	mark("give_2")
	if not is_dedicated:
		(room.players_container.get_node("1") as PlayerController3D).request_ammo_share(actor(room, 2))
	await all_marked("sent_2", count)
	var competition_deadline := Time.get_ticks_msec() + 15000
	while actor(room, 2).current_weapon.reserve_ammo != 60 and Time.get_ticks_msec() < competition_deadline:
		await frames(1)
	var other := actor(room, 4) if is_dedicated else room.players_container.get_node("1") as PlayerController3D
	var donor_reserve := actor(room, 1).current_weapon.reserve_ammo
	var other_reserve := other.current_weapon.reserve_ammo
	require(actor(room, 2).current_weapon.reserve_ammo == 60)
	require(donor_reserve + other_reserve + 60 == 220, "Competing donors conserve all reserve rounds and respect capacity")
	mark("competition", {"donor": donor_reserve, "other": other_reserve})
	await all_marked("seen_2", count)
	var previous := room.get_instance_id()
	var old_incarnation := actor(room, 1).ammo_share_incarnation
	require(net.request_restart_game())
	room = await mission(previous)
	await all_marked("fresh", count)
	require(actor(room, 1).ammo_share_incarnation != old_incarnation)
	await prepare(room, 3, count)
	mark("stale")
	require(await marked("stale_sent"))
	await frames(40)
	await reserves(room, 100, 40)
	mark("give_3")
	await reserves(room, 85, 55)
	await all_marked("seen_3", count)
	mark("leave_recipient")
	require(await marked("recipient_left"))
	var deadline := Time.get_ticks_msec() + 15000
	while room.players_container.has_node(str(int(read_mark("ready_2")))) and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(not room.players_container.has_node(str(int(read_mark("ready_2")))))
	mark("departed")
	require(await marked("missing_sent"))
	await frames(40)
	require(actor(room, 1).current_weapon.reserve_ammo == 85)
	net.disconnect_game()
	await lobby()
	await all_marked("lobby", count)
	for index in range(1, count + 1):
		require(await marked("exit_%d" % index))
	await frames(40)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log := FileAccess.get_file_as_string(output_dir.path_join(file))
			require(log.contains("PASS ammunition sharing") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Ammo operative %d" % slot
	net.selected_class_id = CLASSES[(slot - 1) % CLASSES.size()]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	mark("ready_%d" % slot, net.local_peer_id)
	if slot <= 2:
		await position_owner(room, 1)
		if slot == 1:
			require(await marked("give_1"))
			var donor := actor(room, 1)
			var receiver := actor(room, 2)
			donor.request_ammo_share(receiver)
			# Replay the sequence and forge the recipient's donor actor from this connection.
			donor.server_request_ammo_share.rpc_id(1, donor._ammo_share_sequence, donor.ammo_share_incarnation, str(receiver.name), receiver.ammo_share_incarnation, "mp5", "m9")
			receiver.server_request_ammo_share.rpc_id(1, 9999, receiver.ammo_share_incarnation, str(donor.name), donor.ammo_share_incarnation, "m9", "mp5")
			receiver.sync_weapon_state.rpc_id(1, 2, "m9", 15, 9999, 0.0, false, false)
	require(await marked("four"))
	await reserves(room, 85, 55)
	require(room.players_container.get_child_count() == 4)
	if slot <= 2:
		require(room.hud.squad_toast_label.text.contains("GAVE 15") if slot == 1 else room.hud.squad_toast_label.text.contains("RECEIVED 15"), "Only participants receive the transfer acknowledgement")
	mark("seen_1_%d" % slot)
	await position_owner(room, 2)
	require(await marked("give_2"))
	if slot == 1 or (is_dedicated and slot == 4):
		(room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D).request_ammo_share(actor(room, 2))
	mark("sent_2_%d" % slot)
	require(await marked("competition"))
	var final: Dictionary = read_mark("competition")
	await reserves(room, int(final.donor), 60)
	var other := actor(room, 4) if is_dedicated else room.players_container.get_node("1") as PlayerController3D
	var deadline := Time.get_ticks_msec() + 15000
	while other.current_weapon.reserve_ammo != int(final.other) and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(other.current_weapon.reserve_ammo == int(final.other))
	mark("seen_2_%d" % slot)
	var old_donor := actor(room, 1).ammo_share_incarnation
	var old_receiver := actor(room, 2).ammo_share_incarnation
	var previous := room.get_instance_id()
	room = await mission(previous)
	var mine := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	require(mine.active_slot == 1 and mine.current_weapon.reserve_ammo == mine.current_weapon.reserve_capacity, "Retry restores the class inventory")
	mark("fresh_%d" % slot)
	await position_owner(room, 3)
	if slot == 1:
		require(await marked("stale"))
		actor(room, 1).server_request_ammo_share.rpc_id(1, 9999, old_donor, str(actor(room, 2).name), old_receiver, "mp5", "m9")
		mark("stale_sent")
		require(await marked("give_3"))
		actor(room, 1).request_ammo_share(actor(room, 2))
	await reserves(room, 85, 55)
	mark("seen_3_%d" % slot)
	if slot == 2:
		require(await marked("leave_recipient"))
		net.disconnect_game()
		await lobby()
		mark("recipient_left")
	elif slot == 1:
		require(await marked("departed"))
		actor(room, 1).server_request_ammo_share.rpc_id(1, 10000, actor(room, 1).ammo_share_incarnation, str(int(read_mark("ready_2"))), old_receiver, "mp5", "m9")
		mark("missing_sent")
	await lobby()
	mark("lobby_%d" % slot)
