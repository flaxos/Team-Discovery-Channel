extends SceneTree
## Two-process (listen host) & three-process (late-join observer) ENet verification for SW-2:
## Replicated Goa'uld personal shield aura, client ballistic deflection, client slow melee kill,
## client Zat overload, late-join shield snapshot synchronization, and retry cleanup.

const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const SHOCK := "res://scenes/entities/JaffaShockGuard.tscn"

var child_pid: int = -1
var observer_pid: int = -1
var output_dir: String = ""
var dedicated_host: bool = false
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func dedicated() -> bool:
	return false


func port_number() -> int:
	return 19892 if dedicated() else 19891


func _finalize() -> void:
	for pid: int in [child_pid, observer_pid]:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(5)
		await physics_frame


func role() -> String:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--role")
	return args[idx + 1] if idx >= 0 and idx + 1 < args.size() else "host"


func mark(label: String, text: String = "ok") -> void:
	var destination := output_dir.path_join(label)
	var staged := destination + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()
	assert(DirAccess.rename_absolute(staged, destination) == OK)


func marked(label: String, limit: int = 3000) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if role() == "host":
		for log_name: String in ["client.log", "observer.log"]:
			if FileAccess.file_exists(output_dir.path_join(log_name)):
				print("=== %s ===" % log_name)
				print(FileAccess.get_file_as_string(output_dir.path_join(log_name)))
	return false


func mission(expected_players: int = -1, previous: int = 0) -> ModularMission:
	for _i: int in range(3000):
		var room := main.current_gate_room as ModularMission
		var has_local := dedicated_host or (room != null and room.players_container.has_node(str(net.local_peer_id)))
		var count_ok := expected_players < 0 or (room != null and room.players_container.get_child_count() == expected_players)
		if room != null and room.get_instance_id() != previous and room.is_started and has_local and count_ok:
			return room
		await frames(1)
	assert(false, "ModularMission did not start")
	return null


func spawn_shielded_guard(room: ModularMission, guard_name: String, at: Vector3, facing: Vector3) -> JaffaAI:
	var jaffa := (load(SHOCK) as PackedScene).instantiate() as JaffaAI
	jaffa.name = guard_name
	jaffa.has_personal_shield = true
	jaffa.position = room.enemies.to_local(at + Vector3(0.0, 0.05, 0.0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var route: Array[Vector3] = [at]
	jaffa.start_patrol(route)
	return jaffa


func _on_floor(level: LevelAssembly, spot: Vector3) -> bool:
	return NavigationServer3D.map_get_closest_point(level.navigation_map, spot).distance_to(spot) < 0.4


func _clear_los(room: ModularMission, from: Vector3, to: Vector3) -> bool:
	var space := room.get_world_3d().direct_space_state
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0.0, eye, 0.0), to + Vector3(0.0, aim, 0.0), 1
			)
			if not space.intersect_ray(query).is_empty():
				return false
	return true


