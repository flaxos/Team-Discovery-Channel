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
	var index := 0
	var roles := SGCNetworkManager.CLASS_PROFILES.keys()
	roles.erase(SGCNetworkManager.CLASS_SG3_HEAVY)
	roles.append(SGCNetworkManager.CLASS_SG3_HEAVY)
	for role: String in roles:
		var actor := PLAYER.instantiate() as PlayerController3D
		actor.name = "Squad" + str(index)
		actor.class_id = role
		actor.position = Vector3(14 + index * 2, 11.02, 21)
		index += 1
		room.players_container.add_child(actor)
		actor.set_physics_process(false)
		var rig := actor.get_node(^"Visuals/SquadRig") as Node3D
		assert(actor.class_id == role)
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
			if role == SGCNetworkManager.CLASS_SG3_HEAVY:
				check_player_poses(room, actor, rig)
			if role == SGCNetworkManager.CLASS_ONEILL_RECON:
				await check_recon(room, actor, rig, airman_rig)
			if role == SGCNetworkManager.CLASS_CARTER_TECH:
				check_carter(room, actor, rig, airman_rig)
		actor.queue_free()


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
	assert(not antenna.is_visible_in_tree() and uniform.get_active_material(0) == base)
	actor.class_configured.emit(SGCNetworkManager.CLASS_ONEILL_RECON)
	assert(antenna.is_visible_in_tree() and uniform.get_active_material(0) == palette)
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

	var rescuer := PLAYER.instantiate() as PlayerController3D
	rescuer.name = "ReconRescuer"
	rescuer.position = actor.position + Vector3(0.6, 0, 0)
	room.players_container.add_child(rescuer)
	rescuer.set_physics_process(false)
	rescuer.is_window_focused = true
	actor.health_component.take_damage(400)
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"downed" and actor.current_weapon.weapon_id == "m9")
	rescuer.start_dragging_body(actor)
	var downed_position := actor.position
	await physics_frame
	rescuer._physics_process(1.0 / 60.0)
	rig._process(1.0 / 60.0)
	assert(rescuer.dragged_body == actor and actor.position.distance_to(downed_position) > 0.05)
	assert(rig.pose == &"prone_crawl" and actor.current_weapon.weapon_id == "m9")
	rescuer.stop_dragging_body()
	actor.health_component.revive()
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"revived" and actor.current_weapon.weapon_id == "p90" and antenna.is_visible_in_tree())
	rescuer.queue_free()
	print("PASS O'Neill Recon kit, role isolation, weapon presentation and recovery")


func check_player_poses(room: GateRoom, actor: PlayerController3D, rig: Node3D) -> void:
	var mesh := rig.skin_meshes[0] as MeshInstance3D
	actor._restore_visual_materials()
	actor.ads_zoom_distance = PlayerController3D.ADS_MIN_ZOOM
	actor.ads_blend = 1.0
	actor._update_proximity_fade(1.0)
	assert(is_equal_approx(mesh.transparency, 0.85))
	actor._restore_visual_materials()
	assert(is_zero_approx(mesh.transparency))
	actor.is_crouching = true
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"aim_crouch_idle")
	actor.is_crouching = false
	actor.current_aim_target = actor.current_weapon.muzzle_point.global_position + Vector3.FORWARD * 10.0
	assert(actor.current_weapon.try_fire())
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"shoot")
	actor.health_component.take_damage(400)
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"downed" and actor.active_slot == 2)
	actor.health_component.revive()
	rig._process(1.0 / 60.0)
	assert(rig.pose == &"revived" and actor.active_slot == 1)

	var turret := TURRET.instantiate() as DeployableTurret
	room.add_child(turret)
	turret.global_position = actor.global_position
	turret.mount(actor)
	turret.turret_head.rotation = Vector3(0.14, 1.98, 0)
	turret._place_occupant()
	for frame in range(25):
		rig._process(1.0 / 60.0)
	assert(not actor.weapon_holder.visible)
	var rear := turret.turret_head.global_basis.z.slide(Vector3.UP).normalized()
	assert(actor.global_position.is_equal_approx(turret.global_position + rear * DeployableTurret.GUNNER_REAR_OFFSET))
	assert(rig.global_basis.z.dot(rear) > 0.99)
	if "--expect-m2-fallback" in OS.get_cmdline_user_args():
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
