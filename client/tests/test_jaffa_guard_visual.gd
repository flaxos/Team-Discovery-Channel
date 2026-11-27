extends SceneTree
## Milestone 2: Verify Sprint 20 Serpent and Sprint 21 Horus Jaffa rigs activate by default
## across both SGC Defense and Offworld ModularMission maps, preserving collision and muzzles.

const JAFFA := preload("res://scenes/entities/JaffaGuard.tscn")
const SHOCK := preload("res://scenes/entities/JaffaShockGuard.tscn")
const SGC_BASE := preload("res://scenes/main/SGCUATBase.tscn")
const OFFWORLD := preload("res://scenes/mission/GoauldInfiltrationMission.tscn")


func _init() -> void:
	call_deferred("run")


func _check_guard(guard: JaffaAI, is_horus: bool) -> void:
	var rig_name: NodePath = ^"HorusRig" if is_horus else ^"SerpentRig"
	var rig := guard.get_node_or_null(rig_name) as Node3D
	assert(rig != null and rig.is_processing(), "Jaffa rig active by default: " + String(rig_name))
	assert(not guard.body_mesh.visible, "Primitive capsule hidden")
	assert(not (guard.get_node(^"Visuals/SerpentHelm") as Node3D).visible, "Primitive prism hidden")
	assert(not (guard.get_node(^"Visuals/EyeSlits") as Node3D).visible, "Primitive eyes hidden")
	var shape := guard.collision_shape.shape as CapsuleShape3D
	assert(is_equal_approx(shape.radius, 0.5 if is_horus else 0.45))
	assert(is_equal_approx(shape.height, 2.0 if is_horus else 1.9))
	assert(guard.muzzle_point.position == Vector3(0, 0, -1.1), "Staff muzzle unchanged")
	if is_horus:
		var helmet := rig.skeleton.get_node(^"HorusHelmet").find_child("FalconHeadpiece", true, false) as MeshInstance3D
		assert(helmet != null and helmet.is_visible_in_tree(), "Horus falcon helmet attached")
		var bounds: AABB = (guard.global_transform.affine_inverse() * helmet.global_transform) * helmet.get_aabb()
		assert(bounds.end.y < guard._tell.position.y, "Horus crown stays below AwarenessTell")
	else:
		var helmet := rig.skeleton.get_node_or_null(^"SerpentHelmet") as BoneAttachment3D
		assert(helmet != null and helmet.get_child_count() > 0, "Serpent helmet attached")


func run() -> void:
	# 1. Verify default Serpent & Horus inside SGC Defense / UAT Base.
	var sgc := SGC_BASE.instantiate() as GateRoom
	root.add_child(sgc)
	await (sgc.get_node(^"SGCMap") as SGCMap).navigation_ready
	var sgc_enemies := sgc.get_node(^"Enemies") as Node3D
	var sgc_serpent := JAFFA.instantiate() as JaffaAI
	var sgc_horus := SHOCK.instantiate() as JaffaAI
	sgc_serpent.position = Vector3(12, 11.02, 18)
	sgc_horus.position = Vector3(14, 11.02, 18)
	sgc_enemies.add_child(sgc_serpent, true)
	sgc_enemies.add_child(sgc_horus, true)
	sgc_serpent.set_physics_process(false)
	sgc_horus.set_physics_process(false)
	await process_frame
	_check_guard(sgc_serpent, false)
	_check_guard(sgc_horus, true)

	# Pose & Combat checks on Horus & Serpent.
	var s_rig := sgc_serpent.get_node(^"SerpentRig") as Node3D
	var h_rig := sgc_horus.get_node(^"HorusRig") as Node3D
	assert(s_rig.pose == &"ready_idle" and h_rig.pose == &"ready_idle")
	assert(s_rig.skin_visual != h_rig.skin_visual and s_rig.skeleton != h_rig.skeleton)
	sgc_serpent.is_crouching = true
	s_rig._process(1.0 / 60.0)
	assert(s_rig.pose == &"aim_crouch_idle")
	sgc_serpent.is_crouching = false
	sgc_horus.play_staff_fire_fx(sgc_horus.muzzle_point.global_position)
	h_rig._process(1.0 / 60.0)
	assert(h_rig.pose == &"shoot")

	# Zat stun hides staff and uses downed pose; death snaps/plays death; vaporize shrinks.
	sgc_horus.health_component.apply_zat_shot()
	h_rig._process(1.0 / 60.0)
	assert(h_rig.pose == &"downed" and not (sgc_horus.staff_mount.get_node(^"StaffVisual") as Node3D).visible)
	sgc_horus.health_component.take_damage(400.0, null, "zat_kill")
	h_rig._process(1.0 / 60.0)
	assert(h_rig.pose == &"death")
	sgc_horus.health_component.apply_zat_shot()
	assert(sgc_horus.health_component.is_vaporized and not (sgc_horus.staff_mount.get_node(^"StaffVisual") as Node3D).visible)

	# Late-join snapshot dead guard immediately snaps death clip to end.
	var late_dead := SHOCK.instantiate() as JaffaAI
	late_dead.position = Vector3(16, 11.02, 18)
	sgc_enemies.add_child(late_dead, true)
	late_dead.set_physics_process(false)
	late_dead.health_component.sync_health_state({
		"revision": 1, "health": 0.0, "maximum": 140.0,
		"dead": true, "downed": false, "stunned": false, "vaporized": false,
		"stun_timer": 0.0, "bleedout_timer": 0.0, "zat_hits": 0, "zat_window": 0.0,
	}, "", 0.0, NodePath())
	var dead_rig := late_dead.get_node(^"HorusRig") as Node3D
	dead_rig._process(0.016)
	assert(dead_rig.pose == &"death" and is_equal_approx(dead_rig.animation.current_animation_position, dead_rig.animation.current_animation_length),
		"Late-join dead Jaffa snaps immediately to final death pose")

	sgc.queue_free()
	await physics_frame
	await physics_frame

	# 2. Verify inside Modular Offworld Mission and shared Horus helmet mesh across multiple Horus guards.
	var world := OFFWORLD.instantiate() as ModularMission
	root.add_child(world)
	while not world.is_started:
		await process_frame
	var h1 := SHOCK.instantiate() as JaffaAI
	var h2 := SHOCK.instantiate() as JaffaAI
	world.enemies.add_child(h1, true)
	world.enemies.add_child(h2, true)
	h1.set_physics_process(false)
	h2.set_physics_process(false)
	await process_frame
	_check_guard(h1, true)
	_check_guard(h2, true)
	var m1 := (h1.get_node(^"HorusRig").skeleton.get_node(^"HorusHelmet").find_child("FalconHeadpiece", true, false) as MeshInstance3D).mesh
	var m2 := (h2.get_node(^"HorusRig").skeleton.get_node(^"HorusHelmet").find_child("FalconHeadpiece", true, false) as MeshInstance3D).mesh
	assert(m1 == m2, "Horus guards share cached native helmet mesh")
	for enemy: JaffaAI in world.enemies.get_children():
		_check_guard(enemy, enemy.is_shock_guard)
	world.queue_free()
	await physics_frame
	await physics_frame
	print("test_jaffa_guard_visual: PASS")
	await preload("res://tests/support/finish.gd").success(self)