func _open_spot(room: ModularMission, skip_near: Vector3 = Vector3.INF) -> Dictionary:
	var level := room.level
	var entry := level.marker(level.layout.entry_instance, level.layout.entry_marker)
	for item in level.layout.instances:
		if item.id == level.layout.entry_instance:
			continue
		var at := level.marker(item.id, &"patrol")
		if at.distance_to(entry) < 6.0 or _clear_los(room, at, entry):
			continue
		if skip_near != Vector3.INF and at.distance_to(skip_near) < 3.0:
			continue
		for facing: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var front := at + facing * 3.5
			var behind := at - facing * 3.5
			if (
				_on_floor(level, at) and _on_floor(level, front) and _on_floor(level, behind)
				and _clear_los(room, at, front) and _clear_los(room, at, behind)
			):
				return {"at": at, "facing": facing, "front": front, "behind": behind}
	assert(false, "Could not find open test spot in modular layout")
	return {}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_idx := engine_args.find("--log-file")
	var log_dir := engine_args[log_idx + 1].get_base_dir() if log_idx >= 0 else OS.get_user_data_dir()
	var r := role()
	dedicated_host = dedicated() and r == "host"
	net = root.get_node("NetworkManager") as SGCNetworkManager
	output_dir = args[args.find("--result-dir") + 1] if r != "host" else log_dir.path_join("shield-mp-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)

	if r == "host":
		await run_host()
	elif r == "client":
		await run_client()
	else:
		await run_observer()

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS sw2 shield %s (dedicated=%s)" % [r, str(dedicated_host)])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = dedicated_host
	assert(net.host_game(port_number()) == OK)
	assert(net.set_mission(MISSION))
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.request_start_game()
	var room := await mission(0 if dedicated_host else 1)
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	if not dedicated_host:
		var host_player := room.players_container.get_node("1") as PlayerController3D
		host_player.health_component.current_health = 1000000.0

	for enemy: Node in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)

	var a_setup := _open_spot(room)
	var b_setup := _open_spot(room, a_setup.at)
	var alpha := spawn_shielded_guard(room, "ShieldAlpha", a_setup.at, a_setup.facing)
	var beta := spawn_shielded_guard(room, "ShieldBeta", b_setup.at, b_setup.facing)
	beta.set_physics_process(false)
	mark(
		"guards_ready",
		JSON.stringify({
			"alpha_front": [a_setup.front.x, a_setup.front.y, a_setup.front.z],
			"beta_behind": [b_setup.behind.x, b_setup.behind.y, b_setup.behind.z],
		})
	)

	child_pid = _spawn_peer("client", "client.log")
	assert(child_pid > 0)

	for _i: int in range(2400):
		await frames(1)
		for p: Node in room.players_container.get_children():
			var pc := p as PlayerController3D
			if pc != null:
				pc.health_component.current_health = 1000000.0
		if alpha.health_component.is_dead and not beta.is_physics_processing():
			beta.set_physics_process(true)
		if alpha.personal_shield.deflect_count >= 1 and alpha.health_component.is_dead and beta.personal_shield.is_overloaded:
			break
	if alpha.personal_shield.deflect_count < 1 or not alpha.health_component.is_dead or not beta.personal_shield.is_overloaded:
		for log_name: String in ["client.log"]:
			if FileAccess.file_exists(output_dir.path_join(log_name)):
				print("=== %s (host timeout) ===" % log_name)
				print(FileAccess.get_file_as_string(output_dir.path_join(log_name)))
	assert(alpha.personal_shield.deflect_count >= 1, "Server recorded client ballistic deflection on ShieldAlpha (deflect=%d)" % alpha.personal_shield.deflect_count)
	assert(alpha.health_component.is_dead, "Server executed client slow melee kill on ShieldAlpha")
	assert(beta.personal_shield.is_overloaded and not beta.has_active_shield(), "Server executed client Zat overload on ShieldBeta")

	# Keep overload active long enough for late-join snapshot check under slow CI
	beta.personal_shield.overload_timer = 30.0
	observer_pid = _spawn_peer("observer", "observer.log")
	assert(observer_pid > 0)
	assert(await marked("observer_verified"), "Late-join observer verified overloaded shield snapshot")
	var old_id := room.get_instance_id()
	mark("observer_can_leave")
	await frames(20)

	assert(await marked("client_done"), "Main client finished shield & retry checks")
	if not dedicated_host:
		assert(net.request_restart_game(), "Listen host triggers mission retry")
	room = await mission(1 if dedicated_host else 2, old_id)
	assert(room.enemies.get_child_count() == 5, "Retry resets to default mission patrols cleanly")
	mark("host_retried")
	await frames(20)


