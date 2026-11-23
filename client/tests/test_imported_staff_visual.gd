extends SceneTree
## Cross-check the placed emitter against actual vertices and each existing gameplay marker.

func _init() -> void:
	call_deferred("run")


func check_mesh(holder: Node3D, visual: Node3D, muzzle: Marker3D, length_m: float) -> MeshInstance3D:
	var imported := visual.get_node_or_null("ImportedGLB") as Node3D
	assert(imported != null, "Staff visual is attached")
	assert(imported.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(imported.find_children("*", "CollisionShape3D", true, false).is_empty())
	assert(imported.find_children("*", "NavigationRegion3D", true, false).is_empty())
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 1)
	var mi := meshes[0] as MeshInstance3D
	var placed := holder.global_transform.affine_inverse() * mi.global_transform
	var arrays := mi.mesh.surface_get_arrays(0)
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert(indices.size() == 9216 * 3)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var ring_low := Vector3(INF, INF, INF)
	var ring_high := Vector3(-INF, -INF, -INF)
	var ring_count := 0
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var point := placed * vertex
		low = low.min(point)
		high = high.max(point)
		if absf(point.z - muzzle.position.z) < 0.0001:
			ring_low = ring_low.min(point)
			ring_high = ring_high.max(point)
			ring_count += 1
	assert(ring_count >= 96 and ((ring_low + ring_high) * 0.5).distance_to(muzzle.position) < 0.003,
		"Emitter geometry sits on its own gameplay origin")
	assert(absf(high.z - low.z - length_m) < 0.002 and low.z >= muzzle.position.z - 0.003)
	assert(maxf(absf(high.x), absf(low.x)) <= 0.055 and maxf(absf(high.y), absf(low.y)) <= 0.055)
	return mi


func check_jaffa_fire(guard: JaffaAI, target: Node3D) -> void:
	target.position = guard.position + Vector3(0, 0, -6)
	guard.current_target = target
	guard._dispatch_single_plasma_bolt()
	var matched := 0
	for node: Node in root.get_children():
		if node is PlasmaBolt and node.global_position.is_equal_approx(guard.muzzle_point.global_position):
			assert(node.damage == guard.plasma_damage)
			matched += 1
	assert(matched == 1, "Existing Jaffa fire emits from StaffMount/MuzzlePoint")


func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var gun := WeaponStaff.new()
	var started := Time.get_ticks_usec()
	holder.add_child(gun)
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	assert(gun.weapon_id == "staff_weapon" and gun.damage == 85.0 and gun.fire_rate_rpm == 180.0)
	assert(gun.is_plasma and gun.plasma_speed_mps == 45.0 and gun.heat_per_shot == 18.0)
	assert(gun.muzzle_point.position.is_equal_approx(Vector3(0, 0, -1.05)))
	var player_visual := gun.get_node("WeaponModel") as Node3D
	var fallback := OS.get_cmdline_user_args().has("--expect-fallback")
	var first: MeshInstance3D
	var material: BaseMaterial3D
	var decoded_bytes := 0
	if fallback:
		assert(not player_visual.has_node("ImportedGLB") and player_visual.get_child_count() == 2)
	else:
		first = check_mesh(gun, player_visual, gun.muzzle_point, 1.644)
		material = first.get_surface_override_material(0) as BaseMaterial3D
		assert(material != null and material.normal_enabled and is_zero_approx(material.metallic))
		var images := {}
		for texture: Texture2D in [material.albedo_texture, material.normal_texture,
			material.roughness_texture, material.emission_texture]:
			assert(texture != null and texture.get_width() == 1024 and texture.get_height() == 1024)
			var data := texture.get_image()
			assert(data.has_mipmaps())
			images[texture.get_rid()] = data.get_data().size()
		assert(images.size() == 4)
		for size: int in images.values():
			decoded_bytes += size
		assert(decoded_bytes < 64 * 1024 * 1024)
	var bolt_count := 0
	assert(gun.try_fire(0.0, Vector3.FORWARD) and gun.current_heat == 18.0)
	for node: Node in root.get_children():
		if node is PlasmaBolt:
			assert(node.global_position.is_equal_approx(gun.muzzle_point.global_position))
			assert(node.damage == 85.0 and node.speed == 45.0)
			bolt_count += 1
	assert(bolt_count == 1, "Existing player fire emits one bolt from the existing muzzle")
	var cached_ms := 0.0
	var target := Node3D.new()
	holder.add_child(target)
	var guard_count := 0
	for scene: PackedScene in [preload("res://scenes/entities/JaffaGuard.tscn"),
			preload("res://scenes/entities/JaffaShockGuard.tscn")]:
		var guard := scene.instantiate() as JaffaAI
		guard_count += 1
		guard.position.x = guard_count * 10.0
		holder.add_child(guard)
		guard.set_physics_process(false)
		assert(guard.muzzle_point.position.is_equal_approx(Vector3(0, 0, -1.1)))
		var visual := guard.staff_mount.get_node("StaffVisual") as Node3D
		if fallback:
			assert(not visual.has_node("ImportedGLB") and visual.get_child_count() == 2)
		else:
			var copy := check_mesh(guard.staff_mount, visual, guard.muzzle_point, 1.907)
			assert(copy.mesh == first.mesh and copy.get_surface_override_material(0) == material)
		check_jaffa_fire(guard, target)
	if not fallback:
		var probe := Node3D.new()
		holder.add_child(probe)
		started = Time.get_ticks_usec()
		assert(WeaponBase.attach_staff_visual(probe, Vector3.ZERO))
		cached_ms = (Time.get_ticks_usec() - started) / 1000.0
		var credits := preload("res://resources/asset_credits.tres")
		assert("client/assets/weapons/tri_vane_staff.glb" in credits.get_meta("asset_files", []))
		assert("Tri-vane plasma staff" in str(credits.get_meta("attributions", "")))
	print("test_imported_staff_visual: PASS fallback=", fallback, " cold_ms=", cold_ms,
		" cached_ms=", cached_ms, " decoded_bytes=", decoded_bytes)
	await preload("res://tests/support/finish.gd").success(self)
