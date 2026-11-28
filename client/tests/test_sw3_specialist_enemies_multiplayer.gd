extends SceneTree
## Two-process (listen host) & three-process (late-join observer) ENet verification for SW-3:
## Replicated specialist combat roles (Officer, Heavy, Grenadier), Goa'uld System Lord Boss
## (`GoauldSystemLord.tscn`), TacticalHUD Boss Health & Shield Bar, replicated Goa'uld Shock
## Grenade disorientation/flash on client, Kara Kesh telekinetic shockwave impulse RPC to client,
## client Zat overload interrupting Kara Kesh beam + late-join snapshot sync, and retry cleanup.

const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
const LORD := "res://scenes/entities/GoauldSystemLord.tscn"

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
	return 19912 if dedicated() else 19911


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
		if at.distance_to(entry) < 5.0 or _clear_los(room, at, entry):
			continue
		if skip_near != Vector3.INF and at.distance_to(skip_near) < 3.0:
			continue
		for facing: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var front := at + facing * 4.5
			var behind := at - facing * 3.5
			if (
				_on_floor(level, at) and _on_floor(level, front) and _on_floor(level, behind)
				and _clear_los(room, at, front) and _clear_los(room, at, behind)
			):
				return {"at": at, "facing": facing, "front": front, "behind": behind}
	assert(false, "Could not find open spot for SW-3 multiplayer test")
	return {}