func run_client() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "SW2 Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", port_number()) == OK)
	var room := await mission()
	assert(await marked("guards_ready"))
	var spots: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join("guards_ready")))
	var alpha_front := Vector3(spots.alpha_front[0], spots.alpha_front[1], spots.alpha_front[2])
	var beta_behind := Vector3(spots.beta_behind[0], spots.beta_behind[1], spots.beta_behind[2])

	for _i: int in range(1800):
		await frames(1)
		if room.enemies.has_node("ShieldAlpha") and room.enemies.has_node("ShieldBeta"):
			break
	var alpha := room.enemies.get_node("ShieldAlpha") as JaffaAI
	var beta := room.enemies.get_node("ShieldBeta") as JaffaAI
	for _i: int in range(600):
		if alpha.personal_shield.is_active() and beta.personal_shield.is_active():
			break
		await frames(1)
	assert(alpha.has_personal_shield and alpha.personal_shield.is_active() and alpha.personal_shield.aura_mesh.visible, "Client replica shows active ShieldAlpha aura")
	assert(beta.has_personal_shield and beta.personal_shield.is_active() and beta.personal_shield.aura_mesh.visible, "Client replica shows active ShieldBeta aura")

	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	me.set_physics_process(false)
	# 1. Ballistic shot -> deflected
	for _attempt: int in range(5):
		if alpha.personal_shield.deflect_count >= 1:
			break
		me.global_position = alpha_front + Vector3(0.0, 0.05, 0.0)
		me.velocity = Vector3.ZERO
		var aim_alpha := alpha.global_position + Vector3(0.0, 1.0, 0.0)
		me.look_at(Vector3(aim_alpha.x, me.global_position.y, aim_alpha.z), Vector3.UP)
		me.current_aim_target = aim_alpha
		await frames(10)
		if me.current_weapon != null:
			me.current_weapon.fire_cooldown = 0.0
		me.request_weapon_fire()
		for _w: int in range(30):
			await frames(1)
			if alpha.personal_shield.deflect_count >= 1:
				break
	assert(alpha.personal_shield.deflect_count >= 1 and alpha.health_component.current_health == 140.0, "Client observes ballistic deflection without HP loss")

	# 2. Close-quarters slow melee strikes bypass active shield until eliminated
	for _attempt: int in range(5):
		if alpha.health_component.is_dead:
			break
		var rear := alpha.global_transform.basis.z
		rear.y = 0.0
		rear = rear.normalized()
		me.global_position = alpha.global_position + rear * 1.35 + Vector3(0.0, 0.05, 0.0)
		me.velocity = Vector3.ZERO
		me.look_at(Vector3(alpha.global_position.x, me.global_position.y, alpha.global_position.z), Vector3.UP)
		me.melee_cooldown = 0.0
		await frames(12)
		me.try_melee_strike()
		for _w: int in range(65):
			await frames(1)
			if alpha.health_component.is_dead:
				break
	assert(alpha.health_component.is_dead, "Client observes ShieldAlpha death via slow melee bypass")
	assert(not alpha.personal_shield.aura_mesh.visible)

	# 3. Zat shot on ShieldBeta to overload shield
	me.switch_slot(2)
	await frames(8)
	for _attempt: int in range(5):
		if beta.personal_shield.is_overloaded:
			break
		me.global_position = beta_behind + Vector3(0.0, 0.05, 0.0)
		me.velocity = Vector3.ZERO
		var aim_beta := beta.global_position + Vector3(0.0, 1.0, 0.0)
		me.look_at(Vector3(aim_beta.x, me.global_position.y, aim_beta.z), Vector3.UP)
		me.current_aim_target = aim_beta
		await frames(12)
		if me.current_weapon != null:
			me.current_weapon.fire_cooldown = 0.0
			me.current_weapon.current_heat = 0.0
		me.request_weapon_fire()
		for _w: int in range(30):
			await frames(1)
			if beta.personal_shield.is_overloaded:
				break
	assert(beta.personal_shield.is_overloaded and not beta.personal_shield.is_active(), "Client observes ShieldBeta shield overload")
	assert(not beta.personal_shield.aura_mesh.visible, "Client hides ShieldBeta aura while overloaded")

	assert(await marked("observer_can_leave"))
	mark("client_done")
	var old_id := room.get_instance_id()
	if dedicated():
		assert(net.request_restart_game(), "Client triggers mission retry on dedicated server")
	room = await mission(-1, old_id)
	assert(await marked("host_retried"))
	for _i: int in range(1800):
		await frames(1)
		if room.enemies.get_child_count() == 5:
			break
	assert(room.enemies.get_child_count() == 5 and not room.enemies.has_node("ShieldAlpha"))


func run_observer() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "Late Observer"
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	assert(net.join_game("127.0.0.1", port_number()) == OK)
	var room := await mission()
	for _i: int in range(1800):
		await frames(1)
		if room.enemies.has_node("ShieldBeta"):
			var beta := room.enemies.get_node("ShieldBeta") as JaffaAI
			if beta.personal_shield._last_revision >= 0:
				break
	var mirror := room.enemies.get_node("ShieldBeta") as JaffaAI
	assert(mirror.personal_shield._last_revision >= 0, "Late joiner received shield snapshot (rev=%d)" % mirror.personal_shield._last_revision)
	assert(mirror.has_personal_shield and mirror.personal_shield.is_overloaded, "Late joiner sees ShieldBeta overloaded state (has=%s enabled=%s overloaded=%s energy=%.1f rev=%d)" % [str(mirror.has_personal_shield), str(mirror.personal_shield.enabled), str(mirror.personal_shield.is_overloaded), mirror.personal_shield.energy, mirror.personal_shield._last_revision])
	assert(not mirror.personal_shield.is_active() and not mirror.personal_shield.aura_mesh.visible, "Late joiner hides overloaded shield aura")
	mark("observer_verified")
	assert(await marked("observer_can_leave"))


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_goauld_personal_shield_multiplayer.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)
