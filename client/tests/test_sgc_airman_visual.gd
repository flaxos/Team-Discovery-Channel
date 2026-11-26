extends SceneTree
## The real SGC airman keeps its gameplay body while the skinned child responds to state.

const ROOM := preload("res://scenes/main/SGCUATBase.tscn")
const AIRMAN := preload("res://scenes/entities/SGCAirman.tscn")
const PLAYER := preload("res://scenes/entities/Player.tscn")
const TURRET := preload("res://scenes/props/DeployableTurret.tscn")
const BONE_MAP := preload("res://resources/characters/sgc_airman_bone_map.tres")
const VISUAL_PATH := ^"Visuals/AirmanRig"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var room := ROOM.instantiate() as GateRoom
	root.add_child(room)
	await (room.get_node(^"SGCMap") as SGCMap).navigation_ready
	var airman := spawn(room, Vector3(14, 11.02, 19))
	var peer_copy := spawn(room, Vector3(15, 11.02, 15))
	var visual := airman.get_node(VISUAL_PATH) as Node3D
	var fallback := airman.get_node(^"Visuals/BodyMesh") as MeshInstance3D
	var muzzle := airman.get_node(^"MuzzlePoint") as Marker3D
	var collision := airman.get_node(^"CollisionShape3D") as CollisionShape3D
	assert(is_equal_approx(collision.shape.height, 1.8) and is_equal_approx(collision.shape.radius, 0.45))
	var fallback_mode := "--expect-airman-fallback" in OS.get_cmdline_user_args()
	await check_squad(room, visual, fallback_mode)
	if fallback_mode:
		assert(fallback.visible and visual.get_child_count() == 0)
	else:
		assert(not fallback.visible and not airman.get_node(^"Visuals/HelmetMesh").visible)
		check_rig(visual, peer_copy.get_node(VISUAL_PATH) as Node3D)
		airman.order_move_to(Vector3(16, 11, 17))
		for step in range(55):
			await process_frame
			if visual.pose in [&"ready_walk", &"ready_run"]:
				break
		assert(visual.pose in [&"ready_walk", &"ready_run"], "Actual Airman movement selects the skinned gait")
		airman.set_physics_process(false)
		visual.ground_speed = 0.0
		visual.previous_position = airman.global_position
		check_stationary_turns(airman, visual)
		check_turret_grips(room, airman, visual)
		airman.current_state = SGCAirmanAI.State.COMBAT
		airman.is_crouching = true
		await process_frame
		await process_frame
		assert(visual.pose == &"aim_crouch_idle" and visual.weapon_model.visible, "Crouch clip and MP5 follow the actual state")
		airman._fire_mp5(Vector3.FORWARD)
		await process_frame
		await process_frame
		assert(visual.pose == &"aim_crouch_idle" and visual.crouch_recoil > 0.0, "A crouching Airman recoils within the crouch pose")
		airman.is_crouching = false
		airman._fire_mp5(Vector3.FORWARD)
		await process_frame
		await process_frame
		assert(visual.pose == &"shoot", "Existing shot effects cue the visible rig")
		assert(muzzle.position.is_equal_approx(Vector3(0.25, 1.15, -0.6)))

	airman.health_component.take_damage(400)
	await process_frame
	await process_frame
	assert(airman.current_state == SGCAirmanAI.State.DOWNED)
	if fallback_mode:
		await physics_frame
		assert(fallback.visible and fallback.scale.y < 1.0)
	else:
		assert(visual.pose == &"downed" and not visual.weapon_model.visible)
	airman.health_component.revive()
	await process_frame
	await process_frame
	assert(airman.current_state == SGCAirmanAI.State.COMBAT)
	if not fallback_mode:
		assert(visual.pose == &"revived")
	airman.health_component.take_damage(150, null, "zat_kill")
	await process_frame
	await process_frame
	assert(airman.current_state == SGCAirmanAI.State.DEAD)
	if not fallback_mode:
		assert(visual.pose == &"death")

	for body: SGCAirmanAI in [airman, peer_copy]:
		body.set_physics_process(false)
		body.collision_layer = 0
	for step in range(3):
		await physics_frame
	airman.queue_free()
	peer_copy.queue_free()
	await process_frame
	print("PASS Airman skins, gameplay pose edges, shared model and procedural fallback mode=", fallback_mode)
	await preload("res://tests/support/finish.gd").success(self)


