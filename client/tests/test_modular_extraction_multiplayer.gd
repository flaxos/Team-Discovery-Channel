extends SceneTree
## Two Godot processes run the production autoload, lobby start and mission host: a listen
## host and a client that joins after the first objective. Jaffa stay live; both operatives
## get surplus health so this suite is about shared mission state, not survival.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const PORT := 19874
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


func marked(label: String, limit: int = 2400) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--extraction-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func mission() -> ModularMission:
	for _i: int in range(2400):
		var room := main.current_gate_room as ModularMission
		if room != null and room.is_started and room.players_container.has_node(str(net.local_peer_id)):
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


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
		else log_dir.path_join("extraction-" + str(OS.get_process_id()))
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
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	print("PASS late client" if is_child() else "PASS two-peer modular extraction: late join snapshot, console authority, shared result and retry")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	assert(room.setup_errors.is_empty() and room.enemies.get_child_count() == 5)
	var events: Array[int] = []
	room.objectives.objective_changed.connect(func(index: int) -> void: events.append(index))
	var me := room.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0
	place(me, room.level.marker(&"command", &"entry"))
	await frames(10)
	assert(room.objectives.index == 1, "Host completes the first objective before anyone joins")
	# Hostiles hold still while the client connects: health RPCs sent before a replica
	# exists are dropped with an engine error, which this suite treats as a failure.
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(false)
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_modular_extraction_multiplayer.gd",
			"--", "--extraction-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)
	for _i: int in range(2400):
		await frames(1)
		if room.players_container.get_child_count() == 2:
			break
	assert(room.players_container.get_child_count() == 2, "Late operative spawned by the host")
	var guest := room.players_container.get_child(1) as PlayerController3D
	if guest == me:
		guest = room.players_container.get_child(0) as PlayerController3D
	guest.health_component.current_health = 1000000.0
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(true)
	var entry := room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker)
	assert(guest.global_position.distance_to(entry) < 3.0, "Late operative uses the entry markers")
	assert(await marked("joined"), "Client must receive the objective snapshot")
	assert(await marked("console"), "Client console use must reach the host")
	assert(room.objectives.index == 2 and events == [1, 2], "One completion per objective")
	assert(await marked("at_exit"))
	await frames(60)
	assert(room.objectives.inside(guest, room.definition.objectives[2]))
	assert(room.mission_result == -1, "Extraction waits for the standing host")
	place(me, entry)
	for _i: int in range(600):
		await frames(1)
		if room.mission_result >= 0:
			break
	assert(room.mission_result == 1 and events == [1, 2, 3])
	assert(await marked("result"), "Client must show the same result")
	var old_room := room.get_instance_id()
	assert(net.request_restart_game())
	assert(await marked("retried"), "Client must finish the coordinated retry")
	room = await mission()
	assert(room.get_instance_id() != old_room and room.objectives.index == 0)
	for _i: int in range(600):
		await frames(1)
		if room.players_container.get_child_count() == 2:
			break
	assert(room.players_container.get_child_count() == 2 and room.enemies.get_child_count() == 5)
	await frames(30)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Late Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission()
	assert(net.selected_mission_id == MISSION and not net.is_server)
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	for _i: int in range(2400):
		await frames(1)
		if room.players_container.get_child_count() == 2 and room.enemies.get_child_count() == 5:
			break
	await frames(60)
	assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
	assert(room.objectives.index == 1, "Late join receives the completed first objective")
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))
	assert(room.mission_result == -1 and room.players_container.get_child_count() == 2)
	assert(room.enemies.get_child_count() == 5, "Host Jaffa replicate to the late client")
	var mirror := room.enemies.get_node("Jaffa_P0_0") as JaffaAI
	assert(mirror.get_multiplayer_authority() == 1 and mirror.patrol_points.is_empty())
	var seen := mirror.global_position
	var console := (
		room.level.get_node("command").find_child("MissionInteract", true, false)
		as MissionInteractable
	)
	# Out of reach, and a local attempt to skip the server: neither completes anything.
	console.interact(me)
	console._use(me)
	assert(not room.objectives.complete_interaction(room.definition.objectives[1]))
	await frames(60)
	assert(room.objectives.index == 1, "Server refuses a console request from the entry")
	assert(mirror.global_position.distance_to(seen) > 0.5, "Replica follows the host patrol")
	mark("joined")
	place(me, console.global_position + Vector3(0, 0, 1.5))
	for _i: int in range(600):
		await frames(20)
		if room.objectives.index >= 2:
			break
		console.interact(me)
	assert(room.objectives.index == 2, "In reach, the server accepts the console request")
	console.interact(me)
	await frames(30)
	assert(room.objectives.index == 2 and room.hud.objective_label.text.begins_with("OBJECTIVE 3/3"))
	mark("console")
	place(me, room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker))
	await frames(30)
	mark("at_exit")
	for _i: int in range(2400):
		await frames(1)
		if room.mission_result >= 0:
			break
	assert(room.mission_result == 1 and room.objectives.is_complete())
	assert(room.hud.is_mission_ended and room.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	mark("result")
	var old_room := room.get_instance_id()
	for _i: int in range(2400):
		await frames(1)
		if is_instance_valid(main.current_gate_room) and main.current_gate_room.get_instance_id() != old_room:
			break
	room = await mission()
	assert(room.get_instance_id() != old_room, "Host retry replaces the client world")
	for _i: int in range(2400):
		await frames(1)
		if room.enemies.get_child_count() == 5 and room.players_container.get_child_count() == 2:
			break
	await frames(30)
	assert(room.objectives.index == 0 and room.mission_result == -1)
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/3") and not room.hud.is_mission_ended)
	assert(room.enemies.get_child_count() == 5 and room.players_container.get_child_count() == 2)
	mark("retried")
	await frames(60)
