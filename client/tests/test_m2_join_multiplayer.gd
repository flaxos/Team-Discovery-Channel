extends "res://tests/test_four_player_join_multiplayer.gd"
## Real remote deployment and mount before a replacement joins during travel.

const SHOOTER_SLOT := 2
var deployed_path: NodePath
var shot_origins: Array[Vector3] = []


func port() -> int:
	return 19951 if is_dedicated else 19950


func client_script() -> String:
	return "res://tests/test_m2_join_multiplayer.gd"


func class_for_slot(index: int) -> String:
	if index == SHOOTER_SLOT:
		return SGCNetworkManager.CLASS_SG3_HEAVY
	return super.class_for_slot(index)


func check_m2(turret: DeployableTurret, id: int) -> bool:
	return turret != null and turret.has_node("TurretHead/M2Gun") and turret.has_node("M2Tripod") \
		and is_instance_valid(turret.mounted_player) and turret.mounted_player.name == str(id) \
		and absf(turret.turret_head.rotation.y) > 0.1


func snapshot(label: String, active_slots: Array[int], expected_count: int = 4) -> void:
	await super.snapshot(label, active_slots, expected_count)
	if label == "retry":
		await host_check_deployment()
	elif label == "rejoined":
		var turret := main.current_gate_room.get_node_or_null(deployed_path) as DeployableTurret
		require(check_m2(turret, ids[SHOOTER_SLOT - 1]), "Server retains mounted M2 and aim across late join")
	elif label == "second_retry":
		require(main.current_gate_room.get_node("TurretDeployments").get_child_count() == 0, "Retry clears deployed M2s")


func host_check_deployment() -> void:
	if not await marked("m2_positioned"):
		return
	var room := main.current_gate_room as GateRoom
	var id := ids[SHOOTER_SLOT - 1]
	var actor := room.players_container.get_node(str(id)) as PlayerController3D
	var deadline := Time.get_ticks_msec() + 15000
	while actor.global_position.distance_to(Vector3(0, 0.05, 4.5)) > 0.01 and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(actor.global_position.distance_to(Vector3(0, 0.05, 4.5)) <= 0.01, "Server sees remote deployer's position")
	deployed_path = NodePath("TurretDeployments/DeployedM2_" + str(id))
	mark("m2_deploy", String(deployed_path))
	if not await marked("m2_mounted"):
		return
	var turret := room.get_node(deployed_path) as DeployableTurret
	require(turret.mounted_player == actor and actor.mounted_turret == turret, "Mount admitted on the server")
	require(is_equal_approx(turret.global_position.distance_to(actor.global_position), 1.6), "Existing deployment offset")
	turret.turret_fired.connect(func(origin: Vector3, _direction: Vector3) -> void: shot_origins.append(origin))
	mark("m2_fire")
	deadline = Time.get_ticks_msec() + 15000
	while shot_origins.is_empty() and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(shot_origins.size() == 1 and shot_origins[0].is_equal_approx(turret.muzzle_point.global_position),
		"Remote input produces one authoritative shot from the existing marker")


func see_snapshot(label: String) -> void:
	await super.see_snapshot(label)
	if label == "retry" and slot == SHOOTER_SLOT:
		await client_deploy_and_mount()
	var replacement := slot > (4 if is_dedicated else 3)
	if replacement and label == "rejoined":
		var path := NodePath(str(read_mark("m2_deploy")))
		var id := int(read_mark("m2_mounted"))
		var deadline := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			var turret := main.current_gate_room.get_node_or_null(path) as DeployableTurret
			if check_m2(turret, id):
				print("M2_JOIN: replacement received occupied and aimed M2")
				return
			await frames(1)
		require(false, "Replacement must see deployed visual, occupant and aim")
	elif replacement and label == "second_retry":
		require(main.current_gate_room.get_node("TurretDeployments").get_child_count() == 0, "Replacement sees an empty deployment list after retry")


func client_deploy_and_mount() -> void:
	var room := main.current_gate_room as GateRoom
	var actor := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	actor.global_position = Vector3(0, 0.05, 4.5)
	actor.rotation.y = 0.0
	mark("m2_positioned")
	if not await marked("m2_deploy"):
		return
	actor._deploy_tactical_gadget()
	var path := NodePath(str(read_mark("m2_deploy")))
	var turret: DeployableTurret
	var deadline := Time.get_ticks_msec() + 15000
	while turret == null and Time.get_ticks_msec() < deadline:
		await frames(1)
		turret = room.get_node_or_null(path) as DeployableTurret
	if turret == null:
		require(false, "Deployment appears on the owning client")
		return
	actor._try_interact()
	deadline = Time.get_ticks_msec() + 15000
	while actor.mounted_turret != turret and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(actor.mounted_turret == turret, "Owner receives mount confirmation")
	mark("m2_mounted", net.local_peer_id)
	if await marked("m2_fire"):
		turret.receive_player_input(turret.global_position + Vector3(5, 0.75, -10), true)
