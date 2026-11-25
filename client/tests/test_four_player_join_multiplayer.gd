extends SceneTree
## Real processes, full operative roster, deliberately delayed loads, split-world travel,
## connected retry and replacement late join after retry. The dedicated variant has four
## remote operatives plus its pawnless server; the listen host is one of four operatives.
const DelayedCoordinator = preload("res://tests/support/delayed_mission_coordinator.gd")
const MISSION := SGCNetworkManager.MISSION_TRAVEL_INFILTRATION
const CLASSES: Array[String] = ["carter_tech", "oneill_recon", "tealc_jaffa", "sg3_heavy"]
var net: SGCNetworkManager
var main: MainGameCoordinator
var output_dir: String
var slot := 0
var generation := 0
var children: Array[int] = []
var ids: Array[int] = []
var is_dedicated := false


func _init() -> void:
	call_deferred("run")


func require(condition: bool, message: String = "Fixture requirement failed") -> void:
	if condition:
		return
	push_error(message)
	mark("failure", message)
	for pid: int in children:
		if OS.is_process_running(pid):
			OS.kill(pid)
	quit(1)


func dedicated() -> bool:
	return false


func port() -> int:
	return 19934 if is_dedicated else 19933


func frames(count: int) -> void:
	for i in range(count):
		if is_instance_valid(main):
			for world: GateRoom in main.worlds():
				var mine := world.players_container.get_node_or_null(str(net.local_peer_id)) as PlayerController3D
				if mine != null:
					mine.set_physics_process(false)
				if net.is_server:
					for actor: PlayerController3D in world.players_container.get_children():
						actor.health_component.frozen = true
					if world is ModularMission and (world as ModularMission).is_started:
						(world as ModularMission).alert.set_physics_process(false)
						for enemy: JaffaAI in (world as ModularMission).enemies.get_children():
							enemy.stand_down()
		OS.delay_msec(1)
		await process_frame


func mark(label: String, value: Variant = true) -> void:
	var target := output_dir.path_join(label)
	var temporary := target + ".tmp." + str(OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
	DirAccess.rename_absolute(temporary, target)


func exists(label: String) -> bool:
	return FileAccess.file_exists(output_dir.path_join(label))


func read_mark(label: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join(label)))


