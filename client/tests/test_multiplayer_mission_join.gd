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

func check_armoury(room: GateRoom) -> void:
	var sector := room.get_node(^"Level28Complex/ArmorySector")
	var crate := sector.get_node(^"AmmoCrate1") as ArmoryResupplyStation
	var rack := sector.get_node(^"WeaponRackNorth") as ArmoryResupplyStation
	assert(crate.crate_visual != null and rack.occlusion_visual != null,
		"A loaded client dresses the ammo and loadout stations")
	assert(sector.has_node(^"ArmoryArmorStation/ImportedShelf"), "A loaded client fits the re-armour shelf")
	assert(room.has_node(^"SGCMap/STAGINGCover/ReplacementVisual") and room.has_node(^"SGCMap/SupplyRack1/ReplacementVisual"),
		"A loaded client dresses both Level 26 medical slots")

func wait_for_airman_pose(room: GateRoom, expected: StringName) -> bool:
	var airman := room.get_node(^"Allies/AirmanDavis") as SGCAirmanAI
	var rig := airman.get_node(^"Visuals/AirmanRig")
	for _step in range(180):
		if rig.pose == expected and rig.skeleton != null and not airman.get_node(^"Visuals/BodyMesh").visible:
			return true
		await frames(1)
	return false

func wait_for_mounted_airman(room: GateRoom) -> bool:
	var airman := room.get_node(^"Allies/AirmanSiler") as SGCAirmanAI
	var turret := room.get_node(^"BunkerGeometry/TurretEast") as DeployableTurret
	var rig := airman.get_node(^"Visuals/AirmanRig")
	for _step in range(180):
		if airman.mounted_turret == turret and turret.mounted_player == airman and turret.turret_head.rotation.y > 1.57:
			var right: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
			var left: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[2], rig.grip_bones[3]))
			if not rig.weapon_model.visible and right.distance_to(turret.right_grip.global_position) < 0.035 and left.distance_to(turret.left_grip.global_position) < 0.035:
				return true
		await frames(1)
	return false

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
		check_armoury(room)
		assert(await wait_for_airman_pose(room, &"downed"), "A late client shows the current downed Airman pose")
		assert(await wait_for_mounted_airman(room), "A late client places both hands on the occupied M2")
		mark("joined")
		for _i: int in range(1200):
			await frames(1)
			if main.current_gate_room != room:
				break
		assert(main.current_gate_room != room, "Host retry must replace client world")
		await frames(60)
		assert(main.current_gate_room.get_node("Players").has_node(str(net.local_peer_id)), "Retry must respawn the client at canonical paths")
		check_armoury(main.current_gate_room)
		assert(await wait_for_airman_pose(main.current_gate_room, &"ready_idle"), "Retry shows the new standing Airman")
		var retry_siler := main.current_gate_room.get_node(^"Allies/AirmanSiler") as SGCAirmanAI
		assert(retry_siler.mounted_turret == null, "Retry clears the old Airman mount")
		mark("retried")
	else:
		var room := main.current_gate_room as GateRoom
		room.wave_manager.set_physics_process(false)
		room.wave_manager.defense_started = true
		room.wave_manager.completed_incursions = 3
		room.wave_manager.computer_upgraded = true
		var airman := room.get_node(^"Allies/AirmanDavis") as SGCAirmanAI
		airman.health_component.take_damage(400)
		var siler := room.get_node(^"Allies/AirmanSiler") as SGCAirmanAI
		var turret := room.get_node(^"BunkerGeometry/TurretEast") as DeployableTurret
		siler.mount_turret(turret)
		turret.turret_head.rotation.y = 1.98
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
