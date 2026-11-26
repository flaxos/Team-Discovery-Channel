extends SceneTree
## Real station geometry, shared rig cost, noncombat boundaries and in-place work poses.

const ROOM := preload("res://scenes/main/SGCUATBase.tscn")
const ROLES := {
	&"Laboratory": [&"LABORATORY", SGCCivilianVisual.Role.LABORATORY, ^"Clipboard"],
	&"Medical": [&"STAGING", SGCCivilianVisual.Role.MEDICAL, ^"SampleCase"],
	&"Administration": [&"GENERALS_OFFICE", SGCCivilianVisual.Role.ADMINISTRATION, ^"Folder"],
}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var room := ROOM.instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node(^"SGCMap") as SGCMap
	await map.navigation_ready
	await physics_frame
	var fallback := "--expect-civilian-fallback" in OS.get_cmdline_user_args()
	var headless_asset := fallback or "--expect-head-fallback" in OS.get_cmdline_user_args()
	var stations := room.get_node(^"CivilianStations")
	assert(stations.get_child_count() == ROLES.size())
	var shared_face: Mesh
	var skeletons: Array[Skeleton3D] = []
	for marker: Marker3D in stations.get_children():
		var role: Array = ROLES[marker.name]
		var civilian := marker.get_node(^"Civilian") as SGCCivilianVisual
		assert(civilian.role == role[1] and civilian.transform == Transform3D.IDENTITY, "Placement uses the authored marker")
		assert(map.definition.region_at(marker.global_position + Vector3.UP * 0.1) == role[0])
		assert(civilian.find_children("*", "CollisionObject3D", true, false).is_empty())
		assert(civilian.find_children("*", "MultiplayerSynchronizer", true, false).is_empty())
		assert(civilian.find_children("*", "HealthComponent", true, false).is_empty())
		assert(civilian.find_children("*", "WeaponBase", true, false).is_empty())
		assert(civilian.get_groups().is_empty(), "Civilians stay out of gameplay targeting groups")
		check_floor(map, marker)
		assert(civilian.work_prop.has_node(role[2]), "Each role has its assigned prop")
		var face := civilian.head.find_child("Face", true, false) as MeshInstance3D
		if headless_asset:
			assert(face == null and civilian.head.has_node(^"FallbackHead"))
		else:
			assert(face != null and face.is_visible_in_tree())
			if shared_face == null:
				shared_face = face.mesh
			assert(face.mesh == shared_face, "Head geometry is shared by all three civilians")
			var finish := face.get_active_material(0) as StandardMaterial3D
			assert(finish.albedo_texture.get_image().has_mipmaps())
			var hair := civilian.head.find_child("Hair", true, false) as MeshInstance3D
			assert((hair.get_active_material(0) as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		if fallback:
			assert(not civilian.has_skeletal_body and civilian.has_node(^"FallbackShirt"))
			continue
		assert(civilian.has_skeletal_body and not skeletons.has(civilian.skeleton))
		skeletons.append(civilian.skeleton)
		assert(not (civilian.skin_visual.find_child("Object_105", true, false) as MeshInstance3D).visible)
		check_work(civilian)
	room.queue_free()
	await process_frame
	print("PASS SGC civilian anchor, role silhouettes, cache and independent in-place motion fallback=", fallback)
	await preload("res://tests/support/finish.gd").success(self)


func check_floor(map: SGCMap, marker: Marker3D) -> void:
	var point := marker.global_position
	var space := marker.get_world_3d().direct_space_state
	var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * 0.2, 1))
	assert(not floor.is_empty() and floor.position.distance_to(point) < 0.025)
	var capsule := CapsuleShape3D.new()
	capsule.radius = SGCMapDefinition.CAPSULE_RADIUS
	capsule.height = SGCMapDefinition.CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 128
	query.transform.origin = point + Vector3.UP * (capsule.height * 0.5 + 0.025)
	assert(space.intersect_shape(query).is_empty())
	assert(NavigationServer3D.map_get_closest_point(map.navigation_map, point).distance_to(point) < 0.25)


func check_work(civilian: SGCCivilianVisual) -> void:
	civilian.set_process(false)
	var anchor := civilian.global_transform
	var left := civilian.work_prop.get_node(^"SupportPalm") as Marker3D
	var right := civilian.work_prop.get_node(^"ActionPalm") as Marker3D
	civilian.work_elapsed = 0.1
	civilian._process(0.0)
	assert(is_zero_approx(civilian.work_amount))
	assert((-civilian.head.global_basis.z).dot(-civilian.global_basis.z) > 0.99, "At rest the civilian looks toward the station")
	var idle := civilian.work_prop.global_position
	var action_error := 0.0
	var support_error := 0.0
	var boot_error := 0.0
	for frame in range(480):
		civilian._process(1.0 / 60.0)
		assert(civilian.global_transform == anchor, "Civilian motion remains in place")
		if civilian.work_amount > 0.99:
			assert((-civilian.head.global_basis.z).y < -0.35, "During work the civilian looks down at the prop")
			action_error = maxf(action_error, palm(civilian, 0).distance_to(right.global_position))
		support_error = maxf(support_error, palm(civilian, 2).distance_to(left.global_position))
		for foot in range(civilian.planted_boots.size()):
			var position := civilian.turning.limbs[foot].world_end().origin
			boot_error = maxf(boot_error, position.distance_to(civilian.to_global(civilian.planted_boots[foot].origin)))
		if frame in [0, 240, 479]:
			check_sole_clearance(civilian)
	assert(civilian.work_prop.global_position.distance_to(idle) < 0.001 and is_zero_approx(civilian.work_amount))
	assert(action_error < 0.05 and support_error < 0.035 and boot_error < 0.024,
		"Station %s contact errors (m) action=%f support=%f boots=%f" % [civilian.role, action_error, support_error, boot_error])
	print("CIVILIAN_CONTACT role=", civilian.role, " action=", action_error, " support=", support_error, " boots=", boot_error)


func palm(civilian: SGCCivilianVisual, first_bone: int) -> Vector3:
	return civilian.to_global(civilian.hand_center(civilian.grip_bones[first_bone], civilian.grip_bones[first_bone + 1]))


func check_sole_clearance(civilian: SGCCivilianVisual) -> void:
	var boots := civilian.skin_visual.find_child("Object_123", true, false) as MeshInstance3D
	var skin := boots.skin
	var skeleton := civilian.skeleton
	var transforms: Array[Transform3D] = []
	for joint in range(skin.get_bind_count()):
		var name := skin.get_bind_name(joint)
		var bone := skin.get_bind_bone(joint) if name == &"" else skeleton.find_bone(name)
		transforms.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(joint))
	var mesh := boots.mesh.surface_get_arrays(0)
	var vertices := mesh[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var joints := mesh[Mesh.ARRAY_BONES] as PackedInt32Array
	var weights := mesh[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
	var stride := int(float(joints.size()) / vertices.size())
	var minima: Array[float] = [INF, INF]
	for index in range(vertices.size()):
		var vertex := Vector3.ZERO
		for influence in range(stride):
			var element := index * stride + influence
			if not is_zero_approx(weights[element]):
				vertex += transforms[joints[element]] * vertices[index] * weights[element]
		var side := int(vertices[index].x < 0.0)
		minima[side] = minf(minima[side], civilian.to_local(skeleton.to_global(vertex)).y)
	for ground_gap: float in minima:
		assert(absf(ground_gap) < 0.02, "Both boot meshes keep floor contact during the stationary work pose")
