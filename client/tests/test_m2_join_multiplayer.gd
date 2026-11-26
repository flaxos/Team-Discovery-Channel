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
	if index == 4:
		return SGCNetworkManager.CLASS_ONEILL_RECON if is_dedicated else SGCNetworkManager.CLASS_TEALC_JAFFA
	if index == 5:
		return SGCNetworkManager.CLASS_ONEILL_RECON
	return super.class_for_slot(index)


func run_host() -> void:
	net.selected_class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	await super.run_host()


func check_m2(turret: DeployableTurret, id: int) -> bool:
	if turret == null or not turret.has_node("TurretHead/M2Gun") or not turret.has_node("M2Tripod"):
		return false
	if not is_instance_valid(turret.mounted_player) or turret.mounted_player.name != str(id):
		return false
	if absf(turret.turret_head.rotation.y) <= 1.57 or not operator_behind_gun(turret):
		return false
	var rig := turret.mounted_player.get_node(^"Visuals/SquadRig") as Node3D
	if rig.pose != &"aim_crouch_idle":
		return false
	var right: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
	var left: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[2], rig.grip_bones[3]))
	return right.distance_to(turret.right_grip.global_position) < 0.04 \
		and left.distance_to(turret.left_grip.global_position) < 0.04


func operator_behind_gun(turret: DeployableTurret) -> bool:
	var actor := turret.mounted_player as PlayerController3D
	var rear := turret.turret_head.global_basis.z
	return actor != null and not actor.weapon_holder.visible \
		and (actor.global_position - turret.global_position).distance_to(rear * DeployableTurret.GUNNER_REAR_OFFSET) < 0.01 \
		and actor.visuals.global_basis.z.dot(rear) > 0.99


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
	require(turret.global_position.is_equal_approx(Vector3(0, 0.05, 2.9)), "Existing deployment offset")
	require(operator_behind_gun(turret), "Server places the remote operative behind the gun as soon as they mount")
	turret.turret_fired.connect(func(origin: Vector3, _direction: Vector3) -> void: shot_origins.append(origin))
	mark("m2_fire")
	deadline = Time.get_ticks_msec() + 15000
	while shot_origins.is_empty() and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(shot_origins.size() == 1 and shot_origins[0].is_equal_approx(turret.muzzle_point.global_position),
		"Remote input produces one authoritative shot from the existing marker")
	if not await marked("m2_turned"):
		return
	deadline = Time.get_ticks_msec() + 15000
	while not check_m2(turret, id) and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(check_m2(turret, id), "The remote operative follows a turn past 90 degrees on the server")


func see_snapshot(label: String) -> void:
	await super.see_snapshot(label)
	if label == "retry" and slot == SHOOTER_SLOT:
		await client_deploy_and_mount()
	if label == "rejoined":
		var path := NodePath(str(read_mark("m2_deploy")))
		var id := int(read_mark("m2_mounted"))
		var deadline := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			var turret := main.current_gate_room.get_node_or_null(path) as DeployableTurret
			if check_m2(turret, id):
				print("M2_JOIN: observer ", slot, " received occupied and aimed M2")
				return
			await frames(1)
		require(false, "Every observer must see the deployed visual, occupant and aim")
	elif label == "second_retry":
		require(main.current_gate_room.get_node("TurretDeployments").get_child_count() == 0, "Every client sees an empty deployment list after retry")


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
		turret.receive_player_input(turret.global_position + Vector3(10, 0.75, 5), true)
		deadline = Time.get_ticks_msec() + 15000
		while not check_m2(turret, net.local_peer_id) and Time.get_ticks_msec() < deadline:
			await frames(1)
		require(check_m2(turret, net.local_peer_id), "The owner stays behind and faces the gun after the turn")
		mark("m2_turned")
