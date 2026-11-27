extends SceneTree
## Multi-process ENet authority test for CO-2 roles, fast medic revive, remote Field Medkit,
## forged/replay rejection, offworld DeployableShield replication, and coordinated retry.

const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var output_dir: String = ""
var is_dedicated: bool = false
var slot: int = 0
var children: Array[int] = []


func dedicated() -> bool:
	return false


func port() -> int:
	return 19956 if is_dedicated else 19955


func client_script() -> String:
	return "res://tests/test_co2_roles_and_cover_multiplayer.gd"


func _init() -> void:
	call_deferred("run")


func _finalize() -> void:
	for pid: int in children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(4)
		await process_frame


func mark(label: String, payload: Variant = "ok") -> void:
	var file := FileAccess.open(output_dir.path_join(label), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))


func marked(label: String, timeout_s: float = 35.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	return false


func read_mark(label: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join(label)))


func spawn_child(child_slot: int) -> void:
	var args: Array[String] = [
		"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output_dir.path_join("client_%d.log" % child_slot),
		"--script", client_script(),
		"--", "--co2-child", str(child_slot), "--result-dir", output_dir,
	]
	if is_dedicated:
		args.append("--co2-dedicated")
	var pid := OS.create_process(OS.get_executable_path(), args)
	assert(pid > 0, "CO-2 child process must start")
	children.append(pid)