func marked(label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		if exists("failure"):
			quit(1)
			return false
		if exists(label):
			return true
		await frames(1)
	if slot == 0:
		for file: String in DirAccess.get_files_at(output_dir):
			if file.ends_with(".log"):
				print(FileAccess.get_file_as_string(output_dir.path_join(file)))
	require(false, "Missing barrier: " + label)
	return false


func before_load() -> void:
	generation += 1
	mark("loading_%d_%d" % [slot, generation], net.local_peer_id)
	require(await marked("load_%d_%d" % [slot, generation]))


func worlds(previous: int = 0) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var home := main.current_gate_room as GateRoom
		var site := main.current_site as ModularMission
		if home != null and site != null and site.is_started and home.get_instance_id() != previous:
			var mine := home.players_container.get_node_or_null(str(net.local_peer_id))
			if (slot == 0 and is_dedicated) or mine != null:
				require(site.setup_errors.is_empty() and site.level.last_errors.is_empty())
				return
		await frames(1)
	require(false, "Two worlds and own operative did not start")


func child_display_args(_index: int) -> PackedStringArray:
	return PackedStringArray(["--headless"])


func spawn_child(index: int) -> int:
	var args := child_display_args(index)
	args.append_array(PackedStringArray([
		"--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output_dir.path_join("client_%d.log" % index),
		"--script", client_script(),
		"--", "--roster-child", str(index), "--result-dir", output_dir
	]))
	if is_dedicated:
		args.append("--pawnless-fixture")
	var pid := OS.create_process(OS.get_executable_path(), args)
	require(pid > 0)
	children.append(pid)
	return pid


func client_script() -> String:
	return "res://tests/test_four_player_join_multiplayer.gd"


func travel(id: int) -> void:
	var home := main.current_gate_room as GateRoom
	var gate := home.stargate_mesh
	if gate.current_state == StargateRing.GateState.INACTIVE:
		require(gate.reserve_connection(false))
		gate.authorize_extraction()
		for chevron in range(1, 8):
			gate.lock_chevron(chevron)
		var deadline := Time.get_ticks_msec() + 15000
		while gate.current_state != StargateRing.GateState.ACTIVE and Time.get_ticks_msec() < deadline:
			await frames(1)
		require(gate.current_state == StargateRing.GateState.ACTIVE)
	var actor := home.players_container.get_node(str(id)) as PlayerController3D
	gate._on_extraction_entered(actor)
	var arrival_deadline := Time.get_ticks_msec() + 15000
	while not main.current_site.get_node("Players").has_node(str(id)) and Time.get_ticks_msec() < arrival_deadline:
		await frames(1)
	require(not home.players_container.has_node(str(id)))
	require(main.current_site.get_node("Players").has_node(str(id)))


func snapshot(label: String, active_slots: Array[int], expected_count: int = 4) -> void:
	# Server expectations are read by clients, but never applied to their replicas.
	var expected: Dictionary = {}
	for w in range(2):
		var world := main.worlds()[w] as GateRoom
		for actor: PlayerController3D in world.players_container.get_children():
			check_imported_loadout(actor)
			expected[str(actor.peer_id)] = {"world": w, "class": actor.class_id, "slot": actor.active_slot,
				"position": [actor.position.x, actor.position.y, actor.position.z],
				"health": actor.health_component.current_health, "crouching": actor.is_crouching}
	require(expected.size() == expected_count, "Exactly the expected operative identities across both worlds")
	require(not is_dedicated or not expected.has("1"), "Dedicated host remains pawnless")
	mark("snapshot_" + label, expected)
	for index in active_slots:
		require(await marked("seen_%s_%d" % [label, index]))


func see_snapshot(label: String) -> void:
	require(await marked("snapshot_" + label))
	var expected: Dictionary = read_mark("snapshot_" + label)
	var correct := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		correct = true
		var count := 0
		for w in range(2):
			var world := main.worlds()[w] as GateRoom
			for actor: PlayerController3D in world.players_container.get_children():
				count += 1
				var item: Dictionary = expected.get(str(actor.peer_id), {})
				if item.is_empty():
					correct = false
					continue
				var xyz: Array = item.position
				correct = correct and int(item.world) == w and item["class"] == actor.class_id
				correct = correct and int(item.slot) == actor.active_slot
				correct = correct and actor.position.distance_to(Vector3(xyz[0], xyz[1], xyz[2])) < 0.1
				correct = correct and is_equal_approx(float(item.health), actor.health_component.current_health)
				correct = correct and bool(item.crouching) == actor.is_crouching
		correct = correct and count == expected.size()
		if correct:
			break
		await frames(1)
	require(correct, "Roster/class/health/motion mismatch: " + label)
	for world: GateRoom in main.worlds():
		for actor: PlayerController3D in world.players_container.get_children():
			check_imported_loadout(actor)
	var own_world := int(expected[str(net.local_peer_id)].world)
	require(main.session.presented == main.worlds()[own_world], "Each operative presents its own world")
	require((main.current_site as ModularMission).events.fired.is_empty())
	mark("seen_%s_%d" % [label, slot])


func check_imported_loadout(actor: PlayerController3D) -> void:
	var rig := actor.get_node(^"Visuals/SquadRig")
	require(rig.skeleton != null and rig.skin_visual.visible and not actor.body_mesh.visible,
		"Every squad member uses the shared skin, including remote spawns and replacements")
	var has_radio: bool = rig.recon_mount != null and rig.recon_mount.visible
	require(has_radio == (actor.class_id == SGCNetworkManager.CLASS_ONEILL_RECON),
		"Only O’Neill Recon carries the radio, including after travel and retry")
	if actor.active_slot == 2 and actor.class_id in [
		SGCNetworkManager.CLASS_CARTER_TECH, SGCNetworkManager.CLASS_TEALC_JAFFA
	]:
		var zat := actor.current_weapon as WeaponZat
		require(zat != null and zat.muzzle_point.position.is_equal_approx(Vector3(0, 0.05, -0.20)),
			"Zat secondary keeps its emitter and slot on each replica")
		require(zat.has_node("WeaponModel/ImportedGLB/ZatBody"), "Original Zat mesh on secondary")
		return
	if actor.class_id == SGCNetworkManager.CLASS_TEALC_JAFFA:
		var staff := actor.current_weapon as WeaponStaff
		require(staff != null and staff.muzzle_point.position.is_equal_approx(Vector3(0, 0, -1.05)),
			"Teal'c keeps the staff and muzzle through replica builds")
		require(staff.has_node("WeaponModel/ImportedGLB/StaffBody"), "Original staff mesh on Teal'c replica")
		return
	if actor.class_id != SGCNetworkManager.CLASS_CARTER_TECH:
		return
	var gun := actor.current_weapon as WeaponMP5
	require(gun != null and gun.muzzle_point.position.is_equal_approx(Vector3(0, 0.01, -0.36)), "Carter keeps MP5 and muzzle")
	var imported := gun.get_node_or_null("WeaponModel/ImportedGLB")
	require(imported != null and imported.has_node("MP5SD_Obj"), "Imported MP5SD survives " + str(actor.get_path()))
	var mesh := imported.get_node("MP5SD_Obj") as MeshInstance3D
	var triangles := 0
	for surface in range(mesh.mesh.get_surface_count()):
		triangles += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	require(triangles == 10669, "Real MP5SD body on each Carter replica")


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/roster-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	if slot > 0:
		main.set_script(DelayedCoordinator)
		main.set("before_load", before_load)
		# An old scene-ready reply can cross preparation. It must not authorize spawns
		# into the replacement world while this peer is deliberately still loading.
		net.mission_restart_preparing.connect(func() -> void: net.report_mission_ready.rpc_id(1))
	root.add_child(main)
	if slot > 0:
		await run_client()
	else:
		await run_host()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	mark("exit_%d" % slot)
	print("PASS four-operative roster, delayed loads, travel and retry (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(MISSION))
	net.request_start_game()
	await worlds()
	var count := 4 if is_dedicated else 3
	var active: Array[int] = []
	for index in range(1, count + 1):
		spawn_child(index)
		require(await marked("loading_%d_1" % index))
		var id := int(read_mark("loading_%d_1" % index))
		ids.append(id)
		require(not net.mission_ready_peers.has(id), "A transport connection is not mission readiness")
		require(not main.current_gate_room.get_node("Players").has_node(str(id)))
		if index == 2:
			# First remote operative changes world while the next late peer has no worlds.
			await travel(ids[0])
		await frames(30)
		mark("load_%d_1" % index)
		require(await marked("ready_%d_1" % index))
		if index == 1:
			var actor := (main.current_gate_room as GateRoom).players_container.get_node(str(id)) as PlayerController3D
			actor.health_component.frozen = false
			actor.health_component.take_damage(13.0)
			actor.health_component.frozen = true
		active.append(index)
	await travel(ids[2]) # Prove Teal'c builds the same staff visual at the destination.
	await frames(30)
	await snapshot("split", active)
	# Client-owned movement must still replicate to the server and every other client.
	mark("move")
	require(await marked("moved"))
	var moving := (main.current_site as GateRoom).players_container.get_node(str(ids[0])) as PlayerController3D
	var target: Array = read_mark("moved")
	var movement_deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < movement_deadline:
		if moving.is_crouching and moving.position.distance_to(Vector3(target[0], target[1], target[2])) < 0.05:
			break
		await frames(1)
	require(moving.is_crouching and moving.position.distance_to(Vector3(target[0], target[1], target[2])) < 0.05)
	moving.switch_slot(2)
	var tealc := (main.current_site as GateRoom).players_container.get_node(str(ids[2])) as PlayerController3D
	tealc.switch_slot(2)
	await snapshot("motion", active)
	var previous := main.current_gate_room.get_instance_id()
	require(net.request_restart_game())
	for index in active:
		require(await marked("loading_%d_2" % index))
		require(not net.mission_ready_peers.has(ids[index - 1]), "Old readiness cannot authorize the retry world")
		mark("load_%d_2" % index)
		require(await marked("ready_%d_2" % index))
	await worlds(previous)
	await frames(30)
	var carter := (main.current_gate_room as GateRoom).players_container.get_node(str(ids[0])) as PlayerController3D
	require(carter.active_slot == 1 and carter.current_weapon is WeaponMP5, "Retry rebuilds the primary loadout")
	await snapshot("retry", active)
	# Free one operative slot, then late join after retry while an existing player travels.
	mark("leave_%d" % count)
	require(await marked("exit_%d" % count))
	for i in range(1800):
		if not net.peers.has(ids[-1]):
			break
		await frames(1)
	require(not net.peers.has(ids[-1]))
	active.erase(count)
	var replacement := count + 1
	spawn_child(replacement)
	require(await marked("loading_%d_1" % replacement))
	carter.switch_slot(2)
	await travel(ids[0])
	var traveled := (main.current_site as GateRoom).players_container.get_node(str(ids[0])) as PlayerController3D
	require(traveled.active_slot == 2 and traveled.current_weapon is WeaponZat, "Travel carries the Zat secondary")
	mark("load_%d_1" % replacement)
	require(await marked("ready_%d_1" % replacement))
	active.append(replacement)
	await frames(30)
	await snapshot("rejoined", active)
	previous = main.current_gate_room.get_instance_id()
	require(net.request_restart_game())
	for index in active:
		var epoch := 2 if index == replacement else 3
		require(await marked("loading_%d_%d" % [index, epoch]))
		var id := int(read_mark("loading_%d_1" % index))
		require(not net.mission_ready_peers.has(id), "Replacement peers also load before retry spawning")
		mark("load_%d_%d" % [index, epoch])
		require(await marked("ready_%d_%d" % [index, epoch]))
	await worlds(previous)
	await frames(30)
	await snapshot("second_retry", active)
	for index in active:
		mark("leave_%d" % index)
		require(await marked("exit_%d" % index))
		var id := int(read_mark("loading_%d_1" % index))
		var deadline := Time.get_ticks_msec() + 15000
		while net.peers.has(id) and Time.get_ticks_msec() < deadline:
			await frames(1)
		require(not net.peers.has(id))
		await frames(10)
	await frames(40)
	for file: String in DirAccess.get_files_at(output_dir):
		if file.ends_with(".log"):
			var log := FileAccess.get_file_as_string(output_dir.path_join(file))
			require(not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func class_for_slot(index: int) -> String:
	return CLASSES[(index - 1) % CLASSES.size()]


func run_client() -> void:
	net.player_name = "Roster %d" % slot
	net.selected_class_id = class_for_slot(slot)
	require(net.join_game("127.0.0.1", port()) == OK)
	await worlds()
	mark("ready_%d_1" % slot)
	var replacement := slot > (4 if is_dedicated else 3)
	if not replacement:
		await see_snapshot("split")
		if slot == 1:
			require(await marked("move"))
			var actor := (main.current_site as GateRoom).players_container.get_node(str(net.local_peer_id)) as PlayerController3D
			actor.position += Vector3(0.4, 0, 0.6)
			actor.is_crouching = true
			mark("moved", [actor.position.x, actor.position.y, actor.position.z])
		await see_snapshot("motion")
		var previous := main.current_gate_room.get_instance_id()
		await worlds(previous)
		mark("ready_%d_2" % slot)
		await see_snapshot("retry")
		if slot == (4 if is_dedicated else 3):
			require(await marked("leave_%d" % slot))
			return
	await see_snapshot("rejoined")
	var previous := main.current_gate_room.get_instance_id()
	await worlds(previous)
	mark("ready_%d_%d" % [slot, generation])
	await see_snapshot("second_retry")
	require(await marked("leave_%d" % slot))