func check_squad(room: GateRoom, airman_rig: Node3D, fallback: bool) -> void:
	var roles := SGCNetworkManager.CLASS_PROFILES.keys()
	roles.erase(SGCNetworkManager.CLASS_SG3_HEAVY)
	roles.append(SGCNetworkManager.CLASS_SG3_HEAVY)
	var squad: Array[PlayerController3D] = []
	for index in range(roles.size()):
		var actor := PLAYER.instantiate() as PlayerController3D
		actor.name = "Squad" + str(index)
		actor.class_id = roles[index]
		actor.position = Vector3(14 + index * 2, 11.02, 21)
		room.players_container.add_child(actor)
		actor.set_physics_process(false)
		# The matrix deliberately exhausts the whole squad before testing the Airmen.
		actor.player_downed.disconnect(room._check_squad_status)
		actor.player_died.disconnect(room._check_squad_status)
		squad.append(actor)
	for actor: PlayerController3D in squad:
		var role := actor.class_id
		var rig := actor.get_node(^"Visuals/SquadRig") as Node3D
		assert(actor.body_mesh.visible == fallback and actor.visor_mesh.visible == fallback)
		assert(actor.class_gear.visible == fallback)
		if fallback:
			assert(rig.get_child_count() == 0)
		else:
			check_rig(airman_rig, rig)
			for slot: int in [1, 2]:
				actor.switch_slot(slot)
				rig._process(1.0 / 60.0)
				var weapon := actor.current_weapon
				var model := weapon.get_node(^"WeaponModel") as Node3D
				var grips: Array = rig.palm_grips(weapon.weapon_id)
				var palm: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
				assert(palm.distance_to(model.to_global(grips[0])) < 0.001, "The weapon follows the right palm")
				assert(weapon.position == Vector3(0.3, 0.9, -0.4), "Rigging moves only held weapon art")
				await check_moving_weapon(actor, rig)
			if role == SGCNetworkManager.CLASS_SG3_HEAVY:
				await check_player_poses(room, actor, rig, airman_rig)
			if role == SGCNetworkManager.CLASS_ONEILL_RECON:
				await check_recon(room, actor, rig, airman_rig)
			if role == SGCNetworkManager.CLASS_CARTER_TECH:
				check_carter(room, actor, rig, airman_rig)
				await check_dragged_pose(room, actor, rig, "zat")
				actor.health_component.revive()
				rig._process(1.0 / 60.0)
				assert(rig.pose == &"revived" and actor.current_weapon.weapon_id == "mp5")
			if role == SGCNetworkManager.CLASS_TEALC_JAFFA:
				await check_tealc(room, actor, rig)
			var weapon_model := actor.current_weapon.get_node(^"WeaponModel") as Node3D
			actor.health_component.apply_zat_shot()
			rig._process(1.0 / 60.0)
			# Recovery may still be blending, but the stun always takes precedence.
			assert(rig.pose == &"downed" and not weapon_model.visible)
			actor.health_component._process(HealthComponent.ZAT_STUN_DURATION)
			assert(not actor.health_component.is_stunned)
			actor.health_component.take_damage(400, null, "zat_kill")
			rig._process(1.0 / 60.0)
			assert(rig.pose == &"death" and not weapon_model.visible)
			print("PASS weapon, movement and health matrix for ", role)
	for actor: PlayerController3D in squad:
		actor.queue_free()
	await process_frame


