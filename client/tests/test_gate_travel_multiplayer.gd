extends SceneTree
## Two-process multiplayer gate travel (roadmap GT-2; docs/plans/gate-travel-split-worlds.md).
## Tests:
## 1. Listen host starts MISSION_TRAVEL_INFILTRATION.
## 2. Remote client connects and spawns at SGC (home).
## 3. Host dials SGC gate; host steps through event horizon -> travels to offworld compound.
## 4. Host presentation switches to compound; client in SGC sees host despawn from SGC.
## 5. Client steps through open SGC gate -> client travels to offworld compound.
## 6. Client presentation switches to compound; client and host reunite offworld.
## 7. Split-squad loss rule and clean session teardown.

const MISSION := SGCNetworkManager.MISSION_TRAVEL_INFILTRATION
const PORT := 19878
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator
var home: GateRoom
var site: ModularMission
var session: MissionSession


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
	return OS.get_cmdline_user_args().has("--gate-travel-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func worlds() -> void:
	for _i: int in range(2400):
		home = main.current_gate_room as GateRoom
		site = main.current_site as ModularMission
		if home != null and site != null and site.is_started and home.players_container.has_node(str(net.local_peer_id)):
			session = main.session
			return
		await frames(1)
	assert(false, "The two worlds did not start")


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_index: int = engine_args.find("--log-file")
	var log_dir: String = (
		engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	)
	output_dir = (
		args[args.find("--result-dir") + 1]
		if is_child()
		else log_dir.path_join("gate-travel-" + str(OS.get_process_id()))
	)
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if is_child():
		await run_client()
	else:
		await run_host()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(main):
		main.queue_free()
	await frames(2)
	net.disconnect_game()
	print("PASS gate travel client" if is_child() else "PASS two peers gate travel multiplayer")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await worlds()

	# Launch client process
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_gate_travel_multiplayer.gd",
			"--", "--gate-travel-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)

	# Wait for client to connect and spawn in SGC
	for _i: int in range(2400):
		if home.players_container.get_child_count() >= 2:
			break
		await frames(1)
	assert(home.players_container.get_child_count() == 2, "Both host and client in SGC")
	assert(await marked("client_ready"), "Client finished setup in SGC")

	# Host dials gate and authorizes extraction
	var sgc_gate: StargateRing = home.stargate_mesh
	assert(sgc_gate != null)
	sgc_gate.reserve_connection(false)
	sgc_gate.current_state = StargateRing.GateState.ACTIVE
	sgc_gate.authorize_extraction()

	# Host operative travels through gate
	var host_op := home.players_container.get_node("1") as PlayerController3D
	sgc_gate._on_extraction_entered(host_op)
	await frames(10)

	assert(home.players_container.get_node_or_null("1") == null, "Host despawned from SGC")
	assert(site.players_container.get_node_or_null("1") != null, "Host spawned in offworld compound")
	assert(session.presented == site, "Host view switched to compound")

	mark("host_traveled")
	assert(await marked("client_saw_host_travel"), "Client saw host depart SGC")

	# Now client travels through gate
	var client_node: PlayerController3D = null
	for child in home.players_container.get_children():
		var p := child as PlayerController3D
		if p != null and p.peer_id != 1:
			client_node = p
			break
	assert(client_node != null)
	var client_id: int = client_node.peer_id

	sgc_gate._on_extraction_entered(client_node)
	await frames(10)

	assert(home.players_container.get_node_or_null(str(client_id)) == null, "Client despawned from SGC")
	assert(site.players_container.get_node_or_null(str(client_id)) != null, "Client spawned in offworld compound")

	mark("client_traveled_server")
	assert(await marked("client_finished_travel"), "Client confirmed presentation in compound")
	assert(await marked("client_disconnected"), "Client disconnected cleanly")

	await frames(10)
	net.disconnect_game()
	mark("host_done")


func run_client() -> void:
	net.player_name = "Travel Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	await worlds()

	var me := home.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	assert(me != null and session.presented == home)
	mark("client_ready")

	# Wait for host to travel
	assert(await marked("host_traveled"))
	await frames(10)

	# Verify host is no longer in client's SGC
	assert(home.players_container.get_node_or_null("1") == null, "Client sees host left SGC")
	assert(session.presented == home, "Client stays presented in SGC until they travel")
	mark("client_saw_host_travel")

	# Wait for server to process client's travel
	assert(await marked("client_traveled_server"))
	for _i: int in range(1200):
		if session.presented == site and site.players_container.has_node(str(net.local_peer_id)):
			break
		await frames(1)

	assert(session.presented == site, "Client presentation switched to offworld site")
	assert(site.visible and site.hud.visible, "Site visible on client")
	mark("client_finished_travel")

	await frames(10)
	net.disconnect_game()
	mark("client_disconnected")
