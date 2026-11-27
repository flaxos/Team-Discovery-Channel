extends SceneTree
## Multi-process ENet EV-2 test:
## Part A: Real MainGameCoordinator host+client+late-joiner with MISSION_ALPHA_SITE (authored room_entered trigger),
##         verifying downed operative ignored, standing operative triggers HUD notice across peers,
##         late joiner receives snapshot without stale toast replay, and connected retry resets fired state.
## Part B: Synchronized ModularMission over live ENet testing initially_enabled=false objective skipping,
##         room_entered -> enable_objective insertion + sync_state bitmask replication + real client interact RPC
##         on newly enabled console + monotonic downgrade rejection.
const INFILTRATION_DEF := "res://resources/missions/goauld_infiltration.tres"
const PORT := 19961
var is_dedicated := false
var output_dir: String
var child_pid := -1
var buddy_pid := -1
var observer_pid := -1
var patched_def: MissionDefinition
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func port() -> int:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--port")
	return int(args[idx + 1]) if idx >= 0 and idx + 1 < args.size() else PORT


func dedicated() -> bool:
	return false


func _finalize() -> void:
	for pid: int in [child_pid, buddy_pid, observer_pid]:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)


func frames(count: int) -> void:
	for _i in range(count):
		OS.delay_msec(1)
		await process_frame


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--ev2-child")


func mark(name: String, val: Variant = "ok") -> void:
	FileAccess.open(output_dir.path_join(name), FileAccess.WRITE).store_string(str(val))