func check_moving_weapon(actor: PlayerController3D, rig: Node3D) -> void:
	var weapon := actor.current_weapon
	var model := weapon.get_node(^"WeaponModel") as Node3D
	var muzzle := weapon.muzzle_point.transform
	var start := actor.transform
	var peak := 0.0
	for gait: StringName in [&"ready_idle", &"ready_walk", &"ready_run", &"aim_idle", &"aim_walk",
			&"aim_crouch_idle", &"aim_crouch_walk"]:
		actor.is_sprinting = gait == &"ready_run"
		actor.is_aiming_down_sights = gait.begins_with("aim_")
		actor.is_crouching = gait.begins_with("aim_crouch")
		var moving := gait.ends_with("walk") or actor.is_sprinting
		for frame in range(72):
			if moving:
				actor.rotation.y += 0.012
			elif frame == 19:
				actor.rotation.y += 1.1
			elif frame == 51:
				actor.rotation.y -= 1.1
			if moving:
				actor.position -= actor.global_basis.z * (0.10 if actor.is_sprinting else 0.032)
			actor.weapon_holder.rotation.x = PI / 4.0 * sin(float(frame) * TAU / 52.0)
			rig._process(1.0 / 60.0)
			if frame < 17:
				continue
			assert(rig.pose == gait, "%s %s expected %s, saw %s" % [actor.class_id, weapon.weapon_id, gait, rig.pose])
			assert(model.visible and model.global_basis.z.is_equal_approx(weapon.global_basis.z.normalized()))
			peak = maxf(peak, maxf(palm_error(rig, model, 0), palm_error(rig, model, 1)))
	assert(peak < 0.020, "%s %s moving grip error: %.1f mm" % [actor.class_id, weapon.weapon_id, peak * 1000.0])

	actor.transform = start
	actor.weapon_holder.rotation.x = 0.0
	actor.is_crouching = false
	actor.is_sprinting = false
	actor.is_aiming_down_sights = true
	rig.previous_position = actor.global_position
	rig.ground_speed = 0.0
	var origin := weapon.muzzle_point.global_position
	var forward := -weapon.global_basis.z.normalized()
	var emissions: Array[Vector3] = []
	weapon.fired.connect(func(point: Vector3, direction: Vector3, _hit: Vector3, _node: Node) -> void:
		emissions.assign([point, direction]), CONNECT_ONE_SHOT)
	var fired := weapon.try_fire(0.0, forward)
	assert(fired)
	assert(emissions.size() == 2 and emissions[0].is_equal_approx(origin) and emissions[1].is_equal_approx(forward))
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"shoot" and rig.recoil > 0.0)
	assert(rig.show_shot(origin, weapon.is_plasma, weapon.is_zat).is_equal_approx(model.to_global(muzzle.origin)))
	weapon.reload()
	assert(weapon.is_reloading != weapon.uses_heat)
	for frame in range(16):
		rig._process(1.0 / 60.0)
	assert(is_equal_approx(rig.reload_blend, 0.0 if weapon.uses_heat else 1.0))
	assert(weapon.muzzle_point.transform == muzzle)
	if not weapon.uses_heat:
		await weapon.reloaded
		for frame in range(16):
			rig._process(1.0 / 60.0)
		assert(is_zero_approx(rig.reload_blend))
	else:
		assert(weapon.current_heat > 0.0)
		for bolt: PlasmaBolt in get_nodes_in_group(&"plasma_bolt"):
			if bolt.shooter == actor:
				assert(bolt.global_position.is_equal_approx(origin) and bolt.direction.is_equal_approx(forward))
				bolt.queue_free()
		await create_timer(weapon.fire_cooldown + 0.05).timeout
	for frame in range(50):
		rig._process(1.0 / 60.0)
	actor.is_aiming_down_sights = false
	print("MATRIX ", actor.class_id, " ", weapon.weapon_id, " max palm error (mm) ", snappedf(peak * 1000.0, 0.01))


