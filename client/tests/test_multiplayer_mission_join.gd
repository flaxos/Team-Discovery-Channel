extends SceneTree
## Separate Godot processes exercise the production autoload, mission join and retry handshake.
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
	var file := FileAccess.open(output_dir.path_join(label), FileAccess.WRITE)
	file.store_string("ok")

func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)

func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var child: bool = args.has("--mission-join-child")
	var engine_args := OS.get_cmdline_args()
	var log_index: int = engine_args.find("--log-file")
	var log_dir: String = engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	output_dir = args[args.find("--result-dir") + 1] if child else log_dir.path_join("mission-join-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	if child:
		net.player_name = "Late Carter"
		net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	else:
		net.is_dedicated_server = true
		assert(net.host_game(19844) == OK)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	if child:
		assert(net.join_game("127.0.0.1", 19844) == OK)
		for _i: int in range(1200):
			await frames(1)
			if is_instance_valid(main.current_gate_room) and main.current_gate_room.get_node("Players").has_node(str(net.local_peer_id)):
				break
		assert(net.mission_started and is_instance_valid(main.current_gate_room), "Late join must enter the running mission")
		var room := main.current_gate_room as GateRoom
		var actor := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
		await frames(30)
		assert(actor.class_id == SGCNetworkManager.CLASS_CARTER_TECH and actor.health_component.max_health == 100, "Ready handshake must preserve the registered class")
		assert(room.wave_manager.completed_incursions == 3 and room.wave_manager.computer_upgraded, "Late join must receive objective snapshot")
		mark("joined")
		for _i: int in range(1200):
			await frames(1)
			if main.current_gate_room != room:
				break
		assert(main.current_gate_room != room, "Host retry must replace client world")
		await frames(60)
		assert(main.current_gate_room.get_node("Players").has_node(str(net.local_peer_id)), "Retry must respawn the client at canonical paths")
		mark("retried")
	else:
		var room := main.current_gate_room as GateRoom
		room.wave_manager.set_physics_process(false)
		room.wave_manager.defense_started = true
		room.wave_manager.completed_incursions = 3
		room.wave_manager.computer_upgraded = true
		child_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "--log-file", output_dir.path_join("client.log"), "--script", "res://tests/test_multiplayer_mission_join.gd", "--", "--mission-join-child", "--result-dir", output_dir])
		assert(child_pid > 0)
		for _i: int in range(1500):
			await frames(1)
			if FileAccess.file_exists(output_dir.path_join("joined")):
				break
		if not FileAccess.file_exists(output_dir.path_join("joined")):
			print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
		assert(FileAccess.file_exists(output_dir.path_join("joined")), "Late client must complete production mission handshake")
		assert(room.players_container.get_child_count() == 1, "Dedicated server spawns exactly one late operative")
		assert(net.request_restart_game())
		for _i: int in range(1500):
			await frames(1)
			if FileAccess.file_exists(output_dir.path_join("retried")):
				break
		assert(FileAccess.file_exists(output_dir.path_join("retried")), "Client must finish coordinated retry")
		await frames(30)
		var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
		assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)
	# Stop packet delivery before removing RPC targets; keep a valid local peer for teardown.
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	print("PASS production late join, registered class, objective snapshot and coordinated retry" if not child else "PASS late client")
	quit(0)
