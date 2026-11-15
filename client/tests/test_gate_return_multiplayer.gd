extends SceneTree
## Two-process multiplayer return gate travel, SGC debrief, and two-world retry (roadmap GT-3).
## Tests:
## 1. Listen host and client launch MISSION_TRAVEL_INFILTRATION and travel to the offworld site.
## 2. Combat & objectives completion opens the site's Stargate for both host and client.
## 3. Host steps through site Stargate -> arrives on SGC ramp; client remains offworld.
## 4. Client goes down offworld -> D-017 success triggers, closing gates and showing SGC debrief
##    on BOTH host and client with real kills, 3/3 objectives, and client callsign listed as lost.
## 5. Host triggers retry -> both host and client cleanly reload fresh SGC and offworld site.

const MISSION := SGCNetworkManager.MISSION_TRAVEL_INFILTRATION
const PORT := 19879
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
	return OS.get_cmdline_user_args().has("--gate-return-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func worlds(previous_home_id: int = 0) -> void:
	for _i: int in range(2400):
		home = main.current_gate_room as GateRoom
		site = main.current_site as ModularMission
		if (
			home != null
			and home.get_instance_id() != previous_home_id
			and site != null
			and site.is_started
			and home.players_container.has_node(str(net.local_peer_id))
		):
			session = main.session
			return
		await frames(1)
	assert(false, "The two worlds did not start")


func console_spot(room_id: StringName) -> Vector3:
	var console := site.level.get_node(str(room_id)).find_child("MissionInteract", true, false) as Node3D
	assert(console != null)
	var best := Vector3.INF
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var spot := NavigationServer3D.map_get_closest_point(site.level.navigation_map, console.global_position + offset)
		if spot.distance_to(console.global_position) < MissionInteractable.REACH - 0.3:
			if best == Vector3.INF or spot.distance_to(console.global_position) < best.distance_to(console.global_position):
				best = spot
	assert(best != Vector3.INF)
	return best


func use_console(room_id: StringName, actor: PlayerController3D) -> void:
	var console := site.level.get_node(str(room_id)).find_child("MissionInteract", true, false) as MissionInteractable
	var before := site.objectives.index
	for _i in range(40):
		console.interact(actor)
		await frames(2)
		if site.objectives.index > before:
			return
	assert(false, "Console %s did not complete" % room_id)


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
		else log_dir.path_join("gate-return-" + str(OS.get_process_id()))
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
	print("PASS gate return client" if is_child() else "PASS two peers gate return, debrief and retry multiplayer")
	quit(0)


func run_host() -> void:
	net.player_name = "Host O'Neill"
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await worlds()

	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_gate_return_multiplayer.gd",
			"--", "--gate-return-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)

	for _i: int in range(2400):
		if home.players_container.get_child_count() >= 2:
			break
		await frames(1)
	assert(home.players_container.get_child_count() == 2)
	assert(await marked("client_ready"))

	# Open SGC gate and travel both operatives offworld
	var sgc_gate: StargateRing = home.stargate_mesh
	sgc_gate.kawoosh_duration_s = 0.08
	sgc_gate.reserve_connection(false)
	sgc_gate.current_state = StargateRing.GateState.ACTIVE
	sgc_gate.authorize_extraction()

	var host_home := home.players_container.get_node("1") as PlayerController3D
	var client_home: PlayerController3D = null
	for child in home.players_container.get_children():
		var p := child as PlayerController3D
		if p != null and p.peer_id != 1:
			client_home = p
			break
	assert(client_home != null)
	var client_id := client_home.peer_id

	sgc_gate._on_extraction_entered(host_home)
	await frames(10)
	mark("host_traveled")
	assert(await marked("client_saw_host_travel"))
	sgc_gate._on_extraction_entered(client_home)
	await frames(10)

	var host_site := site.players_container.get_node_or_null("1") as PlayerController3D
	var client_site := site.players_container.get_node_or_null(str(client_id)) as PlayerController3D
	assert(host_site != null and client_site != null)
	mark("both_offworld")
	assert(await marked("client_offworld"))

	# Eliminate 2 sentries and complete all 3 objectives
	host_site.health_component.current_health = 100000.0
	client_site.health_component.current_health = 100000.0
	var kills := 0
	for child in site.enemies.get_children():
		var jaffa := child as JaffaAI
		if jaffa != null and not jaffa.health_component.is_dead:
			jaffa.health_component.take_damage(9999.0, host_site, "test")
			kills += 1
			if kills == 2:
				break
	assert(site.hostiles_eliminated_count() == 2)

	host_site.global_position = console_spot(&"generator")
	await use_console(&"generator", host_site)
	host_site.global_position = console_spot(&"cmd_command")
	await use_console(&"cmd_command", host_site)

	site.stargate_mesh.kawoosh_duration_s = 0.08
	var entry := site.level.marker(&"gate", &"entry")
	host_site.global_position = entry + Vector3(-0.5, 0.05, 0.0)
	client_site.global_position = entry + Vector3(0.5, 0.05, 0.0)
	for _i: int in range(120):
		await frames(1)
		if site.objectives.is_complete() and site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE:
			break
	assert(site.objectives.is_complete())
	assert(site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE)
	assert(site.stargate_mesh.extraction_authorized)
	assert(session.result == -1)

	mark("site_gate_open")
	assert(await marked("client_saw_site_gate"))

	# Host steps through site gate back to SGC ramp
	site.stargate_mesh._on_extraction_entered(host_site)
	await frames(10)
	var host_returned := home.players_container.get_node_or_null("1") as PlayerController3D
	assert(host_returned != null and host_returned.global_position.y > 1.8)
	assert(session.presented == home)
	assert(session.result == -1, "Mission waits for client still standing offworld")
	mark("host_returned")
	assert(await marked("client_saw_host_return"))

	# Client goes down offworld -> triggers D-017 victory & SGC debrief across both peers
	client_site.health_component.current_health = 10.0
	client_site.health_component.take_damage(500.0, null, "bullet")
	for _i: int in range(120):
		await frames(1)
		if session.result == 1:
			break
	assert(session.result == 1 and home.mission_result == 1 and site.mission_result == 1)
	assert(home.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(site.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(home.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	assert(home.hud.stat_kills.text == "HOSTILES ELIMINATED: 2", home.hud.stat_kills.text)
	assert(home.hud.stat_waves.text == "OBJECTIVES COMPLETE: 3 / 3", home.hud.stat_waves.text)
	assert("Host O'Neill" in home.hud.stat_chevrons.text and "Return Carter" in home.hud.stat_chevrons.text, home.hud.stat_chevrons.text)

	mark("mission_finished")
	assert(await marked("client_saw_debrief"))

	# Two-world retry across both processes
	var old_home := home.get_instance_id()
	assert(net.request_restart_game())
	await worlds(old_home)
	for _i: int in range(1200):
		if home.players_container.get_child_count() >= 2:
			break
		await frames(1)
	assert(home.players_container.get_child_count() == 2, "Both host and client respawn in SGC after retry")
	assert(site.players_container.get_child_count() == 0 and site.enemies.get_child_count() == 6)
	assert(session.result == -1 and home.mission_result == -1 and site.mission_result == -1)

	mark("host_restarted")
	assert(await marked("client_restarted"))

	await frames(10)
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	assert(await marked("client_disconnected"))
	await frames(20)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Return Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	await worlds()
	await frames(20)
	mark("client_ready")

	assert(await marked("host_traveled"))
	await frames(10)
	assert(home.players_container.get_node_or_null("1") == null)
	mark("client_saw_host_travel")

	assert(await marked("both_offworld"))
	for _i: int in range(1200):
		if session.presented == site and site.players_container.has_node(str(net.local_peer_id)):
			break
		await frames(1)
	assert(session.presented == site)
	mark("client_offworld")

	assert(await marked("site_gate_open"))
	for _i: int in range(600):
		if site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE and site.stargate_mesh.extraction_authorized:
			break
		await frames(1)
	assert(site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE)
	assert(site.stargate_mesh.event_horizon_mesh.visible)
	mark("client_saw_site_gate")

	assert(await marked("host_returned"))
	await frames(15)
	assert(session.presented == site, "Client remains presented offworld while standing there")
	assert(site.mission_result == -1)
	mark("client_saw_host_return")

	assert(await marked("mission_finished"))
	for _i: int in range(600):
		if home.hud.is_mission_ended and session.presented == home:
			break
		await frames(1)
	assert(session.presented == home, "Client presentation moves to SGC for debrief")
	assert(home.hud.is_mission_ended and home.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	assert(home.hud.stat_kills.text == "HOSTILES ELIMINATED: 2", home.hud.stat_kills.text)
	assert(home.hud.stat_waves.text == "OBJECTIVES COMPLETE: 3 / 3", home.hud.stat_waves.text)
	assert("Host O'Neill" in home.hud.stat_chevrons.text and "Return Carter" in home.hud.stat_chevrons.text, home.hud.stat_chevrons.text)
	mark("client_saw_debrief")

	var old_home := home.get_instance_id()
	assert(await marked("host_restarted"))
	await worlds(old_home)
	for _i: int in range(600):
		if site.enemies.get_child_count() == 6:
			break
		await frames(1)
	assert(session.presented == home and home.mission_result == -1 and site.mission_result == -1)
	assert(site.enemies.get_child_count() == 6)
	mark("client_restarted")

	for _i: int in range(1200):
		if not net.is_in_active_session():
			break
		await frames(1)
	mark("client_disconnected")