func palm_error(rig: Node3D, model: Node3D, index: int) -> float:
	var bone_index := index * 2
	var palm: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[bone_index], rig.grip_bones[bone_index + 1]))
	var targets: Array = rig.palm_grips(rig.player.current_weapon.weapon_id)
	return palm.distance_to(model.to_global(targets[index]))


func check_tealc(room: GateRoom, actor: PlayerController3D, rig: Node3D) -> void:
	var front_plate := rig.jaffa_mount.find_child("UpperPlate", true, false) as MeshInstance3D
	assert(front_plate.is_visible_in_tree() and rig.recon_mount == null and rig.tech_mount == null)
	rig.set_camera_alpha(0.15)
	assert(is_equal_approx(front_plate.transparency, 0.85))
	actor._restore_visual_materials()
	assert(is_zero_approx(front_plate.transparency))

	actor.switch_slot(1)
	actor.is_aiming_down_sights = true
	var staff := actor.current_weapon as WeaponStaff
	var model := staff.get_node(^"WeaponModel") as Node3D
	var muzzle := staff.muzzle_point.transform
	for crouched: bool in [false, true]:
		actor.is_crouching = crouched
		for pitch: float in [-PI / 4.0, 0.0, PI / 4.0]:
			actor.weapon_holder.rotation.x = pitch
			for frame in range(10):
				rig._process(1.0 / 60.0)
			check_staff_contacts(rig, model)
			assert(actor.to_local(model.global_position).x > 0.22, "The shaft clears the right side of the vest")
			assert(model.global_basis.z.is_equal_approx(staff.global_basis.z.normalized()))
	assert(staff.muzzle_point.transform == muzzle)
	var shot_origin := staff.muzzle_point.global_position
	var shot_direction := -staff.global_basis.z.normalized()
	var fired := staff.try_fire(0.0, shot_direction)
	assert(fired)
	var found_bolt := false
	for bolt: PlasmaBolt in get_nodes_in_group(&"plasma_bolt"):
		if bolt.shooter == actor:
			assert(bolt.global_position.is_equal_approx(shot_origin) and bolt.direction.is_equal_approx(shot_direction))
			found_bolt = true
			bolt.queue_free()
	assert(found_bolt, "The staff shot uses the authoritative muzzle and aim")
	rig._process(1.0 / 60.0)
	check_staff_contacts(rig, model)
	var visible_emitter := model.to_global(staff.muzzle_point.position)
	assert(rig.show_shot(shot_origin, true, false).is_equal_approx(visible_emitter))

	var drag_start := actor.position
	for gait: StringName in [&"ready_run", &"aim_walk", &"aim_crouch_walk"]:
		actor.is_sprinting = gait == &"ready_run"
		actor.is_aiming_down_sights = not actor.is_sprinting
		actor.is_crouching = gait == &"aim_crouch_walk"
		for frame in range(160):
			actor.rotation.y += 0.005
			actor.position -= actor.global_basis.z * (0.10 if actor.is_sprinting else 0.03)
			actor.weapon_holder.rotation.x = PI / 4.0 * sin(float(frame) * TAU / 120.0)
			rig._process(1.0 / 60.0)
			if frame >= 30:
				assert(rig.pose == gait, "Expected %s while moving, saw %s" % [gait, rig.pose])
				check_staff_contacts(rig, model)
				assert(actor.to_local(model.global_position).x > 0.22)

	actor.is_crouching = false
	actor.is_sprinting = false
	actor.position = drag_start
	rig.previous_position = actor.global_position
	rig.ground_speed = 0.0
	await check_dragged_pose(room, actor, rig, "zat")
	actor.health_component.revive()
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"revived" and actor.current_weapon == staff and front_plate.is_visible_in_tree())
	print("PASS Teal’c Jaffa armour, moving staff grips, plasma alignment and Zat through drag and recovery")


