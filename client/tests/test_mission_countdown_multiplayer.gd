extends "res://tests/test_four_player_join_multiplayer.gd"
## Four operatives, real console RPCs, running/terminal late joins and two full-team retries.
const Fixture = preload("res://tests/support/mission_countdown_fixture.gd")


func port() -> int:
	return 19938 if is_dedicated else 19937


func client_script() -> String:
	return "res://tests/test_mission_countdown_multiplayer.gd"


func mission_id() -> String:
	return SGCNetworkManager.MISSION_TIMED_EXTRACTION


func park_hostiles(room: ModularMission) -> void:
	Fixture.stand_down(room)


func frames(count: int) -> void:
	for i in range(count):
		if is_instance_valid(main):
			for world: GateRoom in main.worlds():
				var mine := world.players_container.get_node_or_null(str(net.local_peer_id)) as PlayerController3D
				if mine != null:
					mine.set_physics_process(false)
				if net.is_server and world is ModularMission and (world as ModularMission).is_started:
					park_hostiles(world as ModularMission)
		OS.delay_msec(1)
		await process_frame


func mission(previous: int = 0) -> ModularMission:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var room := main.current_gate_room as ModularMission
		if room != null and room.is_started and room.get_instance_id() != previous:
			if (slot == 0 and is_dedicated) or room.players_container.has_node(str(net.local_peer_id)):
				require(room.setup_errors.is_empty() and room.level.last_errors.is_empty())
				return room
		await frames(1)
	require(false, "Timed mission did not start")
	return null


