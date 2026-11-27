extends SceneTree
## Two-process multiplayer test for Milestone CA-1: Campaign State Replication.
## Tests:
## 1. Host initializes CampaignManager with active campaign (Operation Ha'tak Strike).
## 2. Remote client peer connects via ENet.
## 3. Host broadcasts state snapshot upon client connection.
## 4. Client receives sync_campaign_state and asserts matching campaign ID and stage 0.
## 5. Host advances campaign to stage 1 -> client synchronizes stage 1 metadata.
## 6. Clean disconnection and session teardown.

const PORT := 19888
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var campaign_mgr: SGCCampaignManager


func _init() -> void:
	call_deferred("run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(1)
		await process_frame


func mark(label: String, text: String = "ok") -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string(text)


func marked(label: String, limit: int = 2400) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--campaign-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	campaign_mgr = root.get_node("CampaignManager") as SGCCampaignManager
	assert(net != null and campaign_mgr != null)

	var user_args := OS.get_cmdline_user_args()
	if is_child():
		output_dir = user_args[user_args.find("--dir") + 1]
		await run_child()
	else:
		output_dir = "build/test-results/campaign-multiplayer-%d" % OS.get_process_id()
		DirAccess.make_dir_recursive_absolute(output_dir)
		await run_parent()


func run_child() -> void:
	print("--- Running test_campaign_multiplayer [Client] ---")
	net.player_name = "ClientCarter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)

	# Wait for connection to host
	for _i in range(1200):
		if net.is_in_active_session():
			break
		await frames(1)
	assert(net.is_in_active_session(), "Client failed to connect to host")

	# Wait for campaign state to sync from host
	for _i in range(1200):
		if campaign_mgr.is_campaign_active:
			break
		await frames(1)
	assert(campaign_mgr.is_campaign_active, "Client received active campaign state")
	assert(campaign_mgr.active_campaign != null)
	assert(campaign_mgr.active_campaign.campaign_id == "operation_hatak_strike")
	assert(campaign_mgr.current_stage_index == 0)
	assert(campaign_mgr.get_current_mission_id() == SGCNetworkManager.MISSION_TRAVEL_INFILTRATION)

	mark("client_stage0_synced")

	# Wait for host to advance stage to 1
	for _i in range(1200):
		if campaign_mgr.current_stage_index == 1:
			break
		await frames(1)
	assert(campaign_mgr.current_stage_index == 1, "Client synchronized stage 1 advancement")
	assert(campaign_mgr.get_current_mission_id() == SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP)

	mark("client_stage1_synced")

	# Wait for test completion signal
	assert(await marked("test_complete", 600))
	net.disconnect_game()
	print("PASS: test_campaign_multiplayer [Client] completed successfully.")
	quit(0)


func run_parent() -> void:
	print("--- Running test_campaign_multiplayer [Host] ---")
	campaign_mgr.reset_campaign()
	net.player_name = "HostONeill"
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON

	assert(net.host_game(PORT) == OK)
	campaign_mgr.start_campaign()
	assert(campaign_mgr.is_campaign_active)
	assert(campaign_mgr.current_stage_index == 0)

	# Spawn child client process
	var engine_path := OS.get_executable_path()
	var args: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output_dir.path_join("client.log"),
		"--script", "res://tests/test_campaign_multiplayer.gd",
		"--",
		"--campaign-child",
		"--dir", output_dir
	]
	child_pid = OS.create_process(engine_path, args)
	assert(child_pid > 0, "Child client process spawned")

	# Wait for client to connect and sync stage 0
	assert(await marked("client_stage0_synced", 1800), "Client synced stage 0")

	# Advance host to stage 1
	assert(campaign_mgr.advance_to_next_stage())
	assert(campaign_mgr.current_stage_index == 1)

	# Wait for client to sync stage 1
	assert(await marked("client_stage1_synced", 1800), "Client synced stage 1")

	mark("test_complete")
	await frames(15)

	_finalize()
	campaign_mgr.reset_campaign()
	net.disconnect_game()

	print("PASS: test_campaign_multiplayer [Host] completed successfully.")
	await preload("res://tests/support/finish.gd").success(self)
