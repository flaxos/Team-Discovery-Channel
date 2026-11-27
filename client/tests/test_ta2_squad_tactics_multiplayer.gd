extends SceneTree
## Multi-process ENet verification of TA-2 chunk 3: remote offworld shield anchor Hold Corner,
## replicated coordinated rescue cover fire (is_providing_cover_fire / is_peeking), modular bounding
## overwatch across connected rooms, and clean retry reset on listen & dedicated servers.

const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const Wheel := preload("res://scripts/ui/RadialCommandWheel.gd")

var net: SGCNetworkManager
var main: MainGameCoordinator
var output_dir: String = ""
var is_dedicated: bool = false
var slot: int = 0
var children: Array[int] = []


func dedicated() -> bool:
	return false


func port() -> int:
	return 19986 if is_dedicated else 19985


func client_script() -> String:
	return "res://tests/test_ta2_squad_tactics_multiplayer.gd"


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
		"--", "--ta2-child", str(child_slot), "--result-dir", output_dir,
	]
	if is_dedicated:
		args.append("--ta2-dedicated")
	var pid := OS.create_process(OS.get_executable_path(), args)
	assert(pid > 0, "TA-2 child process must start")
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
	assert(false, "TA-2 ModularMission did not start")
	return null


func _park_enemies(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy: JaffaAI in room.enemies.get_children():
		enemy.stand_down()


func _airmen(room: ModularMission) -> Array[SGCAirmanAI]:
	var res: Array[SGCAirmanAI] = []
	if room.allies_container != null:
		for node in room.allies_container.get_children():
			var a := node as SGCAirmanAI
			if a != null:
				res.append(a)
	return res


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--ta2-child"):
		slot = args[args.find("--ta2-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--ta2-dedicated")
	var engine_args := OS.get_cmdline_args()
	var log_index := engine_args.find("--log-file")
	var log_dir := engine_args[log_index + 1].get_base_dir() if log_index >= 0 else ProjectSettings.globalize_path("res://../build/test-results")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else log_dir.path_join("ta2-squad-" + str(OS.get_process_id()))
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
	print("PASS TA-2 squad tactics ENet (dedicated=%s slot=%d)" % [str(is_dedicated), slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	assert(net.host_game(port()) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	_park_enemies(room)

	var expected_clients := 2 if is_dedicated else 1
	for c: int in range(1, expected_clients + 1):
		spawn_child(c)
		assert(await marked("ready_%d" % c))
	var actor_id := int(read_mark("ready_1"))
	var deadline := Time.get_ticks_msec() + 15000
	while not room.players_container.has_node(str(actor_id)) and Time.get_ticks_msec() < deadline:
		await frames(1)
	var actor := room.players_container.get_node(str(actor_id)) as PlayerController3D
	var host_op := room.players_container.get_node("1") as PlayerController3D if not is_dedicated else room.players_container.get_node(str(int(read_mark("ready_2")))) as PlayerController3D
	host_op.health_component.current_health = 10000.0

	# 1. Remote operative deploys shield offworld, steps clear so server syncs position, and orders Airman to Hold Corner behind it
	mark("deploy_shield")
	var deployments := room.get_node("FieldKitDeployments") as Node3D
	deadline = Time.get_ticks_msec() + 15000
	while deployments.get_child_count() == 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(deployments.get_child_count() == 1, "Remote offworld shield spawned on server")
	var clear_spot := room.level.marker(&"gate", &"entry") + Vector3(2.0, 0.05, 1.5)
	deadline = Time.get_ticks_msec() + 15000
	while actor.global_position.distance_to(clear_spot) > 0.35 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(actor.global_position.distance_to(clear_spot) <= 0.35, "Server receives remote operative step-clear pose")
	mark("ready_to_order")
	deadline = Time.get_ticks_msec() + 15000
	while not _airmen(room).any(func(a: SGCAirmanAI) -> bool: return a.current_state == SGCAirmanAI.State.HOLD_CORNER and a.is_in_cover) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(_airmen(room).any(func(a: SGCAirmanAI) -> bool: return a.current_state == SGCAirmanAI.State.HOLD_CORNER and a.is_in_cover))
	mark("shield_cover_ok")
	assert(await marked("client_saw_cover_%d" % expected_clients))

	# 2. Coordinated rescue cover fire: down remote operative while both Airmen are in gate
	var holder := _airmen(room)[0]
	var partner := _airmen(room)[1]
	var gate_entry := room.level.marker(&"gate", &"entry")
	holder.global_position = gate_entry + Vector3(-1.0, 0.05, 0.0)
	partner.global_position = gate_entry + Vector3(2.2, 0.05, 0.0)
	actor.health_component.take_damage(99999.0, null, "bullet")
	assert(actor.health_component.is_downed)
	deadline = Time.get_ticks_msec() + 15000
	var saw_cover_fire := false
	while actor.health_component.is_downed and Time.get_ticks_msec() < deadline:
		for a: SGCAirmanAI in _airmen(room):
			if a.current_state == SGCAirmanAI.State.COVER_FIRE and a.is_providing_cover_fire and a.is_peeking:
				saw_cover_fire = true
		await frames(1)
	assert(not actor.health_component.is_downed, "Airman completes remote rescue")
	assert(saw_cover_fire, "Fireteam partner provides replicated covering fire during rescue")

	# 3. Retry restores Airmen cleanly to STAGING and clears shield
	var prev_id := room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(prev_id)
	_park_enemies(room)
	assert(room.get_node("FieldKitDeployments").get_child_count() == 0)
	assert(_airmen(room).size() == 2 and _airmen(room)[0].current_state == SGCAirmanAI.State.STAGING)
	for c: int in range(1, expected_clients + 1):
		assert(await marked("retry_ok_%d" % c))
	mark("done")
	for c: int in range(1, expected_clients + 1):
		assert(await marked("exit_%d" % c))
	await frames(20)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log_text := FileAccess.get_file_as_string(output_dir.path_join(file))
			assert(log_text.contains("PASS TA-2 squad tactics") and not log_text.contains("ERROR:") and not log_text.contains("ObjectDB"), log_text)


func run_client() -> void:
	net.player_name = "TA2 Operative %d" % slot
	net.selected_class_id = SGCNetworkManager.CLASS_SG3_HEAVY if slot == 1 else SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", port()) == OK)
	var room := await mission()
	_park_enemies(room)
	var mine := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	var gate_entry := room.level.marker(&"gate", &"entry")
	if slot == 1:
		mine.global_position = gate_entry + Vector3(0.0, 0.05, 1.5)
		mine.rotation.y = 0.0
	else:
		mine.global_position = gate_entry + Vector3(2.4, 0.05, 1.8)
	await frames(4)
	mark("ready_%d" % slot, net.local_peer_id)

	assert(await marked("deploy_shield"))
	if slot == 1:
		mine.deploy_shield()
		var deployments := room.get_node("FieldKitDeployments") as Node3D
		var deadline_s := Time.get_ticks_msec() + 15000
		while deployments.get_child_count() == 0 and Time.get_ticks_msec() < deadline_s:
			await frames(1)
		var shield := deployments.get_child(0) as DeployableShield
		mine.global_position = gate_entry + Vector3(2.0, 0.05, 1.5)
		assert(await marked("ready_to_order"))
		mine.execute_squad_radial_command(Wheel.CMD_HOLD_CORNER, shield.global_position)

	assert(await marked("shield_cover_ok"))
	var deadline := Time.get_ticks_msec() + 15000
	while not _airmen(room).any(func(a: SGCAirmanAI) -> bool: return a.is_in_cover) and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(_airmen(room).any(func(a: SGCAirmanAI) -> bool: return a.is_in_cover), "Client sees Airman cover state replicated")
	mark("client_saw_cover_%d" % slot)

	var prev_id := room.get_instance_id()
	room = await mission(prev_id)
	_park_enemies(room)
	deadline = Time.get_ticks_msec() + 15000
	while _airmen(room).size() < 2 and Time.get_ticks_msec() < deadline:
		await frames(1)
	assert(_airmen(room).size() == 2 and _airmen(room)[0].current_state == SGCAirmanAI.State.STAGING)
	mark("retry_ok_%d" % slot)
	assert(await marked("done"))