func check_staff_contacts(rig: Node3D, model: Node3D) -> void:
	var grips: Array = rig.palm_grips("staff_weapon")
	var right: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
	var left: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[2], rig.grip_bones[3]))
	assert(right.distance_to(model.to_global(grips[0])) < 0.015, "Rear palm stays on the staff sleeve")
	assert(left.distance_to(model.to_global(grips[1])) < 0.015, "Front palm stays on the staff sleeve")


func check_carter(room: GateRoom, actor: PlayerController3D, rig: Node3D, airman_rig: Node3D) -> void:
	var servo := room.get_node(^"IrisServoHousing") as IrisServoHousing
	var display := rig.tech_mount.find_child("ScannerDisplay", true, false) as MeshInstance3D
	assert(display.is_visible_in_tree() and rig.recon_mount == null)
	var uniform := rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D
	var base := (airman_rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	var finish := uniform.get_active_material(0) as StandardMaterial3D
	assert(finish.albedo_color != base.albedo_color and finish.albedo_texture == base.albedo_texture)
	rig.set_camera_alpha(0.15)
	assert(is_equal_approx(display.transparency, 0.85))
	actor._restore_visual_materials()
	assert(is_zero_approx(display.transparency))

	actor.switch_slot(1)
	var model := actor.current_weapon.get_node(^"WeaponModel") as Node3D
	var muzzle := actor.current_weapon.muzzle_point.transform
	actor.global_position = servo.to_global(Vector3(0, 0.01, 0.63))
	actor.global_rotation.y = servo.global_rotation.y
	servo.start_repair(actor)
	assert(servo.is_repairing and servo.repairer_player == actor)
	rig.previous_position = actor.global_position
	rig.ground_speed = 0.0
	for frame in range(12):
		rig._process(1.0 / 60.0)
	assert(not model.visible and actor.current_weapon.muzzle_point.transform == muzzle)
	var right: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
	var left: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[2], rig.grip_bones[3]))
	var lever := servo.get_node(^"LeverMesh/RepairLeverPalm") as Marker3D
	var brace := servo.get_node(^"RepairBracePalm") as Marker3D
	assert(right.distance_to(lever.global_position) < 0.035 and left.distance_to(brace.global_position) < 0.035)
	actor.is_aiming_down_sights = true
	rig._process(1.0 / 60.0)
	assert(model.visible and servo.is_repairing, "Aiming releases the visual pose without changing the repair")
	actor.is_aiming_down_sights = false
	actor.global_position = servo.to_global(Vector3(0, 0.01, 1.7))
	rig.previous_position = actor.global_position
	rig._process(1.0 / 60.0)
	assert(model.visible and servo.is_repairing, "Distant repairs keep the regular weapon pose")
	servo.cancel_repair()
	assert(not servo.is_repairing)
	print("PASS Carter Tech kit, material isolation and iris repair contact")