func _spawn_unit(room: ModularMission, scene_path: String, unit_name: String, role_id: String, at: Vector3, facing: Vector3) -> JaffaAI:
	var jaffa := (load(scene_path) as PackedScene).instantiate() as JaffaAI
	jaffa.name = unit_name
	jaffa.combat_role = role_id
	if role_id == JaffaAI.ROLE_GOAULD_LORD:
		jaffa.has_personal_shield = true
		jaffa.boss_display_name = "SYSTEM LORD ANUBIS"
	jaffa.position = room.enemies.to_local(at + Vector3(0.0, 0.05, 0.0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var route: Array[Vector3] = [at]
	jaffa.start_patrol(route)
	return jaffa


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_idx := engine_args.find("--log-file")
	var log_dir := engine_args[log_idx + 1].get_base_dir() if log_idx >= 0 else OS.get_user_data_dir()
	var r := role()
	dedicated_host = dedicated() and r == "host"
	net = root.get_node("NetworkManager") as SGCNetworkManager
	output_dir = args[args.find("--result-dir") + 1] if r != "host" else log_dir.path_join("sw3-mp-" + str(OS.get_process_id()))
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
	await frames(4)
	net.disconnect_game()
	print("PASS sw3 specialist enemies & boss %s (dedicated=%s)" % [r, str(dedicated_host)])
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
		host_player.health_component.max_health = 1000000.0
		host_player.health_component.current_health = 1000000.0

	for enemy: Node in room.enemies.get_children():
		enemy.queue_free()
	await frames(4)

	var spot := _open_spot(room)
	var side: Vector3 = (spot.facing as Vector3).cross(Vector3.UP).normalized()
	var boss := _spawn_unit(room, LORD, "SW3Boss", JaffaAI.ROLE_GOAULD_LORD, spot.at, spot.facing)
	var officer := _spawn_unit(room, JAFFA, "SW3Officer", JaffaAI.ROLE_OFFICER, spot.behind, spot.facing)
	var heavy := _spawn_unit(room, JAFFA, "SW3Heavy", JaffaAI.ROLE_HEAVY, spot.behind + side * 1.4, spot.facing)
	var grenadier := _spawn_unit(room, JAFFA, "SW3Grenadier", JaffaAI.ROLE_GRENADIER, spot.behind - side * 1.4, spot.facing)
	officer.set_physics_process(false)
	heavy.set_physics_process(false)
	grenadier.set_physics_process(false)
	# Freeze boss movement until client positions itself so positions stay deterministic
	boss.set_physics_process(false)

	mark(
		"units_ready",
		JSON.stringify({
			"front": [spot.front.x, spot.front.y, spot.front.z],
			"boss_at": [spot.at.x, spot.at.y, spot.at.z],
		})
	)

	child_pid = _spawn_peer("client", "client.log")
	assert(child_pid > 0)
	assert(await marked("client_positioned"), "Client positioned for SW-3 encounter checks")

	# Find remote client operative on host
	var remote_player: PlayerController3D = null
	for child: Node in room.players_container.get_children():
		var pc := child as PlayerController3D
		if pc != null and pc.peer_id != 1:
			remote_player = pc
			break
	assert(remote_player != null, "Server found remote client operative")
	remote_player.health_component.max_health = 1000000.0
	remote_player.health_component.current_health = 1000000.0

	# 1. Server Grenadier throws Goa'uld Shock Grenade at client -> replicates under FieldKitDeployments
	grenadier._shock_grenade_cooldown = 0.0
	var grenade := grenadier.try_throw_shock_grenade(remote_player.global_position) as GoauldShockGrenade
	assert(grenade != null, "Server Grenadier launched Shock Grenade at remote operative")
	grenade.fuse_remaining = 0.25
	grenade.global_position = remote_player.global_position + Vector3(0.0, 0.35, 0.0)
	grenade.velocity = Vector3.ZERO
	await frames(40)
	assert(await marked("client_saw_grenade"), "Client confirmed Shock Grenade disorientation & HUD flash")

	# 2. Server Goa'uld Boss fires Kara Kesh Telekinetic Push at client -> impulse RPC reaches client
	boss.set_physics_process(true)
	boss.current_target = remote_player
	boss.perception.alert(remote_player, remote_player.global_position)
	boss._publish_awareness()
	boss.rotation.y = atan2(-(remote_player.global_position.x - boss.global_position.x), -(remote_player.global_position.z - boss.global_position.z))
	boss._kara_kesh_push_cd = 0.0
	assert(boss.trigger_kara_kesh_push(), "Boss triggered Kara Kesh Push")
	await frames(50)
	assert(await marked("client_saw_push"), "Client confirmed Kara Kesh push impulse & Boss HUD Bar")

	# 3. Server Boss channels Kara Kesh Beam -> client overloads shield with Zat to interrupt
	boss._kara_kesh_beam_cd = 0.0
	var beam_end_reason := [""]
	boss.kara_kesh_beam_ended.connect(func(reason: String) -> void: beam_end_reason[0] = reason)
	assert(boss.trigger_kara_kesh_beam(remote_player), "Boss triggered Kara Kesh Beam")
	await frames(55)
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.CHANNELING_BEAM, "Boss channeling Kara Kesh Beam")
	# Extend duration slightly so slow CI client Zat shot always lands during channel
	boss._kara_kesh_phase_timer = 15.0
	mark("beam_channeling")

	for _i: int in range(1800):
		await frames(1)
		if is_instance_valid(remote_player) and remote_player.health_component != null:
			remote_player.health_component.current_health = 1000000.0
		if boss.personal_shield.is_overloaded:
			break
	assert(boss.personal_shield.is_overloaded, "Client Zat shot overloaded System Lord shield")
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.IDLE and beam_end_reason[0] == "shield_overloaded",
		"Shield overload interrupted Kara Kesh Beam (reason=%s)" % beam_end_reason[0])

	# Keep overload long enough for late-join observer verification
	boss.personal_shield.overload_timer = 30.0
	boss.set_physics_process(false)
	observer_pid = _spawn_peer("observer", "observer.log")
	assert(observer_pid > 0)
	assert(await marked("observer_verified"), "Late-join observer verified SW-3 roles & overloaded Boss snapshot")
	var old_id := room.get_instance_id()
	mark("observer_can_leave")
	await frames(20)

	assert(await marked("client_done"), "Client finished SW-3 verification")
	if not dedicated_host:
		assert(net.request_restart_game(), "Listen host triggers retry")
	room = await mission(1 if dedicated_host else 2, old_id)
	assert(room.enemies.get_child_count() == 5, "Retry resets enemies cleanly")
	assert(room.get_node("FieldKitDeployments").get_child_count() == 0, "Retry clears all Shock Grenades")
	mark("host_retried")
	assert(await marked("client_retried"), "Client confirmed post-retry state before host shutdown")
	await frames(8)


