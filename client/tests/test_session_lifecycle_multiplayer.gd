extends "res://tests/test_four_player_join_multiplayer.gd"
## Full-team lifecycle with a surviving observer, abrupt connection-loss bursts,
## actual HUD returns, same-process rejoining, full-team retry and same-port rehosting.
var epochs: Dictionary = {}
var connection_counts: Dictionary = {}


func remember_connections() -> void:
	for name: String in ["game_started", "session_ended", "mission_restart_preparing", "mission_restart_released", "mission_peer_ready", "player_list_updated"]:
		var source: Signal = net.get(name)
		connection_counts[name] = source.get_connections().size()


func port() -> int:
	return 19936 if is_dedicated else 19935


func client_script() -> String:
	return "res://tests/test_session_lifecycle_multiplayer.gd"


func lobby() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if main.current_lobby != null and main.worlds().is_empty() and main.session == null and not net.is_in_active_session():
			break
		await frames(1)
	require(main.current_lobby != null and main.worlds().is_empty() and main.session == null,
		"Disconnect returns to the existing coordinator's lobby and removes both worlds")
	require(not net.is_in_active_session() and net.peers.is_empty() and net.mission_ready_peers.is_empty())
	require(not net.mission_started and not net.restart_pending and net.local_peer_id == 1)
	require(net._player_pauses.is_empty() and net._paused_actors.is_empty())
	require(net._player_transfer_changed.get_connections().is_empty(), "No suspended handoff awaits a retired world")
	require(not paused, "Lobby return also clears pause state")
	require(main.world_container.get_child_count() == 0 and main.ui_container.get_child_count() == 1,
		"No old world, duplicate lobby, or dead session remains")
	await frames(2)  # Let the retired world's queued objects disconnect their signals.
	for name: String in connection_counts:
		var source: Signal = net.get(name)
		require(source.get_connections().size() == connection_counts[name], "No accumulated signal handlers: " + name)


func roster(label: String) -> void:
	await see_snapshot(label)
	var expected: Dictionary = read_mark("snapshot_" + label)
	var wanted: Array[int] = [1]
	for key: String in expected:
		if int(key) != 1:
			wanted.append(int(key))
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if net.peers.size() == wanted.size():
			var complete := true
			for id in wanted:
				complete = complete and net.peers.has(id)
			if complete:
				mark("roster_%s_%d" % [label, slot])
				return
		await frames(1)
	require(false, "Roster %s wanted=%s actual=%s" % [label, wanted, net.peers.keys()])


func snapshot(label: String, active_slots: Array[int], expected_count: int = 4) -> void:
	await super.snapshot(label, active_slots, expected_count)
	for index in active_slots:
		require(await marked("roster_%s_%d" % [label, index]))


func connect_slots(active: Array[int], phase: String, spawn: bool = false) -> void:
	for index in active:
		if spawn:
			spawn_child(index)
		else:
			mark("join_%s_%d" % [phase, index])
		await release_load(index, phase)


func release_load(index: int, phase: String) -> void:
	var epoch: int = epochs.get(index, 0) + 1
	epochs[index] = epoch
	require(await marked("loading_%d_%d" % [index, epoch]))
	mark("load_%d_%d" % [index, epoch])
	require(await marked("ready_%s_%d" % [phase, index]))


func retry_team(active: Array[int], phase: String) -> void:
	var previous := main.current_gate_room.get_instance_id()
	require(net.request_restart_game())
	for index in active:
		await release_load(index, phase)
	await worlds(previous)
	await frames(30)
	await snapshot(phase, active)


func departed(active: Array[int], phase: String) -> void:
	for index in active:
		require(await marked("closed_%s_%d" % [phase, index]))
	multiplayer_poll = true
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var remaining := false
		for index in active:
			var id := int(read_mark("id_%s_%d" % [phase, index]))
			remaining = remaining or net.peers.has(id) or net.mission_ready_peers.has(id)
			for world: GateRoom in main.worlds():
				remaining = remaining or world.players_container.has_node(str(id))
			remaining = remaining or main.session.placement.has(id)
		if not remaining:
			return
		await frames(1)
	require(false, "Departed identities survive burst: " + phase)