func check_recon(room: GateRoom, actor: PlayerController3D, rig: Node3D, airman_rig: Node3D) -> void:
	var uniform := rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D
	var airman_uniform := airman_rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D
	var base := airman_uniform.get_active_material(0) as StandardMaterial3D
	var palette := uniform.get_active_material(0) as StandardMaterial3D
	assert(palette != base and palette.albedo_color != base.albedo_color)
	assert(palette.albedo_texture == base.albedo_texture and palette.normal_texture == base.normal_texture)
	var antenna := rig.recon_mount.find_child("WhipAntenna", true, false) as MeshInstance3D
	assert(antenna.is_visible_in_tree() and rig.recon_mount.bone_name == BONE_MAP.get_skeleton_bone_name(&"UpperChest"))
	rig.set_camera_alpha(0.15)
	assert(is_equal_approx(antenna.transparency, 0.85))
	actor._restore_visual_materials()
	assert(is_zero_approx(antenna.transparency))
	actor.class_configured.emit(SGCNetworkManager.CLASS_SG3_HEAVY)
	assert(not antenna.is_visible_in_tree() and rig.heavy_mount.visible and uniform.get_active_material(0) != base)
	actor.class_configured.emit(SGCNetworkManager.CLASS_ONEILL_RECON)
	assert(antenna.is_visible_in_tree() and not rig.heavy_mount.visible and uniform.get_active_material(0) == palette)
	actor.switch_slot(1)

	actor.is_aiming_down_sights = true
	actor.position.x += 0.10
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"aim_walk")
	actor.is_crouching = true
	actor.position.x += 0.10
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"aim_crouch_walk")
	actor.is_crouching = false
	var p90 := actor.current_weapon
	assert(p90.weapon_id == "p90")
	var model := p90.get_node(^"WeaponModel") as Node3D
	var muzzle := p90.muzzle_point.transform
	actor.current_aim_target = p90.muzzle_point.global_position + Vector3.FORWARD * 10.0
	var fired := p90.try_fire()
	assert(fired)
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"shoot" and rig.recoil > 0.0)
	p90.reload()
	assert(p90.is_reloading)
	for frame in range(16):
		rig._process(1.0 / 60.0)
	assert(is_equal_approx(rig.reload_blend, 1.0))
	assert(model.global_basis.z.y > p90.global_basis.z.y + 0.30 and p90.muzzle_point.transform == muzzle)
	actor.switch_slot(2)
	rig._process(1.0 / 60.0)
	assert(is_zero_approx(rig.reload_blend) and actor.current_weapon.weapon_id == "m9")
	actor.switch_slot(1)
	await p90.reloaded
	for frame in range(16):
		rig._process(1.0 / 60.0)
	assert(is_zero_approx(rig.reload_blend) and p90.current_ammo == p90.mag_capacity)

	await check_dragged_pose(room, actor, rig, "m9")
	actor.health_component.revive()
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"revived" and actor.current_weapon.weapon_id == "p90" and antenna.is_visible_in_tree())
	print("PASS O'Neill Recon kit, role isolation, weapon presentation and recovery")


func check_dragged_pose(room: GateRoom, actor: PlayerController3D, rig: Node3D, sidearm_id: String) -> void:
	var rescuer := PLAYER.instantiate() as PlayerController3D
	rescuer.name = "RecoveryRescuer"
	rescuer.position = actor.position + Vector3(0.6, 0, 0)
	room.players_container.add_child(rescuer, true)
	rescuer.set_physics_process(false)
	rescuer.is_window_focused = true
	actor.health_component.take_damage(400)
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"downed" and actor.current_weapon.weapon_id == sidearm_id)
	var downed_model := actor.current_weapon.get_node(^"WeaponModel") as Node3D
	assert(downed_model.visible and palm_error(rig, downed_model, 0) < 0.001)
	var crawl_start := actor.global_position
	Input.action_press("move_right")
	for frame in range(8):
		await physics_frame
		actor._process_downed_crawl(1.0 / 60.0)
		rig._process(1.0 / 60.0)
	Input.action_release("move_right")
	assert(actor.global_position.distance_to(crawl_start) > 0.05 and rig.pose == &"prone_crawl")
	assert(actor.active_slot == 2 and palm_error(rig, downed_model, 0) < 0.001)
	var sidearm := actor.current_weapon
	var origins: Array[Vector3] = []
	sidearm.fired.connect(func(origin: Vector3, _dir: Vector3, _hit: Vector3, _node: Node) -> void:
		origins.append(origin), CONNECT_ONE_SHOT)
	actor.current_aim_target = actor.global_position + Vector3.UP * 8.0
	Input.action_press("fire")
	await physics_frame
	actor._process_downed_crawl(1.0 / 60.0)
	Input.action_release("fire")
	assert(origins.size() == 1 and origins[0].is_equal_approx(sidearm.muzzle_point.global_position))
	actor.current_aim_target = Vector3.ZERO
	rescuer.start_dragging_body(actor)
	var downed_position := actor.position
	await physics_frame
	rescuer._physics_process(1.0 / 60.0)
	rig._process(1.0 / 60.0)
	assert(rescuer.dragged_body == actor and actor.position.distance_to(downed_position) > 0.05)
	assert(rig.pose == &"prone_crawl" and actor.current_weapon.weapon_id == sidearm_id)
	rescuer.stop_dragging_body()
	rescuer.queue_free()