func run_client() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "SW3 Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", port_number()) == OK)
	var room := await mission()
	assert(await marked("units_ready"))
	var spots: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join("units_ready")))
	var front := Vector3(spots.front[0], spots.front[1], spots.front[2])

	# Wait for all 4 SW-3 units to replicate with accurate combat_role
	for _i: int in range(1800):
		await frames(1)
		if (
			room.enemies.has_node("SW3Boss")
			and room.enemies.has_node("SW3Officer")
			and room.enemies.has_node("SW3Heavy")
			and room.enemies.has_node("SW3Grenadier")
		):
			break
	var boss := room.enemies.get_node("SW3Boss") as JaffaAI
	var officer := room.enemies.get_node("SW3Officer") as JaffaAI
	var heavy := room.enemies.get_node("SW3Heavy") as JaffaAI
	var grenadier := room.enemies.get_node("SW3Grenadier") as JaffaAI
	for _i: int in range(600):
		if (
			boss.is_boss() and boss.personal_shield.is_active()
			and officer.is_officer() and heavy.is_heavy() and grenadier.is_grenadier()
		):
			break
		await frames(1)
	assert(boss.is_boss() and boss.boss_display_name == "SYSTEM LORD ANUBIS", "Boss role & custom name replicated")
	assert(boss.personal_shield.is_active() and boss.personal_shield.aura_mesh.visible, "Boss Personal Shield active on client")
	assert(officer.is_officer() and heavy.is_heavy() and grenadier.is_grenadier(), "Specialist combat_roles replicated to client")

	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	me.global_position = front + Vector3(0.0, 0.05, 0.0)
	me.velocity = Vector3.ZERO
	await frames(10)
	mark("client_positioned")

	# Wait for Shock Grenade disorientation & HUD flash on client
	for _i: int in range(900):
		await frames(1)
		if me.disorientation_timer > 0.0 and room.hud.shock_flash_alpha > 0.0:
			break
	assert(me.disorientation_timer > 0.0 and is_equal_approx(me.disorientation_speed_scale, 0.55),
		"Client received Shock Grenade disorientation slow")
	assert(room.hud.shock_flash_alpha > 0.0, "Client HUD displayed shock flash overlay")
	mark("client_saw_grenade")

	# Reposition cleanly in front of Boss for Kara Kesh Push & verify Boss HUD Bar
	me.global_position = front + Vector3(0.0, 0.05, 0.0)
	me.velocity = Vector3.ZERO
	me.last_external_impulse = Vector3.ZERO
	for _i: int in range(900):
		await frames(1)
		if me.last_external_impulse.length() > 8.0 and room.hud.boss_panel.visible:
			break
	assert(me.last_external_impulse.length() > 8.0, "Client received Kara Kesh Push impulse RPC")
	assert(room.hud.boss_panel.visible and room.hud.boss_name_label.text == "SYSTEM LORD ANUBIS",
		"Client HUD shows Boss Health & Shield Bar")
	mark("client_saw_push")

	# Wait for Kara Kesh Beam channel, then fire Carter's Zat to overload shield & cancel beam
	assert(await marked("beam_channeling"))
	me.switch_slot(2)
	await frames(10)
	for _attempt: int in range(8):
		if boss.personal_shield.is_overloaded:
			break
		me.global_position = front + Vector3(0.0, 0.05, 0.0)
		me.velocity = Vector3.ZERO
		var aim_boss := boss.global_position + Vector3(0.0, 1.05, 0.0)
		me.look_at(Vector3(aim_boss.x, me.global_position.y, aim_boss.z), Vector3.UP)
		me.current_aim_target = aim_boss
		await frames(10)
		if me.current_weapon != null:
			me.current_weapon.fire_cooldown = 0.0
			if "current_heat" in me.current_weapon:
				me.current_weapon.set("current_heat", 0.0)
		me.request_weapon_fire()
		for _w: int in range(30):
			await frames(1)
			if boss.personal_shield.is_overloaded:
				break
	assert(boss.personal_shield.is_overloaded and not boss.personal_shield.is_active(),
		"Client replica updated Boss shield to overloaded after Zat shot")
	await frames(4)
	assert("SHIELD DOWN" in room.hud.boss_shield_label.text, "Client Boss HUD updated to SHIELD DOWN")

	assert(await marked("observer_can_leave"))
	var old_id := room.get_instance_id()
	mark("client_done")
	if dedicated():
		assert(net.request_restart_game(), "Client triggers retry on dedicated server")
	room = await mission(-1, old_id)
	assert(await marked("host_retried"))
	mark("client_retried")
	await frames(8)


func run_observer() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.player_name = "SW3 Observer"
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	assert(net.join_game("127.0.0.1", port_number()) == OK)
	var room := await mission()
	for _i: int in range(1800):
		await frames(1)
		if room.enemies.has_node("SW3Boss") and room.enemies.has_node("SW3Heavy") and room.enemies.has_node("SW3Officer") and room.enemies.has_node("SW3Grenadier"):
			var b := room.enemies.get_node("SW3Boss") as JaffaAI
			if b.is_boss() and b.personal_shield.is_overloaded:
				break
	var boss := room.enemies.get_node("SW3Boss") as JaffaAI
	var heavy := room.enemies.get_node("SW3Heavy") as JaffaAI
	var officer := room.enemies.get_node("SW3Officer") as JaffaAI
	var grenadier := room.enemies.get_node("SW3Grenadier") as JaffaAI
	assert(boss.is_boss() and boss.personal_shield.is_overloaded and not boss.personal_shield.aura_mesh.visible,
		"Late-join observer synced overloaded Goa'uld System Lord snapshot")
	assert(officer.is_officer() and heavy.is_heavy() and grenadier.is_grenadier(),
		"Late-join observer synced all SW-3 specialist combat roles")
	mark("observer_verified")
	assert(await marked("observer_can_leave"))


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_sw3_specialist_enemies_multiplayer.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)
