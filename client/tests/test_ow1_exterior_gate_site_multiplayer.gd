extends SceneTree
## Two-process ENet listen-host + late-joining client verification for OW-1 (Exterior Gate Site):
## 1. Host starts MISSION_OUTDOOR_GATE_SITE, spawns outdoors at Stargate/DHD clearing, crosses doorway
##    into the modular bunker to complete Objective 1 (`breach_bunker`).
## 2. Client joins late mid-mission, spawns outdoors at `gate_arrival`, receives synchronized outdoor
##    navigation/door/objective state, enters bunker, completes telemetry download (`download_bunker_intel`).
## 3. Both standing operatives return outside to the exterior Stargate pad (`extract_gate`) ->
##    synchronized victory debrief on host and client!

const MISSION := SGCNetworkManager.MISSION_OUTDOOR_GATE_SITE
const PORT := 19941
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


func mark(label: String, text: String = "ok") -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string(text)


func marked(label: String, timeout_ms: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--ow1-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func mission() -> ModularMission:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var room := main.current_gate_room as ModularMission
		if room != null and room.is_started and room.players_container.has_node(str(net.local_peer_id)):
			return room
		await frames(1)
	assert(false, "OutdoorGateSiteMission did not start")
	return null


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0.0, 0.08, 0.0)
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
		else log_dir.path_join("ow1-multi-" + str(OS.get_process_id()))
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
	await frames(3)
	net.disconnect_game()
	print("PASS ow1 client" if is_child() else "PASS ow1 exterior gate site multiplayer")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	assert(room.outdoor != null and room.outdoor.ready_for_navigation)
	assert(room.stargate_mesh != null and room.dhd_console != null)
	assert(room.enemies.get_child_count() == 5)

	var me := room.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0
	var arrival := room.outdoor.marker_position(&"gate_arrival")
	assert(me.global_position.distance_to(arrival) < 2.5, "Host spawned outdoors at gate_arrival")

	# Host enters bunker through doorway -> advances objective 0 -> 1 before client joins.
	place(me, room.level.marker(&"bunker_entry", &"entry"))
	var deadline := Time.get_ticks_msec() + 15000
	while room.objectives.index < 1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 1, "Host entering bunker completes breach_bunker")

	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_ow1_exterior_gate_site_multiplayer.gd",
			"--", "--ow1-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)
	assert(await marked("client_joined"), "Late client joined outdoor mission")

	# Give client operative surplus health so live patrols don't down them during transfer checks.
	var guest: PlayerController3D = null
	deadline = Time.get_ticks_msec() + 15000
	while guest == null and Time.get_ticks_msec() < deadline:
		for child in room.players_container.get_children():
			var p := child as PlayerController3D
			if p != null and p.peer_id != 1:
				guest = p
				break
		await frames(1)
	assert(guest != null, "Server spawned late client operative")
	guest.health_component.current_health = 1000000.0
	assert(guest.global_position.distance_to(arrival) < 3.0, "Late client spawns outdoors at gate_arrival")
	mark("host_ready_for_download")

	assert(await marked("client_requested_download"), "Client triggered bunker command console")
	deadline = Time.get_ticks_msec() + 15000
	while room.objectives.index < 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 2, "Server accepted client bunker telemetry download")
	mark("download_confirmed")

	# Both operatives return outside to the exterior Stargate pad for extraction.
	place(me, arrival)
	assert(await marked("client_at_gate"), "Client moved back outside to Stargate pad")
	deadline = Time.get_ticks_msec() + 20000
	while room.mission_result < 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.is_complete() and room.mission_result == 1, "Both operatives extracting at exterior Stargate completes mission")
	mark("victory_confirmed")
	assert(await marked("client_done"), "Client confirmed synchronized victory debrief")

	deadline = Time.get_ticks_msec() + 15000
	while OS.is_process_running(child_pid) and Time.get_ticks_msec() < deadline:
		await frames(1)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert("PASS ow1 client" in log_text, log_text)
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Remote Teal'c"
	net.selected_class_id = SGCNetworkManager.CLASS_TEALC_JAFFA
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission()
	assert(room.outdoor != null and room.outdoor.ready_for_navigation, "Client OutdoorBoundary ready")
	assert(room.stargate_mesh != null and room.dhd_console != null, "Client has exterior Stargate & DHD")

	var deadline := Time.get_ticks_msec() + 15000
	while room.objectives.index < 1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 1, "Late client received objective snapshot (index == 1)")
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	var arrival := room.outdoor.marker_position(&"gate_arrival")
	assert(me.global_position.distance_to(arrival) < 3.0, "Late client positioned outdoors at gate_arrival")
	mark("client_joined")
	assert(await marked("host_ready_for_download"))

	# Client enters bunker and interacts with bunker_command main_console.
	var console_pos := room.objectives.position_of(room.objectives.current())
	place(me, console_pos + Vector3(0.0, 0.0, -1.2))
	await frames(25)
	var station := room.level.find_child("MissionInteract", true, false) as MissionInteractable
	assert(station != null, "Client sees bunker command MissionInteractable")
	station.interact(me)
	mark("client_requested_download")
	assert(await marked("download_confirmed"))

	deadline = Time.get_ticks_msec() + 15000
	while room.objectives.index < 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.objectives.index == 2, "Client synced to exterior extraction objective")

	# Return outside to exterior Stargate pad.
	place(me, arrival)
	await frames(20)
	mark("client_at_gate")
	assert(await marked("victory_confirmed"))

	deadline = Time.get_ticks_msec() + 15000
	while room.mission_result < 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.mission_result == 1 and room.hud.is_mission_ended, "Client received victory debrief")
	mark("client_done")
