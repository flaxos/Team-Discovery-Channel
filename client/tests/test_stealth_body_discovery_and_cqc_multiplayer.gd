extends SceneTree
## Two-process ENet listen-host + client verification for Stealth Follow-ups:
## 1. Remote client throws combat knife [V] -> server spawns replicated ThrownKnife, silently kills
##    unalerted sentry, decrements & syncs throwing_knives_count (2 -> 1) on client HUD, and client
##    recovers lodged knife back to 2.
## 2. Patrolling witness sentry on server discovers a slain comrade -> replicates ALERTED tell,
##    MissionAlert SEARCHING, and "FALLEN JAFFA DISCOVERED" HUD toast to the remote client.

const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const PORT := 19943
const JAFFA_SCENE := "res://scenes/entities/JaffaGuard.tscn"

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
	return OS.get_cmdline_user_args().has("--stealth-cqc-child")


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
	assert(false, "Mission did not start")
	return null


func place(actor: CharacterBody3D, pos: Vector3) -> void:
	actor.global_position = pos + Vector3(0.0, 0.05, 0.0)
	actor.velocity = Vector3.ZERO


func face_dir(node: Node3D, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		node.rotation.y = atan2(-flat.x, -flat.z)


func find_lane(room: ModularMission) -> Dictionary:
	var base := room.level.marker(&"gate", &"entry")
	var space := room.get_world_3d().direct_space_state
	for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var a := NavigationServer3D.map_get_closest_point(room.level.navigation_map, base)
		var b := NavigationServer3D.map_get_closest_point(room.level.navigation_map, base + dir * 6.0)
		if a.distance_to(b) < 5.0:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(a + Vector3.UP * 1.1, b + Vector3.UP * 1.1, 1 | 128)).is_empty():
			return {"a": a, "b": b, "dir": (b - a).normalized()}
	assert(false, "No clear lane in gate room")
	return {}


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
		else log_dir.path_join("stealth-cqc-multi-" + str(OS.get_process_id()))
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
	print("PASS stealth cqc client" if is_child() else "PASS stealth body discovery and cqc multiplayer")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	for child in room.enemies.get_children():
		child.queue_free()
	if room.allies_container != null:
		for ally in room.allies_container.get_children():
			ally.queue_free()
	await frames(4)
	var host_op := room.players_container.get_node("1") as PlayerController3D
	host_op.health_component.current_health = 1000000.0
	place(host_op, room.level.marker(&"cmd_command", &"entry"))

	var lane := find_lane(room)
	var a: Vector3 = lane["a"]
	var b: Vector3 = lane["b"]
	var d: Vector3 = lane["dir"]

	# Spawn unalerted sentry target at b facing away from a.
	var target := (load(JAFFA_SCENE) as PackedScene).instantiate() as JaffaAI
	target.name = "KnifeTarget"
	target.profile = JaffaAI.Profile.SENTRY
	target.position = room.enemies.to_local(b + Vector3(0.0, 0.05, 0.0))
	room.enemies.add_child(target, true)
	target.start_patrol([b])
	face_dir(target, d)

	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_stealth_body_discovery_and_cqc_multiplayer.gd",
			"--", "--stealth-cqc-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)
	assert(await marked("client_joined"))

	var guest: PlayerController3D = null
	var deadline := Time.get_ticks_msec() + 15000
	while guest == null and Time.get_ticks_msec() < deadline:
		for child in room.players_container.get_children():
			var p := child as PlayerController3D
			if p != null and p.peer_id != 1:
				guest = p
				break
		await frames(1)
	assert(guest != null)
	guest.health_component.current_health = 1000000.0
	mark("pose_spec", "%f,%f,%f|%f,%f,%f" % [a.x, a.y, a.z, b.x, b.y, b.z])

	assert(await marked("client_positioned"))
	deadline = Time.get_ticks_msec() + 15000
	while guest.global_position.distance_to(a) > 0.6 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(guest.global_position.distance_to(a) <= 0.6, "Server synced client throw pose")
	mark("server_ready_throw")

	# Wait for client's thrown knife to silently kill KnifeTarget on server.
	assert(await marked("client_threw_knife"))
	deadline = Time.get_ticks_msec() + 15000
	while not target.health_component.is_dead and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(target.health_component.is_dead, "Server resolved client's thrown combat knife kill")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Silent thrown knife kill keeps compound CALM")
	assert(guest.throwing_knives_count == 1, "Server decremented client throwing_knives_count to 1")
	mark("kill_confirmed")

	# Wait for client to recover lodged knife back to 2.
	assert(await marked("client_recovered_request"))
	deadline = Time.get_ticks_msec() + 15000
	while guest.throwing_knives_count < 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(guest.throwing_knives_count == 2, "Server restored client throwing_knives_count to 2")
	mark("recovery_confirmed")

	# Now spawn a patrolling witness sentry facing KnifeTarget's corpse -> body discovery!
	assert(await marked("client_parked_for_discovery"))
	var witness := (load(JAFFA_SCENE) as PackedScene).instantiate() as JaffaAI
	witness.name = "BodyWitness"
	witness.profile = JaffaAI.Profile.SENTRY
	witness.position = room.enemies.to_local(a + Vector3(0.0, 0.05, 0.0))
	room.enemies.add_child(witness, true)
	witness.start_patrol([a])
	face_dir(witness, d)

	deadline = Time.get_ticks_msec() + 15000
	while room.alert.alert_level != MissionAlert.Level.SEARCHING and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(target.body_discovered_flag, "Witness discovered KnifeTarget's corpse on server")
	assert(witness.awareness_level == JaffaPerception.Level.ALERTED, "Witness escalated to ALERTED")
	assert(room.alert.alert_level == MissionAlert.Level.SEARCHING, "Compound escalated to SEARCHING")
	mark("discovery_confirmed")

	assert(await marked("client_done"))
	deadline = Time.get_ticks_msec() + 15000
	while OS.is_process_running(child_pid) and Time.get_ticks_msec() < deadline:
		await frames(1)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert("PASS stealth cqc client" in log_text, log_text)
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Recon O'Neill"
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission()
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	mark("client_joined")
	assert(await marked("pose_spec"))
	var parts := FileAccess.get_file_as_string(output_dir.path_join("pose_spec")).split("|")
	var a_vals := parts[0].split(",")
	var b_vals := parts[1].split(",")
	var a := Vector3(float(a_vals[0]), float(a_vals[1]), float(a_vals[2]))
	var b := Vector3(float(b_vals[0]), float(b_vals[1]), float(b_vals[2]))

	place(me, a)
	face_dir(me, b - a)
	me.current_aim_target = Vector3.ZERO
	await frames(15)
	mark("client_positioned")
	assert(await marked("server_ready_throw"))

	assert(me.try_throw_knife(), "Client sends thrown combat knife request")
	mark("client_threw_knife")
	assert(await marked("kill_confirmed"))

	var deadline := Time.get_ticks_msec() + 15000
	while me.throwing_knives_count != 1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(me.throwing_knives_count == 1, "Client received confirmed throwing_knives_count == 1")
	assert(room.hud.gadget_label.text.contains("KNIFE (1/2)"), "Client HUD reflects 1/2 knives: %s" % room.hud.gadget_label.text)

	# Locate replicated lodged knife and recover via interact RPC.
	var knife: ThrownKnife = null
	deadline = Time.get_ticks_msec() + 15000
	while knife == null and Time.get_ticks_msec() < deadline:
		for node in MissionWorld.in_group(room, &"thrown_knife"):
			var tk := node as ThrownKnife
			if tk != null and tk.lodged:
				knife = tk
				break
		await frames(1)
	assert(knife != null, "Client sees replicated lodged ThrownKnife")
	place(me, knife.global_position + Vector3(0.5, 0.0, 0.0))
	await frames(20)
	if is_instance_valid(knife):
		knife.interact(me)
	mark("client_recovered_request")
	assert(await marked("recovery_confirmed"))

	deadline = Time.get_ticks_msec() + 15000
	while me.throwing_knives_count != 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(me.throwing_knives_count == 2, "Client synced restored throwing_knives_count == 2")

	# Park client out of sight so witness discovers ONLY the corpse, not the player.
	place(me, room.level.marker(&"cmd_command", &"entry"))
	await frames(20)
	mark("client_parked_for_discovery")
	assert(await marked("discovery_confirmed"))

	deadline = Time.get_ticks_msec() + 15000
	while (room.alert.alert_level != MissionAlert.Level.SEARCHING or not ("FALLEN JAFFA DISCOVERED" in room.hud.squad_toast_label.text)) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(room.alert.alert_level == MissionAlert.Level.SEARCHING, "Client synced MissionAlert SEARCHING from body discovery")
	assert("FALLEN JAFFA DISCOVERED" in room.hud.squad_toast_label.text, "Client HUD received fallen Jaffa discovery toast")
	mark("client_done")