func check_player_poses(room: GateRoom, actor: PlayerController3D, rig: Node3D, airman_rig: Node3D) -> void:
	var mesh := rig.heavy_mount.find_child("CarrierPanel", true, false) as MeshInstance3D
	assert(mesh.is_visible_in_tree() and rig.heavy_mount.bone_name == BONE_MAP.get_skeleton_bone_name(&"UpperChest"))
	var uniform := rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D
	var base := (airman_rig.skin_visual.find_child("Object_107", true, false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	var finish := uniform.get_active_material(0) as StandardMaterial3D
	assert(finish.albedo_color != base.albedo_color and finish.albedo_texture == base.albedo_texture)
	actor._restore_visual_materials()
	actor.ads_zoom_distance = PlayerController3D.ADS_MIN_ZOOM
	actor.ads_blend = 1.0
	actor._update_proximity_fade(1.0)
	assert(is_equal_approx(mesh.transparency, 0.85))
	actor._restore_visual_materials()
	assert(is_zero_approx(mesh.transparency))
	actor.switch_slot(1)
	await check_dragged_pose(room, actor, rig, "m9")
	actor.health_component.revive()
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"revived" and actor.active_slot == 1)

	var turret := TURRET.instantiate() as DeployableTurret
	room.add_child(turret)
	turret.global_position = actor.global_position
	turret.request_mount(actor)
	assert(turret.mounted_player == actor and not actor.weapon_holder.visible)
	var view_heading := actor.rotation.y
	var muzzle := turret.muzzle_point.transform
	var fallback := "--expect-m2-fallback" in OS.get_cmdline_user_args()
	for step in range(25):
		var forward := Vector3.FORWARD.rotated(Vector3.UP, step * TAU / 24.0)
		turret.receive_player_input(turret.turret_head.global_position + forward * 15.0, false)
		for frame in range(12):
			rig._process(1.0 / 60.0)
		var actor_offset := actor.global_position - turret.global_position
		assert(actor_offset.is_equal_approx(-forward * DeployableTurret.GUNNER_REAR_OFFSET))
		assert(rig.global_basis.z.dot(forward) < -0.99 and actor.rotation.y == view_heading)
		assert(rig.turning.step_foot == -1 and turret.muzzle_point.transform == muzzle)
		if fallback:
			assert(rig.pose == &"aim_idle")
		else:
			assert(rig.pose == &"aim_crouch_idle")
			var right: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[0], rig.grip_bones[1]))
			var left: Vector3 = rig.to_global(rig.hand_center(rig.grip_bones[2], rig.grip_bones[3]))
			assert(right.distance_to(turret.right_grip.global_position) < 0.035)
			assert(left.distance_to(turret.left_grip.global_position) < 0.035)
	turret.dismount()
	rig._process(1.0 / 60.0)
	assert(actor.weapon_holder.visible)
	turret.queue_free()
	print("PASS Heavy carrier, drag and full mounted M2 rotation with fixed camera heading and muzzle")


func spawn(room: GateRoom, position: Vector3) -> SGCAirmanAI:
	var airman := AIRMAN.instantiate() as SGCAirmanAI
	room.allies_container.add_child(airman)
	airman.global_position = position
	return airman


func check_rig(visual: Node3D, copy: Node3D) -> void:
	var profile := BONE_MAP.profile
	for index in range(profile.bone_size):
		var mapped := BONE_MAP.get_skeleton_bone_name(profile.get_bone_name(index))
		if profile.is_required(index) or not mapped.is_empty():
			assert(visual.skeleton.find_bone(mapped) >= 0, "The exported skeleton honours the humanoid BoneMap")
	var first := visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var second := copy.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(first.skin != null and first.mesh == second.mesh, "Each NPC uses the shared mesh and its own skeleton")
	var surface := first.get_active_material(0) as StandardMaterial3D
	assert(surface.albedo_texture.get_image().has_mipmaps())
	assert(visual.skeleton != copy.skeleton and visual.animation != copy.animation)


