extends SceneTree
## Two worlds across two Godot processes (roadmap GT-1). A listen host runs the quiet SGC and
## the Goa'uld compound side by side, with its own operative in the compound. A client joins
## late: it must load both worlds, arrive in the SGC (decision D-017), present the SGC, and
## still receive the compound's operative and patrols 2 km away. The mission is lost only
## when the operatives in both worlds are down, and both peers see that result.
const MISSION := SGCNetworkManager.MISSION_TWO_WORLDS_DEV
const PORT := 19877
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
	return OS.get_cmdline_user_args().has("--coexistence-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


## Both worlds loaded and started, and this peer's operative created at home.
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
		else log_dir.path_join("coexistence-" + str(OS.get_process_id()))
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
	print("PASS late client in two worlds" if is_child() else "PASS two peers, two worlds: late joiner at home, replication across both, shared loss")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await worlds()
	assert(site.setup_errors.is_empty() and site.enemies.get_child_count() == 6)
	# The host's operative goes to the compound by hand; travel itself is GT-2.
	var profile := (home.players_container.get_node("1") as PlayerController3D).class_id
	home.players_container.get_node("1").free()
	session.place(1, site)
	site._spawn_player(1, profile, (site.spawns_container.get_child(0) as Node3D).global_position)
	await frames(5)
	var me := site.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0
	assert(session.presented == site and home.squad_state() == Vector2i.ZERO)
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_world_coexistence_multiplayer.gd",
			"--", "--coexistence-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)
	for _i: int in range(2400):
		if home.squad_state().x == 1:
			break
		await frames(1)
	# The late joiner arrives in the SGC, although the only other operative is in the compound.
	assert(home.squad_state() == Vector2i(1, 1), "The late joiner's operative is in the SGC")
	assert(site.squad_state() == Vector2i(1, 1), "Nobody else was created in the compound")
	var guest := home.players_container.get_child(0) as PlayerController3D
	assert(guest.peer_id != 1 and session.world_of(guest.peer_id) == home)
	assert(session.presented == site, "The host goes on showing its own world")
	assert(await marked("joined"), "The client must load both worlds and report what it sees")
	await frames(2)
	var reported: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(output_dir.path_join("joined"))
	)
	assert(reported.size() == 7, "Six patrol Jaffa and the host's operative: " + str(reported.keys()))
	for actor_name: String in reported:
		var at: Array = reported[actor_name]
		var truth := (
			me.global_position if actor_name == "operative"
			else (site.enemies.get_node(actor_name) as Node3D).global_position
		)
		assert(truth.x > 1500.0 and truth.distance_to(Vector3(at[0], at[1], at[2])) < 2.5,
			"The client's copy follows " + actor_name)

	# The whole away team down: the mission continues, because the SGC operative stands.
	me.health_component.current_health = 10.0
	me.health_component.take_damage(500.0, null, "bullet")
	await frames(30)
	assert(me.health_component.is_downed and site.squad_state() == Vector2i(1, 0))
	assert(session.result == -1 and home.mission_result == -1 and site.mission_result == -1,
		"One operative standing in the SGC keeps the mission alive")
	mark("away_team_down")
	assert(await marked("still_running"), "The client also sees the mission continue")
	# Then the SGC operative: now everyone is down, in both worlds.
	guest.health_component.take_damage(5000.0, null, "bullet")
	for _i: int in range(600):
		await frames(1)
		if session.result >= 0:
			break
	assert(session.result == 0 and home.mission_result == 0 and site.mission_result == 0)
	assert(await marked("result"), "The client must show the same result in both worlds")
	await frames(30)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Late Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	await worlds()
	assert(net.selected_mission_id == MISSION and not net.is_server)
	var me := home.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	assert(MissionWorld.of(me) == home and home.hud.local_player == me)
	assert(str(site.get_path()) == "/root/Main/WorldContainer/Site/GateRoom")
	assert(site.global_position.is_equal_approx(MainGameCoordinator.SITE_OFFSET))
	# This peer shows the SGC; the compound is loaded, hidden and kept up to date.
	assert(session != null and session.presented == home)
	assert(home.visible and home.hud.visible and not site.visible and not site.hud.visible)
	for _i: int in range(2400):
		await frames(1)
		if site.enemies.get_child_count() == 6 and site.players_container.has_node("1"):
			break
	assert(site.enemies.get_child_count() == 6, "The compound's patrols reach a peer that is not there")
	assert(site.players_container.get_child_count() == 1, "Only the host's operative is in the compound")
	assert(home.players_container.get_child_count() == 1, "Only this peer's operative is in the SGC")
	await frames(90)
	var positions := {}
	for enemy in site.enemies.get_children():
		var at := (enemy as Node3D).global_position
		positions[str(enemy.name)] = [at.x, at.y, at.z]
	var host_operative := (site.players_container.get_node("1") as Node3D).global_position
	positions["operative"] = [host_operative.x, host_operative.y, host_operative.z]
	mark("joined", JSON.stringify(positions))
	assert(await marked("away_team_down"))
	await frames(60)
	assert(home.mission_result == -1 and site.mission_result == -1 and not home.hud.is_mission_ended)
	mark("still_running")
	for _i: int in range(2400):
		await frames(1)
		if home.mission_result >= 0 and site.mission_result >= 0:
			break
	assert(home.mission_result == 0 and site.mission_result == 0, "Both worlds show the loss")
	assert(home.hud.is_mission_ended)
	mark("result")
	await frames(60)
