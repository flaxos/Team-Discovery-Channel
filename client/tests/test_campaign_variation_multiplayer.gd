extends SceneTree
## Multi-process ENet verification for Milestone CA-2:
## Host/dedicated server chooses campaign difficulty tier, deterministic run seed & mutators,
## connected client & late-join observer synchronize identical stage variants and objective counts,
## clients cannot mutate difficulty/seed/mutators, and retry + stage advancement stay synchronized.

const CAMPAIGN_MISSION := SGCNetworkManager.MISSION_CAMPAIGN_OPERATION
const TEST_SEED := 733101
const TEST_MODIFIERS := ["shielded_vanguard", "rapid_response"]

var child_pid: int = -1
var observer_pid: int = -1
var output_dir: String = ""
var dedicated_host: bool = false
var net: SGCNetworkManager
var campaign_mgr: SGCCampaignManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func dedicated() -> bool:
	return false


func port_number() -> int:
	return 19896 if dedicated() else 19895


func _finalize() -> void:
	for pid: int in [child_pid, observer_pid]:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(4)
		await physics_frame


func role() -> String:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--role")
	return args[idx + 1] if idx >= 0 and idx + 1 < args.size() else "host"


func mark(label: String, text: String = "ok") -> void:
	var destination := output_dir.path_join(label)
	var staged := destination + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()
	assert(DirAccess.rename_absolute(staged, destination) == OK)


func marked(label: String, limit: int = 3000) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if role() == "host":
		for log_name: String in ["client.log", "observer.log"]:
			if FileAccess.file_exists(output_dir.path_join(log_name)):
				print("=== %s ===" % log_name)
				print(FileAccess.get_file_as_string(output_dir.path_join(log_name)))
	return false


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_campaign_variation_multiplayer.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)


