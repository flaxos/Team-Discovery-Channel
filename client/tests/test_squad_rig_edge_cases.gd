extends SceneTree
## Milestone 2: Verify SGCSquadVisual / SGCHumanRig / SGCAirmanVisual animation edge cases:
## 1. Dragging a body switches rescuer to crouch_idle / crouch_walk with held weapon hidden.
## 2. IrisServoHousing reference refreshes across split-world Stargate travel.
## 3. Late-join health snapshots snap one-shot death animations directly to final frame.

const SGC_BASE := preload("res://scenes/main/SGCUATBase.tscn")
const OFFWORLD := preload("res://scenes/mission/GoauldInfiltrationMission.tscn")
const PLAYER := preload("res://scenes/entities/Player.tscn")
const AIRMAN := preload("res://scenes/entities/SGCAirman.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var sgc := SGC_BASE.instantiate() as GateRoom
	root.add_child(sgc)
	await (sgc.get_node(^"SGCMap") as SGCMap).navigation_ready

	# 1. Body-drag pose & held weapon visibility + snapshot death snap.
	var rescuer := PLAYER.instantiate() as PlayerController3D
	rescuer.name = "Rescuer"
	rescuer.class_id = SGCNetworkManager.CLASS_CARTER_TECH
	rescuer.position = Vector3(14, 11.02, 20)
	sgc.players_container.add_child(rescuer)
	rescuer.set_physics_process(false)
	var r_rig := rescuer.get_node(^"Visuals/SquadRig")

	var patient := PLAYER.instantiate() as PlayerController3D
	patient.name = "Patient"
	patient.class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	patient.position = Vector3(14.5, 11.02, 20)
	sgc.players_container.add_child(patient)
	patient.set_physics_process(false)
	rescuer.player_downed.disconnect(sgc._check_squad_status)
	rescuer.player_died.disconnect(sgc._check_squad_status)
	patient.player_downed.disconnect(sgc._check_squad_status)
	patient.player_died.disconnect(sgc._check_squad_status)

	rescuer.start_dragging_body(patient)
	assert(rescuer.is_dragging_body)
	r_rig._process(1.0 / 60.0)
	assert(r_rig.pose == &"crouch_idle", "Stationary drag uses crouch_idle, got " + str(r_rig.pose))
	assert(not rescuer.current_weapon.get_node(^"WeaponModel").visible, "Weapon hidden while dragging")
	rescuer.position.x += 0.08
	r_rig._process(1.0 / 60.0)
	assert(r_rig.pose == &"crouch_walk", "Moving drag uses crouch_walk, got " + str(r_rig.pose))
	rescuer.stop_dragging_body()
	r_rig.ground_speed = 0.0
	r_rig.previous_position = rescuer.global_position
	r_rig._process(1.0 / 60.0)
	assert(r_rig.pose == &"ready_idle" and rescuer.current_weapon.get_node(^"WeaponModel").visible)

	# 2. Late-join dead snapshot snaps immediately to animation end on Player & Airman.
	patient.health_component.sync_health_state({
		"revision": 1, "health": 0.0, "maximum": 120.0,
		"dead": true, "downed": false, "stunned": false, "vaporized": false,
		"stun_timer": 0.0, "bleedout_timer": 0.0, "zat_hits": 0, "zat_window": 0.0,
	}, "", 0.0, NodePath())
	var p_rig := patient.get_node(^"Visuals/SquadRig")
	p_rig._process(0.016)
	assert(p_rig.pose == &"death" and is_equal_approx(p_rig.animation.current_animation_position, p_rig.animation.current_animation_length),
		"Late-join dead operative snaps to end")

	var dead_airman := AIRMAN.instantiate() as SGCAirmanAI
	dead_airman.position = Vector3(15, 11.02, 20)
	sgc.allies_container.add_child(dead_airman)
	dead_airman.set_physics_process(false)
	dead_airman.health_component.sync_health_state({
		"revision": 1, "health": 0.0, "maximum": 100.0,
		"dead": true, "downed": false, "stunned": false, "vaporized": false,
		"stun_timer": 0.0, "bleedout_timer": 0.0, "zat_hits": 0, "zat_window": 0.0,
	}, "", 0.0, NodePath())
	var a_rig := dead_airman.get_node(^"Visuals/AirmanRig")
	a_rig._process(0.016)
	assert(a_rig.pose == &"death" and is_equal_approx(a_rig.animation.current_animation_position, a_rig.animation.current_animation_length),
		"Late-join dead Airman snaps to end")

	# 3. IrisServoHousing refreshes dynamically across split-world travel.
	var offworld := OFFWORLD.instantiate() as ModularMission
	offworld.position = Vector3(2000, 0, 0)
	root.add_child(offworld)
	while not offworld.is_started:
		await process_frame
	var off_carter := PLAYER.instantiate() as PlayerController3D
	off_carter.name = "9001"
	off_carter.class_id = SGCNetworkManager.CLASS_CARTER_TECH
	offworld.players_container.add_child(off_carter, true)
	off_carter.set_physics_process(false)
	await process_frame
	assert(off_carter.get_node(^"Visuals/SquadRig").iris_servo == null, "Offworld has no SGC IrisServoHousing")

	var servo := sgc.get_node(^"IrisServoHousing") as IrisServoHousing
	rescuer.global_position = servo.to_global(Vector3(0, 0.01, 0.63))
	rescuer.global_rotation.y = servo.global_rotation.y
	r_rig.previous_position = rescuer.global_position
	r_rig.ground_speed = 0.0
	r_rig.rotation = Vector3.ZERO
	r_rig.iris_servo = null
	servo.start_repair(rescuer)
	for frame in range(12):
		r_rig._process(1.0 / 60.0)
	assert(r_rig.iris_servo == servo, "iris_servo resolves on SGC")
	assert(not rescuer.current_weapon.get_node(^"WeaponModel").visible, "Carter hides weapon while repairing iris")

	var stale_servo := IrisServoHousing.new()
	offworld.add_child(stale_servo)
	r_rig.iris_servo = stale_servo
	r_rig._process(1.0 / 60.0)
	assert(r_rig.iris_servo == servo, "iris_servo must refresh across split worlds after travel")
	assert(not rescuer.current_weapon.get_node(^"WeaponModel").visible, "Carter keeps repair pose after iris_servo refresh")
	servo.cancel_repair()

	offworld.queue_free()
	sgc.queue_free()
	await physics_frame
	await physics_frame
	print("test_squad_rig_edge_cases: PASS")
	await preload("res://tests/support/finish.gd").success(self)
