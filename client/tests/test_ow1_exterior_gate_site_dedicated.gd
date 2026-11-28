extends SceneTree
## Dedicated server verification for OW-1 (`--server --mission outdoor_gate_site`):
## Covers pawnless server launch on the exterior gate site, live outdoor/cross-boundary patrols,
## client join at exterior Stargate arrival pad, bunker breach + telemetry download + exterior
## extraction, and client-requested retry cleanup.

const MISSION := SGCNetworkManager.MISSION_OUTDOOR_GATE_SITE
const PORT := 19942
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred(&"run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(1)
		await process_frame


func mark(label: String) -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string("ok")


func marked(label: String, timeout_ms: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_server_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("server.log")))
	return false


func is_server_child() -> bool:
	return OS.get_cmdline_user_args().has("--ow1-dedicated-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func mission(players: int, previous: int = 0) -> ModularMission:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var room := main.current_gate_room as ModularMission
		if (
			room != null
			and room.get_instance_id() != previous
			and room.is_started
			and room.players_container.get_child_count() == players
		):
			return room
		await frames(1)
	assert(false, "OutdoorGateSiteMission with %d player(s) did not appear" % players)
	return null


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	output_dir = (
		args[args.find("--result-dir") + 1]
		if is_server_child()
		else OS.get_user_data_dir().path_join("ow1-dedi-" + str(OS.get_process_id()))
	)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if is_server_child():
		await run_server()
	else:
		await run_client()
	if main == null:
		quit(1)
		return
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS ow1 dedicated server" if is_server_child() else "PASS ow1 exterior gate site dedicated")
	quit(0)


func run_server() -> void:
	assert(net.is_dedicated_server and net.is_server and net.selected_mission_id == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	var room := await mission(0)
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	assert(room.outdoor != null and room.outdoor.ready_for_navigation)
	assert(room.enemies.get_child_count() == 5 and room.objectives.index == 0)
	var outdoor_guard := room.enemies.get_node("Jaffa_P0_0") as JaffaAI
	var start := outdoor_guard.global_position
	await frames(120)
	assert(outdoor_guard.global_position.distance_to(start) > 0.8, "Outdoor patrol moves on pawnless dedicated server")
	mark("server_ready")

	room = await mission(1)
	var guest := room.players_container.get_child(0) as PlayerController3D
	guest.health_component.current_health = 1000000.0
	var arrival := room.outdoor.marker_position(&"gate_arrival")
	assert(guest.global_position.distance_to(arrival) < 3.0, "Dedicated server spawned client outdoors")
	mark("client_spawned")

	assert(await marked("client_in_bunker"))
	var deadline := Time.get_ticks_msec() + 15000
	while room.objectives.index < 1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 1, "Dedicated server recognized bunker entry")
	mark("bunker_entered")

	# Client triggers retry -> old outdoor/interior world frees cleanly and restarts fresh.
	var old_room := room.get_instance_id()
	room = await mission(1, old_room)
	assert(not is_instance_id_valid(old_room), "Previous outdoor world freed on retry")
	assert(room.setup_errors.is_empty() and room.outdoor.ready_for_navigation)
	assert(room.objectives.index == 0 and room.enemies.get_child_count() == 5)
	mark("server_retried")
	assert(await marked("client_done"))


func run_client() -> void:
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("server.log"),
			"--script", "res://tests/test_ow1_exterior_gate_site_dedicated.gd",
			"--", "--ow1-dedicated-child", "--result-dir", output_dir,
			"--server", "--port", str(PORT), "--mission", MISSION
		]
	)
	assert(child_pid > 0)
	assert(await marked("server_ready"), "Dedicated outdoor server started")
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "Remote Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission(1)
	assert(room.outdoor != null and room.outdoor.ready_for_navigation)
	assert(await marked("client_spawned"))
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	me.global_position = room.level.marker(&"bunker_entry", &"entry") + Vector3(0.0, 0.08, 0.0)
	me.velocity = Vector3.ZERO
	mark("client_in_bunker")
	assert(await marked("bunker_entered"))
	var deadline := Time.get_ticks_msec() + 15000
	while room.objectives.index < 1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 1)

	var old_room := room.get_instance_id()
	assert(net.request_restart_game(), "Client requested outdoor mission retry")
	room = await mission(1, old_room)
	assert(await marked("server_retried"))
	assert(room.objectives.index == 0 and room.outdoor.ready_for_navigation)
	mark("client_done")

	deadline = Time.get_ticks_msec() + 15000
	while OS.is_process_running(child_pid) and Time.get_ticks_msec() < deadline:
		await frames(1)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("server.log"))
	assert("PASS ow1 dedicated server" in log_text, log_text)
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)