func state(room: ModularMission, expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if room.events.timer_state == expected:
			return
		await frames(1)
	require(false, "Timer state %d, expected %d" % [room.events.timer_state, expected])


func result(room: ModularMission, expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if room.mission_result == expected and not room.hud.mission_countdown_panel.visible:
			return
		await frames(1)
	require(false, "Result %d, expected %d" % [room.mission_result, expected])


func fresh(room: ModularMission) -> void:
	# A client bake can finish before the host has applied its initial temporary locks.
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if Fixture.door(room).locked and room.objectives.index == 0 and room.events.fired.is_empty():
			break
		await frames(1)
	require(Fixture.door(room).locked and room.objectives.index == 0 and room.events.fired.is_empty())
	require(room.events.timer_state == MissionEvents.TimerState.IDLE and room.mission_result == -1)
	require(not room.hud.mission_countdown_panel.visible)
	require(Fixture.records_display(room).text == "ACCESS LOCKED")


func use_consoles(room: ModularMission) -> void:
	var actor := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	for index in range(2):
		Fixture.place(actor, Fixture.spot(room, index))
		var deadline := Time.get_ticks_msec() + 10000
		while room.objectives.index <= index and Time.get_ticks_msec() < deadline:
			Fixture.station(room, index).interact(actor)
			await frames(5)
		require(room.objectives.index == index + 1, "Remote console did not earn objective")
	await state(room, MissionEvents.TimerState.RUNNING)


func extract(room: ModularMission) -> void:
	var actor := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	Fixture.place(actor, room.objectives.position_of(room.definition.objectives[-1]))


func lobby() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if main.current_lobby != null and main.worlds().is_empty() and not net.is_in_active_session():
			return
		await frames(1)
	require(false, "Live-timer disconnect did not retire the world")


func all_marked(label: String, count: int) -> void:
	for index in range(1, count + 1):
		require(await marked("%s_%d" % [label, index]))


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/countdown-" + str(OS.get_process_id()))
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
	print("PASS countdown four-operative snapshots, authority, expiry, victory, retry and disconnect (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(mission_id()))
	net.request_start_game()
	var room := await mission()
	await fresh(room)
	Fixture.duration(room, 30.0)
	var count := 4 if is_dedicated else 3
	spawn_child(1)
	require(await marked("ready_1"))
	mark("start_1")
	require(await marked("running_1"))
	await state(room, MissionEvents.TimerState.RUNNING)
	var original_deadline := Time.get_ticks_msec() + int(room.events.remaining_seconds() * 1000.0)
	# Fill the remaining operative slots after the timer is already running.
	await create_timer(0.5).timeout
	for index in range(2, count + 1):
		spawn_child(index)
		require(await marked("running_%d" % index))
	mark("clock_sample", {"seconds": room.events.remaining_seconds(), "at": Time.get_unix_time_from_system()})
	await all_marked("clock_seen", count)
	require(room.players_container.get_child_count() == 4)
	require(not is_dedicated or not room.players_container.has_node("1"))
	require(abs(Time.get_ticks_msec() + int(room.events.remaining_seconds() * 1000.0) - original_deadline) < 5,
		"Late join and repeated console cannot retime the host")
	mark("extract")
	if not is_dedicated:
		extract(room)
	await result(room, 1)
	await state(room, MissionEvents.TimerState.STOPPED)
	await all_marked("won", count)
	var previous := room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	Fixture.duration(room, 2.0)
	await fresh(room)
	await all_marked("fresh_2", count)
	mark("start_2")
	require(await marked("started_2"))
	await result(room, 0)
	await state(room, MissionEvents.TimerState.EXPIRED)
	await all_marked("expired", count)
	# Free one slot and rejoin in the same client process after the final result.
	mark("rejoin")
	require(await marked("left"))
	var leaving_id := int(read_mark("left"))
	var leave_deadline := Time.get_ticks_msec() + 15000
	while net.peers.has(leaving_id) and Time.get_ticks_msec() < leave_deadline:
		await frames(1)
	require(not net.peers.has(leaving_id))
	mark("join_again")
	require(await marked("terminal_late"))
	require(room.players_container.get_child_count() == 4 and room.events.timer_state == MissionEvents.TimerState.EXPIRED)
	previous = room.get_instance_id()
	require(net.request_restart_game())
	room = await mission(previous)
	Fixture.duration(room, 2.0)
	await fresh(room)
	await all_marked("fresh_3", count)
	mark("start_3")
	require(await marked("started_3"))
	await state(room, MissionEvents.TimerState.RUNNING)
	net.disconnect_game()
	await lobby()
	await all_marked("lobby", count)
	for index in range(1, count + 1):
		require(await marked("exit_%d" % index))
	await frames(40)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log := FileAccess.get_file_as_string(output_dir.path_join(file))
			require(log.contains("PASS countdown") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Countdown %d" % slot
	net.selected_class_id = CLASSES[(slot - 1) % CLASSES.size()]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	if slot == 1:
		await fresh(room)
		mark("ready_1")
		require(await marked("start_1"))
		await use_consoles(room)
	else:
		await state(room, MissionEvents.TimerState.RUNNING)
		require(room.events.remaining_seconds() > 0.0 and room.events.remaining_seconds() < 29.8,
			"A late join sees the remaining fixture window, not the authored three minutes")
		require(room.hud.squad_toast_label.text != room.definition.triggers[1].notice,
			"A snapshot does not replay the timer-start notice")
	require(room.hud.mission_countdown_panel.visible)
	# The objective and clock snapshots can arrive on different frames.
	var display := Fixture.records_display(room)
	var display_deadline := Time.get_ticks_msec() + 3000
	while room.objectives.index != 2 and Time.get_ticks_msec() < display_deadline:
		await frames(1)
	require(display.text == "RECORDS SENT\n" + room.hud.mission_countdown_label.text.get_slice("\n", 1),
		"The terminal shows both the earned record and the same clock as the HUD")
	var remaining := room.events.remaining_seconds()
	room.events._on_objective_changed(2)
	require(not room.events._expire_timer(), "A client cannot expire the mission")
	# Bad/stale snapshots cannot reset or inflate the estimate.
	room.events.sync_countdown(-1, str(room.events.timer_id), MissionEvents.TimerState.RUNNING, 180.0)
	room.events.sync_countdown(1000000, "unknown", MissionEvents.TimerState.RUNNING, 180.0)
	room.events.sync_countdown(1000000, str(room.events.timer_id), MissionEvents.TimerState.RUNNING, INF)
	require(room.events.remaining_seconds() <= remaining and room.events.timer_state == MissionEvents.TimerState.RUNNING)
	mark("running_%d" % slot)
	require(await marked("clock_sample"))
	var sample: Dictionary = read_mark("clock_sample")
	var expected := maxf(0.0, float(sample.seconds) - (Time.get_unix_time_from_system() - float(sample.at)))
	require(absf(room.events.remaining_seconds() - expected) < 1.5, "Countdown estimates agree with the host on loopback")
	mark("clock_seen_%d" % slot)
	require(await marked("extract"))
	extract(room)
	await result(room, 1)
	await state(room, MissionEvents.TimerState.STOPPED)
	mark("won_%d" % slot)
	var previous := room.get_instance_id()
	room = await mission(previous)
	await fresh(room)
	mark("fresh_2_%d" % slot)
	if slot == 1:
		require(await marked("start_2"))
		await use_consoles(room)
		mark("started_2")
	await result(room, 0)
	await state(room, MissionEvents.TimerState.EXPIRED)
	require(room.hud.debrief_subtitle.text == "EXTRACTION WINDOW EXPIRED")
	require(Fixture.records_display(room).text == "RECORDS SENT")
	room.events.sync_countdown(1000000, str(room.events.timer_id), MissionEvents.TimerState.RUNNING, 180.0)
	require(room.events.timer_state == MissionEvents.TimerState.EXPIRED and not room.hud.mission_countdown_panel.visible,
		"A terminal snapshot cannot be resurrected")
	mark("expired_%d" % slot)
	if slot == (4 if is_dedicated else 3):
		require(await marked("rejoin"))
		var old_id := net.local_peer_id
		room.hud._on_return_pressed()
		await lobby()
		mark("left", old_id)
		require(await marked("join_again"))
		require(net.join_game("127.0.0.1", port()) == OK)
		room = await mission()
		await result(room, 0)
		await state(room, MissionEvents.TimerState.EXPIRED)
		require(room.hud.debrief_subtitle.text == "EXTRACTION WINDOW EXPIRED")
		require((room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D).health_component.frozen,
			"A pawn arriving after the result is also frozen")
		mark("terminal_late")
	previous = room.get_instance_id()
	room = await mission(previous)
	await fresh(room)
	mark("fresh_3_%d" % slot)
	if slot == 1:
		require(await marked("start_3"))
		await use_consoles(room)
		mark("started_3")
	await lobby()
	await create_timer(2.1).timeout
	require(main.current_lobby != null and main.worlds().is_empty(), "No stale deadline after disconnect")
	mark("lobby_%d" % slot)