func wait_worlds(expected_players: int = -1, previous_home: int = 0) -> Array:
	for _i: int in range(3000):
		var home := main.current_gate_room as GateRoom
		var site := main.current_site as ModularMission
		var has_local := dedicated_host or (home != null and home.players_container.has_node(str(net.local_peer_id)))
		var count_ok := expected_players < 0 or (home != null and home.players_container.get_child_count() == expected_players)
		if home != null and site != null and home.get_instance_id() != previous_home and site.is_started and has_local and count_ok:
			return [home, site]
		await frames(1)
	assert(false, "Two-world campaign failed to load")
	return []


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_idx := engine_args.find("--log-file")
	var log_dir := engine_args[log_idx + 1].get_base_dir() if log_idx >= 0 else OS.get_user_data_dir()
	var r := role()
	dedicated_host = dedicated() and r == "host"
	net = root.get_node("NetworkManager") as SGCNetworkManager
	campaign_mgr = root.get_node("CampaignManager") as SGCCampaignManager
	output_dir = args[args.find("--result-dir") + 1] if r != "host" else log_dir.path_join("ca2-mp-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)

	if r == "host":
		await run_host()
	elif r == "client":
		await run_client()
	else:
		await run_observer()

	_finalize()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)
	if r == "host":
		campaign_mgr.reset_campaign()
		campaign_mgr.clear_records()
	net.disconnect_game(true)
	print("PASS ca2 variation %s (dedicated=%s)" % [r, str(dedicated_host)])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	campaign_mgr.reset_campaign()
	net.is_dedicated_server = dedicated_host
	assert(net.set_mission(CAMPAIGN_MISSION))
	assert(net.set_mission_difficulty(SGCNetworkManager.DIFFICULTY_HARD))
	assert(net.set_run_variation(TEST_SEED, TEST_MODIFIERS))
	campaign_mgr.start_campaign(null, SGCNetworkManager.DIFFICULTY_HARD, TEST_SEED, TEST_MODIFIERS)
	assert(net.host_game(port_number()) == OK)

	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if not dedicated_host:
		net.request_start_game()

	var stage0_worlds := await wait_worlds(0 if dedicated_host else 1)
	var home: GateRoom = stage0_worlds[0] as GateRoom
	var site: ModularMission = stage0_worlds[1] as ModularMission
	assert(site.active_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(site.active_run_seed == TEST_SEED)
	var expected_obj_count: int = site.definition.objectives.size()
	mark("host_stage0_ready", str(expected_obj_count))

	child_pid = _spawn_peer("client", "client.log")
	assert(child_pid > 0)
	assert(await marked("client_stage0_ok"), "Main client verified Stage 0 variation & authority guards")

	observer_pid = _spawn_peer("observer", "observer.log")
	assert(observer_pid > 0)
	assert(await marked("observer_verified"), "Late-join observer synced CA-2 tier/seed/modifiers")
	mark("observer_can_leave")

	var old_home_id: int = home.get_instance_id()
	assert(await marked("client_ready_retry"))
	if not dedicated_host:
		assert(net.request_restart_game())
	var retry_worlds := await wait_worlds(1 if dedicated_host else 2, old_home_id)
	var retry_home: GateRoom = retry_worlds[0] as GateRoom
	var retry_site: ModularMission = retry_worlds[1] as ModularMission
	assert(retry_site.active_run_seed == TEST_SEED)
	assert(retry_site.definition.objectives.size() == expected_obj_count)
	mark("host_retry_ok")
	assert(await marked("client_retry_ok"), "Client verified Stage 0 retry before Stage 1 advance")

	# Advance campaign to Stage 1 (Mothership Boarding) and verify across retry transition
	old_home_id = retry_home.get_instance_id()
	campaign_mgr.record_stage_completion({"kill_count": 9, "duration_seconds": 95, "stealth": "UNDETECTED", "lost_count": 0}, true, {})
	assert(campaign_mgr.advance_to_next_stage())
	if dedicated_host:
		mark("host_advance_ready")
	else:
		assert(net.request_restart_game())

	var stage1_worlds := await wait_worlds(1 if dedicated_host else 2, old_home_id)
	var stage1_site: ModularMission = stage1_worlds[1] as ModularMission
	assert(stage1_site.active_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(stage1_site.active_run_seed == TEST_SEED)
	mark("host_stage1_ok", str(stage1_site.definition.objectives.size()))

	assert(await marked("client_done"))


func run_client() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "CA2 Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", port_number()) == OK)

	assert(await marked("host_stage0_ready"))
	var expected_obj_count: int = FileAccess.get_file_as_string(output_dir.path_join("host_stage0_ready")).to_int()
	var worlds0 := await wait_worlds()
	var home0: GateRoom = worlds0[0] as GateRoom
	var site0: ModularMission = worlds0[1] as ModularMission

	assert(campaign_mgr.is_campaign_active)
	assert(campaign_mgr.campaign_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(campaign_mgr.run_seed == TEST_SEED)
	assert(campaign_mgr.active_modifiers == TEST_MODIFIERS)
	assert(site0.active_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(site0.active_run_seed == TEST_SEED)
	assert(site0.definition.objectives.size() == expected_obj_count, "Client objective count must match host variant")

	var terminal := home0.find_child("SGCBriefingTerminal", true, false) as SGCBriefingTerminal
	assert(terminal != null and "HARD" in terminal.screen_label.text and str(TEST_SEED) in terminal.screen_label.text)

	# Client cannot mutate host difficulty, seed, or modifiers
	assert(not net.set_mission_difficulty(SGCNetworkManager.DIFFICULTY_EASY))
	assert(not campaign_mgr.set_campaign_difficulty(MissionDifficulty.TIER_EASY))
	assert(not campaign_mgr.set_run_seed(999999))
	assert(not campaign_mgr.set_campaign_modifiers([]))
	assert(campaign_mgr.campaign_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(campaign_mgr.run_seed == TEST_SEED)
	assert(campaign_mgr.active_modifiers == TEST_MODIFIERS)

	mark("client_stage0_ok")
	assert(await marked("observer_verified"))

	var old_home_id: int = home0.get_instance_id()
	mark("client_ready_retry")
	if dedicated():
		# Give dedicated host one beat to observe client_ready_retry before client requests restart
		await frames(10)
		assert(net.request_restart_game())
	var retry_worlds := await wait_worlds(-1, old_home_id)
	var retry_home: GateRoom = retry_worlds[0] as GateRoom
	var retry_site: ModularMission = retry_worlds[1] as ModularMission
	assert(await marked("host_retry_ok"))
	assert(retry_site.active_run_seed == TEST_SEED)
	assert(retry_site.definition.objectives.size() == expected_obj_count)
	mark("client_retry_ok")

	old_home_id = retry_home.get_instance_id()
	if dedicated():
		assert(await marked("host_advance_ready"))
		assert(net.request_restart_game())
	assert(await marked("host_stage1_ok"))
	var stage1_objs: int = FileAccess.get_file_as_string(output_dir.path_join("host_stage1_ok")).to_int()
	var stage1_worlds := await wait_worlds(-1, old_home_id)
	var stage1_site: ModularMission = stage1_worlds[1] as ModularMission
	assert(campaign_mgr.current_stage_index == 1)
	assert(stage1_site.active_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(stage1_site.definition.objectives.size() == stage1_objs)

	mark("client_done")


func run_observer() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "CA2 LateJoiner"
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	assert(net.join_game("127.0.0.1", port_number()) == OK)

	var expected_obj_count: int = FileAccess.get_file_as_string(output_dir.path_join("host_stage0_ready")).to_int()
	var obs_worlds := await wait_worlds()
	var obs_site: ModularMission = obs_worlds[1] as ModularMission
	assert(campaign_mgr.is_campaign_active)
	assert(campaign_mgr.campaign_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(campaign_mgr.run_seed == TEST_SEED)
	assert(campaign_mgr.active_modifiers == TEST_MODIFIERS)
	assert(obs_site.active_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(obs_site.definition.objectives.size() == expected_obj_count)

	mark("observer_verified")
	assert(await marked("observer_can_leave"))
