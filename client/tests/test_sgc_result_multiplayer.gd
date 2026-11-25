extends "res://tests/test_four_player_join_multiplayer.gd"
## Real SGC Defense defeat, post-result joins, and a coordinated retry.


func port() -> int:
	return 19978 if is_dedicated else 19977


func client_script() -> String:
	return "res://tests/test_sgc_result_multiplayer.gd"


func frames(count: int) -> void:
	for i in range(count):
		OS.delay_msec(1)
		await process_frame


func wait_until(condition: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 35000
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return
		await frames(1)
	require(false, message)


func room_ready(previous: int = 0) -> GateRoom:
	await wait_until(func() -> bool:
		var room := main.current_gate_room as GateRoom
		return room != null and room.get_instance_id() != previous and (
			(slot == 0 and is_dedicated) or room.players_container.has_node(str(net.local_peer_id))
		),
		"SGC Defense and its operative are ready"
	)
	return main.current_gate_room as GateRoom


func verify_result(room: GateRoom) -> void:
	var pawn := room.players_container.get_node_or_null(str(net.local_peer_id)) as PlayerController3D
	var guard := room.get_node_or_null("Enemies/ResultGuard") as JaffaAI
	var fixed := room.find_child("TurretWest", true, false) as DeployableTurret
	var tripod := room.get_node_or_null("TurretDeployments/ResultTripod") as DeployableTurret
	require(room.mission_result == 0 and room.wave_manager.mission_ended and room.hud.is_mission_ended)
	require(room.hud.victory_modal.visible and room.hud.debrief_title.text.contains("MISSION FAILED"))
	require(guard != null and guard.health_component.frozen and not guard.is_physics_processing())
	require(fixed != null and not fixed.is_physics_processing() and fixed.mounted_player == null)
	require(tripod != null and not tripod.is_physics_processing() and tripod.mounted_player == null)
	for airman: SGCAirmanAI in room.allies_container.get_children():
		require(airman.health_component.frozen and not airman.is_physics_processing())
	if pawn != null:
		require(pawn.health_component.frozen and not pawn.is_physics_processing())
		require(not pawn.current_weapon.try_fire())


func result_ready(room: GateRoom) -> bool:
	var pawn := room.players_container.get_node_or_null(str(net.local_peer_id)) as PlayerController3D
	var guard := room.get_node_or_null("Enemies/ResultGuard") as JaffaAI
	return room.mission_result == 0 and guard != null and guard.health_component.frozen and (
		(slot == 0 and is_dedicated) or (pawn != null and pawn.health_component.frozen)
	) and room.has_node("TurretDeployments/ResultTripod")


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	if args.has("--roster-child"):
		slot = args[args.find("--roster-child") + 1].to_int()
	is_dedicated = dedicated() or args.has("--pawnless-fixture")
	output_dir = args[args.find("--result-dir") + 1] if slot > 0 else ProjectSettings.globalize_path("res://../build/test-results/sgc-result-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	if slot > 0:
		await run_client()
	else:
		await run_host()
	net.disconnect_game()
	await frames(5)
	mark("exit_%d" % slot)
	print("PASS SGC result cleanup (dedicated=%s slot=%d)" % [is_dedicated, slot])
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	Engine.time_scale = 0.02 # Keep the real staging timer pending during fixture setup.
	net.is_dedicated_server = is_dedicated
	require(net.host_game(port()) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_SGC_DEFENSE))
	net.request_start_game()
	var room := await room_ready()
	spawn_child(1)
	require(await marked("ready_1"))
	require(room._defense_staging_started and not room.wave_manager.defense_started)

	var first := room.players_container.get_node(str(int(read_mark("ready_1")))) as PlayerController3D
	var guard := (load("res://scenes/entities/JaffaGuard.tscn") as PackedScene).instantiate() as JaffaAI
	guard.name = "ResultGuard"
	guard.position = Vector3(0.0, 0.1, -6.0)
	room.get_node("Enemies").add_child(guard, true)
	var fixed := room.find_child("TurretWest", true, false) as DeployableTurret
	var tripod := (load("res://scenes/props/DeployableTurret.tscn") as PackedScene).instantiate() as DeployableTurret
	tripod.name = "ResultTripod"
	tripod.position = room.to_local(first.global_position)
	room.get_node("TurretDeployments").add_child(tripod, true)
	tripod.mount(first)
	require(tripod.mounted_player == first and fixed.is_physics_processing() and guard.is_physics_processing())

	var bolt := (load("res://scenes/entities/PlasmaBolt.tscn") as PackedScene).instantiate() as PlasmaBolt
	root.add_child(bolt)
	bolt.initialize(room.global_position + Vector3.UP * 10.0, Vector3.FORWARD, guard)
	var satchel := (load("res://scenes/props/C4Satchel.tscn") as PackedScene).instantiate() as C4Satchel
	satchel.set_timer_mode(5.0)
	room.get_node("FieldKitDeployments").add_child(satchel, true)
	var mine := (load("res://scenes/props/ClaymoreMine.tscn") as PackedScene).instantiate() as ClaymoreMine
	room.get_node("FieldKitDeployments").add_child(mine, true)
	var late_shots := [0]
	fixed.turret_fired.connect(func(_a: Vector3, _b: Vector3) -> void: late_shots[0] += 1)
	guard.staff_fired.connect(func(_a: Vector3, _b: Vector3) -> void: late_shots[0] += 1)
	room.wave_manager.pending_column_spawns = 3
	for pawn: PlayerController3D in room.players_container.get_children():
		pawn.health_component.take_damage(5000, null, "bullet")
	verify_result(room)
	require(first.health_component.is_downed and first.mounted_turret == null)
	require(not fixed.try_manual_fire(Vector3.FORWARD) and not tripod.try_manual_fire(Vector3.FORWARD))
	require(bolt.is_queued_for_deletion() and satchel.is_queued_for_deletion() and mine.is_queued_for_deletion())
	var guard_position := guard.global_position
	var guard_hp := guard.health_component.current_health
	guard.health_component.take_damage(5000)
	require(guard.health_component.current_health == guard_hp)
	room.conclude(true)
	require(room.mission_result == 0, "A second result cannot replace defeat")

	var count := 4 if is_dedicated else 3
	for index in range(2, count + 1):
		spawn_child(index)
	for index in range(1, count + 1):
		require(await marked("finished_%d" % index))
	require(room.players_container.get_child_count() == 4)
	for pawn: PlayerController3D in room.players_container.get_children():
		require(pawn.health_component.frozen and not pawn.is_physics_processing())
	Engine.time_scale = 1.0
	await create_timer(7.0).timeout
	require(not room.wave_manager.defense_started and room.wave_manager.pending_column_spawns == 0)
	require(guard.global_position.is_equal_approx(guard_position) and late_shots[0] == 0)
	require(not is_instance_valid(bolt) and not is_instance_valid(satchel) and not is_instance_valid(mine))

	var previous := room.get_instance_id()
	require(net.request_restart_game())
	room = await room_ready(previous)
	for index in range(1, count + 1):
		require(await marked("retried_%d" % index))
	require(room.mission_result == -1 and not room.wave_manager.mission_ended)
	require((room.find_child("TurretWest", true, false) as DeployableTurret).is_physics_processing())
	require(not room.has_node("Enemies/ResultGuard") and not room.has_node("TurretDeployments/ResultTripod"))
	for index in range(1, count + 1):
		mark("leave_%d" % index)
		require(await marked("exit_%d" % index))
		await wait_until(func() -> bool: return not OS.is_process_running(children[index - 1]), "Client %d exits cleanly" % index)
		var log := FileAccess.get_file_as_string(output_dir.path_join("client_%d.log" % index))
		require(log.contains("PASS SGC result cleanup") and not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Result %d" % slot
	net.selected_class_id = CLASSES[slot - 1]
	require(net.join_game("127.0.0.1", port()) == OK)
	var room := await room_ready()
	mark("ready_%d" % slot, net.local_peer_id)
	await wait_until(func() -> bool: return result_ready(room), "Result, stopped threats and frozen operative arrive")
	verify_result(room)
	mark("finished_%d" % slot)
	room = await room_ready(room.get_instance_id())
	var pawn := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	require(not pawn.health_component.frozen and not pawn.health_component.is_downed and pawn.is_physics_processing())
	require(room.mission_result == -1 and not room.hud.is_mission_ended)
	mark("retried_%d" % slot)
	require(await marked("leave_%d" % slot))