func marked(name: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(output_dir.path_join(name)):
			return true
		OS.delay_msec(2)
		await process_frame
	if not is_child():
		for log_name: String in ["client.log", "observer.log"]:
			if FileAccess.file_exists(output_dir.path_join(log_name)):
				print(FileAccess.get_file_as_string(output_dir.path_join(log_name)))
	return false


func read_mark(name: String) -> String:
	return FileAccess.get_file_as_string(output_dir.path_join(name)).strip_edges()


func park_all(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy in room.enemies.get_children():
		(enemy as JaffaAI).stand_down()
	for player: PlayerController3D in room.players_container.get_children():
		player.health_component.current_health = 1000000.0


func wait_mission(previous: int = 0) -> ModularMission:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var room := main.current_gate_room as ModularMission
		var has_local := (is_dedicated and not is_child()) or (room != null and room.players_container.has_node(str(net.local_peer_id)))
		if room != null and room.get_instance_id() != previous and room.is_started and has_local:
			assert(room.setup_errors.is_empty(), str(room.setup_errors))
			assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
			if not is_child():
				park_all(room)
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func patch_infiltration_for_ev2() -> void:
	patched_def = load(INFILTRATION_DEF) as MissionDefinition
	patched_def.patrols = []
	patched_def.reinforcements = []
	patched_def.objective_variants = []
	patched_def.airman_support = false
	patched_def.objectives[1].initially_enabled = false
	var enable_trig := MissionTrigger.new()
	enable_trig.id = &"antechamber_enables_records"
	enable_trig.condition = "room_entered"
	enable_trig.room = &"cmd_antechamber"
	enable_trig.action = "enable_objective"
	enable_trig.target_objective_id = &"download_records"
	enable_trig.notice = "COMMAND UPLINK ACTIVATED"
	patched_def.triggers.append(enable_trig)
	assert(patched_def.validate().is_empty(), str(patched_def.validate()))


func spawn_peer(role: String) -> int:
	var log_name := "client.log"
	if role == "observer":
		log_name = "observer.log"
	elif role == "buddy":
		log_name = "buddy.log"
	var args := PackedStringArray([
		"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output_dir.path_join(log_name),
		"--script", "res://tests/test_ev2_triggers_and_acoustics_multiplayer.gd",
		"--", "--ev2-child", "--port", str(port()), "--result-dir", output_dir
	])
	if role == "observer":
		args.append("--ev2-observer")
	elif role == "buddy":
		args.append("--ev2-buddy")
	return OS.create_process(OS.get_executable_path(), args)


func run() -> void:
	is_dedicated = dedicated()
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_index := engine_args.find("--log-file")
	var log_dir := engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	output_dir = args[args.find("--result-dir") + 1] if is_child() else log_dir.path_join("ev2-multi-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if is_child():
		await run_client()
	else:
		await run_host()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS EV-2 multiplayer child" if is_child() else "PASS EV-2 multiplayer (dedicated=%s)" % is_dedicated)
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	assert(net.host_game(port()) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_TAURI_ALPHA_SITE))
	child_pid = spawn_peer("client")
	assert(child_pid > 0)
	if is_dedicated:
		buddy_pid = spawn_peer("buddy")
		assert(buddy_pid > 0)
	var expected_peers := 2 if is_dedicated else 1
	var deadline := Time.get_ticks_msec() + 30000
	while net.multiplayer.get_peers().size() < expected_peers and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(net.multiplayer.get_peers().size() == expected_peers)
	net.request_start_game()
	var room := await wait_mission()
	assert(await marked("actor_peer_id"))
	var client_id := int(read_mark("actor_peer_id"))
	var actor := room.players_container.get_node(str(client_id)) as PlayerController3D
	assert(actor != null)
	assert(room.events.fired.is_empty())

	# Downed remote operative inside cmd_observation cannot fire observation_entry_notice.
	actor.health_component.bleedout_timer = 30.0
	actor.health_component.is_downed = true
	mark("move_to_obs_downed")
	assert(await marked("client_in_obs_downed"))
	var obs_pos := room.level.marker(&"cmd_observation", &"entry")
	deadline = Time.get_ticks_msec() + 30000
	while actor.global_position.distance_to(obs_pos) > 1.0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	await frames(4)
	assert(room.events.fired.is_empty(), "Downed remote operative does not fire room_entered")

	# Standing remote operative fires observation_entry_notice via real server detection.
	actor.health_component.is_downed = false
	actor.health_component.bleedout_timer = 0.0
	deadline = Time.get_ticks_msec() + 30000
	while not room.events.fired.has("observation_entry_notice") and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.events.fired.has("observation_entry_notice"))
	assert(await marked("client_saw_obs_notice"))

	if is_dedicated:
		mark("buddy_leave")
		deadline = Time.get_ticks_msec() + 30000
		while net.multiplayer.get_peers().size() > 1 and Time.get_ticks_msec() < deadline:
			await frames(1)

	# Late joiner receives fired room trigger without replaying toast.
	observer_pid = spawn_peer("observer")
	assert(observer_pid > 0 and await marked("observer_ok"))
	mark("observer_leave")
	deadline = Time.get_ticks_msec() + 30000
	while net.multiplayer.get_peers().size() > 1 and Time.get_ticks_msec() < deadline:
		await frames(1)

	# Connected retry clears fired room triggers.
	var prev_id := room.get_instance_id()
	assert(net.request_restart_game())
	room = await wait_mission(prev_id)
	assert(room.events.fired.is_empty(), "Retry clears fired room triggers")
	assert(await marked("client_retry_ok"))

	# Part B: Cleanly close Part A session and verify dynamic objective enabling + retry via MainGameCoordinator.
	mark("part_b_close_main")
	assert(await marked("part_b_client_closed"))
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(6)
	net.disconnect_game()

	patch_infiltration_for_ev2()
	net.is_dedicated_server = false
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.is_dedicated_server = is_dedicated
	assert(net.host_game(port() + 10) == OK)
	mark("part_b_listening")
	deadline = Time.get_ticks_msec() + 30000
	while net.multiplayer.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(not net.multiplayer.get_peers().is_empty())
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	await frames(6)
	net.request_start_game()
	var probe_room := await wait_mission()
	assert(await marked("part_b_client_id"))
	var probe_client_id := int(read_mark("part_b_client_id"))
	assert(probe_room.objectives.index == 0 and not probe_room.objectives.is_objective_enabled(1),
		"Part B init mismatch index=%d enabled=%s title=%s" % [probe_room.objectives.index, probe_room.objectives.enabled, probe_room.definition.title])
	if not is_dedicated:
		var host_op := probe_room.players_container.get_node("1") as PlayerController3D
		host_op.global_position = probe_room.level.marker(&"generator", &"entry") + Vector3(0, 0.05, 0)
	var probe_client := probe_room.players_container.get_node(str(probe_client_id)) as PlayerController3D
	var cp_pos := probe_room.level.marker(&"checkpoint", &"entry")
	assert(await marked("probe_client_ready"))
	deadline = Time.get_ticks_msec() + 30000
	while probe_client.global_position.distance_to(cp_pos) > 1.0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(probe_client.global_position.distance_to(cp_pos) <= 1.0)

	# Server earns generator sabotage, skipping dormant download_records.
	assert(probe_room.objectives.complete_interaction(probe_room.definition.objectives[0]))
	assert(probe_room.objectives.index == 2, "Dormant download_records skipped cleanly")
	assert(await marked("probe_skipped_ok"))

	# Client enters cmd_antechamber -> room_entered fires enable_objective(&"download_records").
	mark("enter_antechamber")
	deadline = Time.get_ticks_msec() + 30000
	while not probe_room.objectives.is_objective_enabled(1) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(probe_room.objectives.is_objective_enabled(1) and probe_room.objectives.index == 1)
	assert(await marked("probe_enabled_ok"))

	# Wait for client to complete download_records through real MissionInteractable RPC, then retry.
	deadline = Time.get_ticks_msec() + 30000
	while not probe_room.objectives.is_objective_completed(1) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(probe_room.objectives.is_objective_completed(1) and probe_room.objectives.index == 2)
	var probe_prev := probe_room.get_instance_id()
	assert(net.request_restart_game())
	probe_room = await wait_mission(probe_prev)
	assert(probe_room.objectives.index == 0 and not probe_room.objectives.is_objective_enabled(1) and probe_room.events.fired.is_empty(),
		"Connected retry resets dynamic objective and triggers")
	assert(await marked("probe_retry_ok"))
	mark("done")
	assert(await marked("client_exit"))
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(6)
	net.disconnect_game()
	var check_logs: Array[String] = ["client.log", "observer.log"]
	if is_dedicated:
		check_logs.append("buddy.log")
	for log_file: String in check_logs:
		var text := FileAccess.get_file_as_string(output_dir.path_join(log_file))
		assert(not text.contains("ERROR:") and not text.contains("ObjectDB"), text)


func run_client() -> void:
	var observer := OS.get_cmdline_user_args().has("--ev2-observer")
	var buddy := OS.get_cmdline_user_args().has("--ev2-buddy")
	net.player_name = "EV2 Observer" if observer else ("EV2 Buddy" if buddy else "EV2 Operative")
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", port()) == OK)
	var room := await wait_mission()
	if not observer and not buddy:
		mark("actor_peer_id", net.local_peer_id)
	if buddy:
		assert(await marked("buddy_leave"))
		return
	if observer:
		var obs_deadline := Time.get_ticks_msec() + 30000
		while not room.events.fired.has("observation_entry_notice") and Time.get_ticks_msec() < obs_deadline:
			await frames(1)
		assert(room.events.fired.has("observation_entry_notice"), "Late joiner receives fired trigger")
		assert(room.hud.squad_toast_label.text != room.definition.triggers[0].notice, "Late joiner does not replay notice toast")
		room.events.sync_fired(PackedStringArray())
		assert(room.events.fired.has("observation_entry_notice"), "Snapshot monotonicity")
		mark("observer_ok")
		assert(await marked("observer_leave"))
		return

	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	assert(await marked("move_to_obs_downed"))
	me.global_position = room.level.marker(&"cmd_observation", &"entry") + Vector3(0, 0.05, 0)
	await frames(4)
	mark("client_in_obs_downed")

	var deadline := Time.get_ticks_msec() + 30000
	while not room.events.fired.has("observation_entry_notice") and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.events.fired.has("observation_entry_notice"))
	assert(room.hud.squad_toast_label.text == room.definition.triggers[0].notice)
	mark("client_saw_obs_notice")

	var prev_id := room.get_instance_id()
	room = await wait_mission(prev_id)
	assert(room.events.fired.is_empty(), "Client retry resets fired triggers")
	mark("client_retry_ok")

	assert(await marked("part_b_close_main"))
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(6)
	net.disconnect_game()
	mark("part_b_client_closed")

	patch_infiltration_for_ev2()
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(await marked("part_b_listening"))
	assert(net.join_game("127.0.0.1", port() + 10) == OK)
	var probe_room := await wait_mission()
	mark("part_b_client_id", net.local_peer_id)
	var pm := probe_room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	pm.global_position = probe_room.level.marker(&"checkpoint", &"entry") + Vector3(0, 0.05, 0)
	await frames(4)
	var records_station := probe_room.level.get_node("cmd_command").find_child("MissionInteract", true, false) as MissionInteractable
	assert(records_station != null and not records_station.is_in_group("interactable") and not records_station.prompt.visible)
	mark("probe_client_ready")

	deadline = Time.get_ticks_msec() + 30000
	while probe_room.objectives.index != 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(probe_room.objectives.index == 2 and not probe_room.objectives.is_objective_enabled(1))
	assert(probe_room.hud.objective_label.text.begins_with("OBJECTIVE 2/2"))
	mark("probe_skipped_ok")

	assert(await marked("enter_antechamber"))
	pm.global_position = probe_room.level.marker(&"cmd_antechamber", &"entry") + Vector3(0, 0.05, 0)
	deadline = Time.get_ticks_msec() + 30000
	while not probe_room.objectives.is_objective_enabled(1) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(probe_room.objectives.index == 1 and probe_room.objectives.is_objective_enabled(1))
	assert(records_station.is_in_group("interactable") and records_station.prompt.visible)
	assert(probe_room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))
	assert(probe_room.hud.squad_toast_label.text == "COMMAND UPLINK ACTIVATED")

	# Reject client monotonic downgrade + client-authority enable attempt.
	probe_room.objectives.sync_state(0, 1, 0)
	assert(probe_room.objectives.is_objective_enabled(1) and probe_room.objectives.index == 1)
	assert(not probe_room.objectives.enable_objective(&"download_records"))
	mark("probe_enabled_ok")

	# Complete newly enabled objective via real interact RPC, then check retry reset.
	pm.global_position = records_station.global_position + Vector3(0, 0.05, 1.0)
	deadline = Time.get_ticks_msec() + 30000
	while probe_room.objectives.index == 1 and Time.get_ticks_msec() < deadline:
		records_station.interact(pm)
		await frames(5)
	assert(probe_room.objectives.index == 2 and probe_room.objectives.is_objective_completed(1))
	var probe_prev := probe_room.get_instance_id()
	probe_room = await wait_mission(probe_prev)
	assert(probe_room.objectives.index == 0 and not probe_room.objectives.is_objective_enabled(1) and probe_room.events.fired.is_empty(),
		"Client retry resets dynamic objective and triggers")
	mark("probe_retry_ok")

	assert(await marked("done"))
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(6)
	net.disconnect_game()
	mark("client_exit")