func run_host() -> void:
	remember_connections()
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(MISSION))
	net.request_start_game()
	await worlds()
	var active: Array[int] = [1, 2, 3]
	if is_dedicated:
		active.append(4)
	await connect_slots(active, "initial", true)
	await frames(30)
	await snapshot("initial", active)
	var first := int(read_mark("loading_1_1"))
	await travel(first)
	var dropped: Array[int] = active.duplicate()
	dropped.erase(1)
	multiplayer_poll = false
	# Reset all affected physical links before one host poll. Clients learn of the
	# unexpected loss through ENet, without manually invalidating their live API.
	for index in dropped:
		var id := int(read_mark("loading_%d_1" % index))
		mark("id_burst_%d" % index, id)
		net._peer.get_peer(id).peer_disconnect_now()
	net._peer.get_host().flush()
	mark("burst")
	multiplayer_poll = true
	await departed(dropped, "burst")
	await frames(30)
	await snapshot("survivor", [1], 1 if is_dedicated else 2)
	await connect_slots(dropped, "rejoined")
	await frames(30)
	await snapshot("rejoined", active)
	await retry_team(active, "retry")
	multiplayer_poll = false
	mark("hud_leave")
	await departed(active, "hud")
	await connect_slots(active, "hud_rejoined")
	await frames(30)
	await snapshot("hud_rejoined", active)
	# Native host loss is detected by polling, rather than by the normal leave API.
	# Poll immediately, as the engine does for a transport loss, before gameplay runs.
	net.auto_reconnect = true
	net._peer.close()
	net.multiplayer.poll()
	await lobby()
	await frames(150)
	require(not net.is_in_active_session(), "A stopped server never reconnects as a client")
	net.auto_reconnect = false
	for index in active:
		require(await marked("server_gone_%d" % index))
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(MISSION))
	net.request_start_game()
	await worlds()
	await connect_slots(active, "rehosted")
	await frames(30)
	await snapshot("rehosted", active)
	await retry_team(active, "rehost_retry")
	var id := int(read_mark("loading_1_%d" % int(epochs[1])))
	var actor := (main.current_gate_room as GateRoom).players_container.get_node(str(id)) as PlayerController3D
	mark("pause_owner_timeout")
	require(await marked("owner_paused_timeout"))
	main.session.travel_player(actor, main.current_gate_room)
	var deadline := Time.get_ticks_msec() + 7000
	while not net._player_pauses.is_empty() and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(net._player_pauses.is_empty() and main.session._traveling.is_empty(), "An unresponsive handoff times out")
	require((main.current_gate_room as GateRoom).players_container.get_node_or_null(str(id)) == actor)
	require(not (main.current_site as GateRoom).players_container.has_node(str(id)), "Timeout never duplicates or teleports an operative")
	mark("resume_owner_timeout")
	require(await marked("owner_resumed_timeout"))
	await snapshot("timeout", active)
	mark("pause_owner_shutdown")
	require(await marked("owner_paused_shutdown"))
	main.session.travel_player(actor, main.current_gate_room)
	require(not net._player_pauses.is_empty(), "An owner handoff is pending at shutdown")
	net.disconnect_game()
	mark("resume_owner_shutdown")
	await lobby()
	for index in active:
		require(await marked("finished_%d" % index))
	await frames(20)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log := FileAccess.get_file_as_string(output_dir.path_join(file))
			require(not log.contains("ERROR:") and not log.contains("ObjectDB"), log)
	print("PASS session lifecycle: burst losses, survivor, HUD leave, rejoin, retry, shutdown and same-port rehost")


func join_phase(phase: String, initial: bool = false) -> void:
	if not initial:
		require(await marked("join_%s_%d" % [phase, slot]))
	require(net.join_game("127.0.0.1", port()) == OK)
	await worlds()
	mark("ready_%s_%d" % [phase, slot])
	await roster(phase)


func client_retry(phase: String) -> void:
	var previous := main.current_gate_room.get_instance_id()
	await worlds(previous)
	mark("ready_%s_%d" % [phase, slot])
	await roster(phase)


func suspend_owner_poll(phase: String) -> void:
	require(await marked("pause_owner_" + phase))
	multiplayer_poll = false
	mark("owner_paused_" + phase)
	require(await marked("resume_owner_" + phase))
	multiplayer_poll = true
	await frames(30)
	if phase == "timeout":
		var actor := (main.current_gate_room as GateRoom).players_container.get_node(str(net.local_peer_id)) as PlayerController3D
		require(net._paused_actors.is_empty() and actor.synchronizer.public_visibility,
			"A canceled transfer restores the original owner, including after its late acknowledgment")
	mark("owner_resumed_" + phase)


func run_client() -> void:
	remember_connections()
	net.player_name = "Lifecycle %d" % slot
	net.selected_class_id = CLASSES[(slot - 1) % CLASSES.size()]
	await join_phase("initial", true)
	require(await marked("burst"))
	if slot != 1:
		await lobby()
		mark("closed_burst_%d" % slot)
		await join_phase("rejoined")
	else:
		await roster("survivor")
		await roster("rejoined")
	await client_retry("retry")
	require(await marked("hud_leave"))
	mark("id_hud_%d" % slot, net.local_peer_id)
	paused = true
	(main.current_gate_room as GateRoom).hud._on_return_pressed()
	await lobby()
	mark("closed_hud_%d" % slot)
	await join_phase("hud_rejoined")
	# Cancel an already scheduled reconnect without starting another connection.
	net.auto_reconnect = slot == 1
	await lobby()
	if slot == 1:
		net.disconnect_game()
		await frames(150)
		require(not net.is_in_active_session(), "An explicit leave cancels a pending reconnect")
		net.auto_reconnect = false
	mark("server_gone_%d" % slot)
	await join_phase("rehosted")
	await client_retry("rehost_retry")
	if slot == 1:
		await suspend_owner_poll("timeout")
	await roster("timeout")
	if slot == 1:
		await suspend_owner_poll("shutdown")
	await lobby()
	mark("finished_%d" % slot)