func check_stationary_turns(airman: SGCAirmanAI, visual: Node3D) -> void:
	var root_position := airman.global_position
	airman.current_state = SGCAirmanAI.State.STAGING
	var heading := airman.global_rotation.y
	for direction: float in [1.0, -1.0]:
		for frame in range(20):
			visual._process(1.0 / 60.0)
		heading += direction * 1.6
		airman.rotation.y = heading
		var maximum_lift := 0.0
		var stepped: Array[int] = []
		for frame in range(38):
			visual._process(1.0 / 60.0)
			var turn := visual.turning as RefCounted
			var lifted: int = turn.step_foot
			if lifted < 0 or is_zero_approx(turn.elapsed):
				continue
			if not lifted in stepped:
				stepped.append(lifted)
			var support := 1 - lifted
			var support_ankle: Vector3 = turn.limbs[support].world_end().origin
			assert(support_ankle.distance_to(turn.planted[support].origin) < 0.013, "Support boot remains planted")
			var active_ankle: Vector3 = turn.limbs[lifted].world_end().origin
			maximum_lift = maxf(maximum_lift, active_ankle.y - turn.planted[lifted].origin.y)
		assert(stepped.size() == 2 and stepped[0] == (0 if direction > 0 else 1) and maximum_lift > 0.07)
		assert(visual.turning.step_foot == -1 and absf(angle_difference(visual.turning.heading, heading)) < 0.002)
		assert(airman.global_position == root_position, "Only the visible skeleton takes turn steps")


func check_turret_grips(room: GateRoom, airman: SGCAirmanAI, visual: Node3D) -> void:
	var turret := TURRET.instantiate() as DeployableTurret
	room.add_child(turret)
	turret.global_position = airman.global_position
	airman.mount_turret(turret)
	if "--expect-m2-fallback" in OS.get_cmdline_user_args():
		visual._process(1.0 / 60.0)
		assert(turret.get_node(^"TurretHead/ReceiverMesh").visible)
		assert(airman.mounted_turret == turret and visual.pose == &"aim_idle" and not visual.weapon_model.visible)
		airman.dismount_turret()
		turret.queue_free()
		return
	var original_muzzle := turret.muzzle_point.transform
	var original_tripod := turret.get_node(^"M2Tripod").global_transform as Transform3D
	for angle: float in [0.0, 1.98, -1.75]:
		turret.turret_head.rotation = Vector3(0.14 * signf(angle), angle, 0.0)
		turret._place_occupant()
		for frame in range(25):
			visual._process(1.0 / 60.0)
		assert(not visual.weapon_model.visible and visual.turning.step_foot == -1)
		var primary: Vector3 = visual.to_global(visual.hand_center(visual.grip_bones[0], visual.grip_bones[1]))
		var support: Vector3 = visual.to_global(visual.hand_center(visual.grip_bones[2], visual.grip_bones[3]))
		assert(primary.distance_to(turret.right_grip.global_position) < 0.035)
		assert(support.distance_to(turret.left_grip.global_position) < 0.035)
		var rear := turret.turret_head.global_basis.z.slide(Vector3.UP).normalized()
		assert(airman.global_position.is_equal_approx(turret.global_position + rear * DeployableTurret.GUNNER_REAR_OFFSET))
		assert(turret.muzzle_point.transform == original_muzzle and turret.get_node(^"M2Tripod").global_transform == original_tripod)
	airman.dismount_turret()
	visual._process(1.0 / 60.0)
	assert(airman.mounted_turret == null and turret.mounted_player == null and visual.weapon_model.visible)
	turret.queue_free()