func mission(previous: int = 0) -> ModularMission:
	for _i: int in range(3600):
		var room := main.current_gate_room as ModularMission
		if (
			room != null
			and room.get_instance_id() != previous
			and room.is_started
			and (slot == 0 and is_dedicated or room.players_container.has_node(str(net.local_peer_id)))
		):
			return room
		await frames(1)
	assert(false, "CO-2 ModularMission did not start")
	return null


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--co2-child"):
		slot = args[args.find("--co2-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--co2-dedicated")
	var engine_args := OS.get_cmdline_args()
	var log_index := engine_args.find("--log-file")
	var log_dir := engine_args[log_index + 1].get_base_dir() if log_index >= 0 else ProjectSettings.globalize_path("res://../build/test-results")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else log_dir.path_join("co2-roles-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)

	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if slot > 0:
		await run_client()
	else:
		await run_host()

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(5)
	net.disconnect_game()
	if slot > 0:
		mark("exit_%d" % slot)
	print("PASS CO-2 roles & cover ENet (dedicated=%s slot=%d)" % [str(is_dedicated), slot])
	await preload("res://tests/support/finish.gd").success(self)


func _freeze_enemies(room: ModularMission) -> void:
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(false)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	if not is_dedicated:
		net.selected_class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	assert(net.host_game(port()) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	_freeze_enemies(room)

	var expected_clients := 2 if is_dedicated else 1
	for c: int in range(1, expected_clients + 1):
		spawn_child(c)
		assert(await marked("ready_%d" % c), "Client %d ready" % c)

	var carter_id := int(read_mark("ready_1"))
	var heavy_id := int(read_mark("ready_2")) if is_dedicated else 1
	var deadline := Time.get_ticks_msec() + 15000
	while (not room.players_container.has_node(str(carter_id)) or not room.players_container.has_node(str(heavy_id))) and Time.get_ticks_msec() < deadline:
		await frames(1)

	var carter := room.players_container.get_node(str(carter_id)) as PlayerController3D
	var heavy := room.players_container.get_node(str(heavy_id)) as PlayerController3D
	assert(carter != null and heavy != null)
	carter.health_component.current_health = 10000.0
	var entry := room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker)
	var spot_a := entry + Vector3(-0.6, 0.05, 0.2)
	var spot_b := entry + Vector3(0.6, 0.05, 0.2)
	if not is_dedicated:
		heavy.global_position = spot_b
		heavy.rotation.y = 0.0
	mark("place_1", {"cx": spot_a.x, "cy": spot_a.y, "cz": spot_a.z, "hx": spot_b.x, "hy": spot_b.y, "hz": spot_b.z})
	await frames(2)
	assert(await marked("placed_1"), "Clients reached placement")
	deadline = Time.get_ticks_msec() + 15000
	while (carter.global_position.distance_to(spot_a) > 0.2 or heavy.global_position.distance_to(spot_b) > 0.2) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(carter.global_position.distance_to(spot_a) <= 0.2 and heavy.global_position.distance_to(spot_b) <= 0.2)

	# 1. Server-authoritative Carter fast revive on downed Heavy
	heavy.health_component.take_damage(9999.0, null, "bullet")
	assert(heavy.health_component.is_downed)
	mark("revive_heavy")
	deadline = Time.get_ticks_msec() + 15000
	while heavy.health_component.is_downed and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(not heavy.health_component.is_downed, "Remote Carter revived Heavy")
	assert(is_equal_approx(heavy.health_component.current_health, heavy.health_component.max_health * 0.75),
		"Server authoritative medic revive must restore 75% HP")

	# 2. Server-authoritative Field Medkit (+50 HP clamped to max 150 -> 150) & replay rejection
	heavy.health_component.current_health = 80.0
	heavy.health_component._publish_state()
	mark("aid_heavy")
	assert(await marked("aid_sent"))
	deadline = Time.get_ticks_msec() + 15000
	while (carter.medkit_charges != 1 or not is_equal_approx(heavy.health_component.current_health, 130.0)) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(carter.medkit_charges == 1 and is_equal_approx(heavy.health_component.current_health, 130.0),
		"Server must apply +50 HP and reject forged/replay medkit RPCs")

	# 3. Remote Carter offworld DeployableShield replication & invalid wall rejection
	mark("deploy_shield_cmd")
	assert(await marked("shield_deployed_client"))
	var deployments := room.get_node("FieldKitDeployments") as Node3D
	deadline = Time.get_ticks_msec() + 15000
	while deployments.get_child_count() == 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(deployments.get_child_count() == 1 and carter.deployable_shields_count == 0, "Server spawns replicated offworld shield")
	await frames(5)
	mark("shield_confirmed_host")
	assert(await marked("shield_seen_all_%d" % expected_clients))
	if is_dedicated:
		assert(await marked("shield_seen_heavy"))

	# 4. Coordinated retry clears offworld shield and restocks medkits
	var prev_id := room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(prev_id)
	_freeze_enemies(room)
	deadline = Time.get_ticks_msec() + 15000
	while not room.players_container.has_node(str(carter_id)) and Time.get_ticks_msec() < deadline:
		await frames(1)
	carter = room.players_container.get_node(str(carter_id)) as PlayerController3D
	assert(room.get_node("FieldKitDeployments").get_child_count() == 0, "Retry clears deployed shields")
	assert(carter.medkit_charges == 2 and carter.deployable_shields_count == 1, "Retry restocks Carter kit")

	for c: int in range(1, expected_clients + 1):
		assert(await marked("retry_ok_%d" % c), "Client %d verified retry" % c)
	mark("done")
	for c: int in range(1, expected_clients + 1):
		assert(await marked("exit_%d" % c), "Client %d exited cleanly" % c)
	await frames(15)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log_text := FileAccess.get_file_as_string(output_dir.path_join(file))
			assert(log_text.contains("PASS CO-2 roles & cover") and not log_text.contains("ERROR:") and not log_text.contains("ObjectDB"), log_text)


func run_client() -> void:
	net.player_name = "CO2 Operative %d" % slot
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH if slot == 1 else SGCNetworkManager.CLASS_SG3_HEAVY
	assert(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	_freeze_enemies(room)
	mark("ready_%d" % slot, net.local_peer_id)

	assert(await marked("place_1"))
	var coords: Dictionary = read_mark("place_1")
	var spot_a := Vector3(float(coords.cx), float(coords.cy), float(coords.cz))
	var spot_b := Vector3(float(coords.hx), float(coords.hy), float(coords.hz))
	var mine := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	mine.global_position = spot_a if slot == 1 else spot_b
	mine.rotation.y = 0.0
	await frames(4)
	if not is_dedicated or slot == 2:
		mark("placed_1")
	else:
		var deadline_p := Time.get_ticks_msec() + 10000
		while not FileAccess.file_exists(output_dir.path_join("placed_1")) and Time.get_ticks_msec() < deadline_p:
			await frames(1)

	# Heavy waits to be revived; Carter holds revive against server
	var heavy_node: PlayerController3D = null
	var deadline := Time.get_ticks_msec() + 15000
	while heavy_node == null and Time.get_ticks_msec() < deadline:
		for child in room.players_container.get_children():
			var op := child as PlayerController3D
			if op != null and op.class_id == SGCNetworkManager.CLASS_SG3_HEAVY:
				heavy_node = op
				break
		if heavy_node == null:
			await frames(1)
	assert(heavy_node != null, "Client sees Heavy operative")

	assert(await marked("revive_heavy"))
	if slot == 1:
		var carter := mine
		deadline = Time.get_ticks_msec() + 15000
		while not heavy_node.health_component.is_downed and Time.get_ticks_msec() < deadline:
			await frames(1)
		assert(heavy_node.health_component.is_downed)
		var revive_path := carter.get_parent().get_path_to(heavy_node)
		var hold_deadline := Time.get_ticks_msec() + 4000
		while heavy_node.health_component.is_downed and Time.get_ticks_msec() < hold_deadline:
			carter.server_revive_hold.rpc_id(1, revive_path)
			await frames(5)
		carter.server_revive_hold.rpc_id(1, NodePath())
		assert(not heavy_node.health_component.is_downed, "Carter client observes Heavy revived")

	assert(await marked("aid_heavy"))
	if slot == 1:
		var carter := mine
		deadline = Time.get_ticks_msec() + 15000
		while heavy_node.health_component.current_health > 85.0 and Time.get_ticks_msec() < deadline:
			await frames(1)
		carter.request_field_aid(heavy_node)
		# Attempt replay with same sequence & forged actor call from wrong class
		carter.server_request_field_aid.rpc_id(1, carter._field_aid_sequence, carter.ammo_share_incarnation, carter.get_parent().get_path_to(heavy_node), heavy_node.ammo_share_incarnation)
		heavy_node.server_request_field_aid.rpc_id(1, 999, heavy_node.ammo_share_incarnation, NodePath(), "")
		mark("aid_sent")

	assert(await marked("deploy_shield_cmd"))
	if slot == 1:
		var carter := mine
		carter.deploy_shield()
		deadline = Time.get_ticks_msec() + 15000
		while carter.deployable_shields_count != 0 and Time.get_ticks_msec() < deadline:
			await frames(1)
		assert(carter.deployable_shields_count == 0, "Remote Carter receives confirmed shield spend")
		mark("shield_deployed_client")

	assert(await marked("shield_confirmed_host"))
	var deployments := room.get_node("FieldKitDeployments") as Node3D
	deadline = Time.get_ticks_msec() + 15000
	while deployments.get_child_count() == 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(deployments.get_child_count() == 1 and deployments.get_child(0) is DeployableShield)
	if is_dedicated and slot == 2:
		mark("shield_seen_heavy")
	mark("shield_seen_all_%d" % (1 if not is_dedicated else 2))

	var prev_id := room.get_instance_id()
	room = await mission(prev_id)
	_freeze_enemies(room)
	mine = room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	if slot == 1:
		deadline = Time.get_ticks_msec() + 15000
		while (mine.medkit_charges != 2 or mine.deployable_shields_count != 1) and Time.get_ticks_msec() < deadline:
			await frames(1)
		assert(mine.medkit_charges == 2 and mine.deployable_shields_count == 1)
	assert(room.get_node("FieldKitDeployments").get_child_count() == 0)
	mark("retry_ok_%d" % slot)
	assert(await marked("done"))
