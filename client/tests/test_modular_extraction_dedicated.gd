extends SceneTree
## Dedicated server for the modular extraction mission. The child process starts through the
## production launch flags (`--server --mission modular_extraction_uat`); this process is an
## ordinary client. Covers the server world without a host operative, the client's spawn,
## replicated patrols, a shared objective, a retry asked for by the client, and the client's
## return to the lobby when the server exits.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const PORT := 19875
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(1)
		await process_frame


func mark(label: String) -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string("ok")


func marked(label: String, limit: int = 3000) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_server_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("server.log")))
	return false


func is_server_child() -> bool:
	return OS.get_cmdline_user_args().has("--dedicated-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


## The current mission world once it has started, with `players` operatives in it.
func mission(players: int, previous: int = 0) -> ModularMission:
	for _i: int in range(3000):
		var room := main.current_gate_room as ModularMission
		if (
			room != null
			and room.get_instance_id() != previous
			and room.is_started
			and room.players_container.get_child_count() == players
		):
			return room
		await frames(1)
	assert(false, "Mission world with %d operative(s) did not appear" % players)
	return null


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	output_dir = (
		args[args.find("--result-dir") + 1]
		if is_server_child()
		else OS.get_user_data_dir().path_join("dedicated-" + str(OS.get_process_id()))
	)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if is_server_child():
		await run_server()
	else:
		await run_client()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	print(
		"PASS dedicated server child"
		if is_server_child()
		else "PASS dedicated modular extraction: server launch, client spawn, patrols, objective and client retry"
	)
	quit(0)


func run_server() -> void:
	# The autoload has already read the launch flags and opened the port.
	assert(net.is_dedicated_server and net.is_server and net.selected_mission_id == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	var room := await mission(0)
	assert(main.current_lobby == null, "A dedicated server never shows the lobby")
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	assert(room.enemies.get_child_count() == 5 and room.objectives.index == 0)
	var lead := room.enemies.get_node("Jaffa_P0_0") as JaffaAI
	var start := lead.global_position
	await frames(120)
	assert(lead.global_position.distance_to(start) > 1.0, "Patrols run with no operative present")
	assert(room.mission_result == -1, "An empty server is not a squad wipe")
	mark("server_ready")

	room = await mission(1)
	var guest := room.players_container.get_child(0) as PlayerController3D
	guest.health_component.current_health = 1000000.0
	var entry := room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker)
	assert(guest.global_position.distance_to(entry) < 3.0, "The client spawns on the entry markers")
	assert(guest.get_multiplayer_authority() != 1 and guest.health_component.get_multiplayer_authority() == 1)
	mark("client_spawned")
	assert(await marked("client_reached"), "The client reports reaching the command room")
	for _i: int in range(600):
		await frames(1)
		if room.objectives.index == 1:
			break
	assert(room.objectives.index == 1, "The server completes the objective from the client's position")
	mark("objective_done")

	# The client asks for the retry: there is no host operative to press the button.
	var old_room := room.get_instance_id()
	room = await mission(1, old_room)
	assert(not is_instance_id_valid(old_room), "The old world is freed")
	assert(room.objectives.index == 0 and room.mission_result == -1)
	assert(room.enemies.get_child_count() == 5 and room.setup_errors.is_empty())
	assert(root.find_children("Jaffa_P*", "JaffaAI", true, false).size() == 5, "No stale Jaffa")
	mark("server_retried")
	assert(await marked("client_done"), "The client finishes its checks")


func run_client() -> void:
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("server.log"),
			"--script", "res://tests/test_modular_extraction_dedicated.gd",
			"--", "--dedicated-child", "--result-dir", output_dir,
			"--server", "--port", str(PORT), "--mission", MISSION
		]
	)
	assert(child_pid > 0)
	assert(await marked("server_ready"), "Dedicated server must start the mission on its own")
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "Remote Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission(1)
	assert(net.selected_mission_id == MISSION and not net.is_server)
	assert(net.peers[1]["class_id"] == "dedicated_server")
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	for _i: int in range(2400):
		await frames(1)
		if room.enemies.get_child_count() == 5:
			break
	assert(room.enemies.get_child_count() == 5, "Server patrols replicate to the client")
	assert(await marked("client_spawned"))
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/3"))
	assert(room.hud.wave_label.text == room.definition.title)
	assert(room.hud.enemies_label.text == "HOSTILE PATROLS ACTIVE: 5 JAFFA")
	var seen := {}
	for enemy in room.enemies.get_children():
		seen[enemy] = (enemy as JaffaAI).global_position
	var moved := false
	for _i: int in range(900):
		for mirror: JaffaAI in seen:
			moved = moved or mirror.global_position.distance_to(seen[mirror]) > 0.5
		if moved:
			break
		await frames(1)
	assert(moved, "Replicas follow the server's Jaffa")

	me.global_position = room.level.marker(&"command", &"entry") + Vector3(0, 0.05, 0)
	me.velocity = Vector3.ZERO
	mark("client_reached")
	assert(await marked("objective_done"))
	for _i: int in range(600):
		await frames(1)
		if room.objectives.index == 1:
			break
	assert(room.objectives.index == 1 and room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))

	var old_room := room.get_instance_id()
	assert(net.request_restart_game(), "A client may ask a dedicated server to retry")
	room = await mission(1, old_room)
	assert(await marked("server_retried"))
	for _i: int in range(2400):
		await frames(1)
		if room.enemies.get_child_count() == 5:
			break
	await frames(30)
	assert(room.objectives.index == 0 and room.mission_result == -1)
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/3") and not room.hud.is_mission_ended)
	assert(room.enemies.get_child_count() == 5 and room.players_container.get_child_count() == 1)
	mark("client_done")
	for _i: int in range(1200):
		if not OS.is_process_running(child_pid):
			break
		await frames(1)
	assert(not OS.is_process_running(child_pid), "The server process ends by itself")
	# Losing the server returns this client to the lobby; it does not keep a dead world running.
	for _i: int in range(600):
		if main.current_lobby != null:
			break
		await frames(1)
	assert(main.current_lobby != null and not is_instance_valid(main.current_gate_room))
	assert(not net.is_in_active_session())
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("server.log"))
	assert("PASS dedicated server child" in log_text, log_text)
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)
