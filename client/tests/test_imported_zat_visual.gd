extends SceneTree
## Independent emitter alignment, retained handling, mipmaps, cache and release packaging.
const MUZZLE := Vector3(0, 0.05, -0.20)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var zat := WeaponZat.new()
	var started := Time.get_ticks_usec()
	stage.add_child(zat)
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	assert(zat.is_zat and zat.uses_heat and zat.noise_radius == 4.0)
	assert(zat.damage == 10.0 and zat.heat_per_shot == 22.0 and zat.fire_rate_rpm == 200.0)
	assert(zat.muzzle_point.position.is_equal_approx(MUZZLE) and zat.max_range_m == 35.0)
	var model := zat.get_node("WeaponModel")
	if OS.get_cmdline_user_args().has("--expect-fallback"):
		assert(not model.has_node("ImportedGLB") and model.get_child_count() == 2)
		assert(zat.try_fire(0.0, Vector3.FORWARD) and zat.current_heat == 22.0)
		print("test_imported_zat_visual: PASS fallback")
		await preload("res://tests/support/finish.gd").success(self)
		return

	var imported := model.get_node_or_null("ImportedGLB")
	assert(imported != null, "Zat visual is installed")
	assert(imported.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(imported.find_children("*", "CollisionShape3D", true, false).is_empty())
	assert(imported.find_children("*", "NavigationRegion3D", true, false).is_empty())
	var mi := imported.get_node("ZatBody") as MeshInstance3D
	assert(mi.mesh.get_surface_count() == 1)
	var arrays := mi.mesh.surface_get_arrays(0)
	assert((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 8448 * 3)
	var offset := zat.global_transform.affine_inverse() * mi.global_transform
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var aperture_low := low
	var aperture_high := high
	var points: Array[Vector3] = []
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var point := offset * vertex
		points.append(point)
		low = low.min(point)
		high = high.max(point)
	var edge_count := 0
	for point: Vector3 in points:
		if point.z <= low.z + 0.0001:
			aperture_low = aperture_low.min(point)
			aperture_high = aperture_high.max(point)
			edge_count += 1
	assert(edge_count >= 32 and ((aperture_low + aperture_high) / 2.0).distance_to(MUZZLE) < 0.003,
		"Visible aperture is aligned to the existing origin")
	assert(low.x >= -0.035 and high.x <= 0.035 and low.y >= -0.08 and high.y <= 0.085)
	assert(high.z <= 0.12 and low.z >= MUZZLE.z - 0.003 and absf(high.z - low.z - 0.3134) < 0.002)
	var material := mi.get_surface_override_material(0) as BaseMaterial3D
	assert(material != null and material.normal_enabled and material.emission_enabled)
	assert(is_zero_approx(material.metallic))
	var textures := {}
	var decoded := 0
	for map: Texture2D in [material.albedo_texture, material.normal_texture,
			material.roughness_texture, material.emission_texture]:
		assert(map != null and map.get_width() == 1024 and map.get_height() == 1024)
		assert(map.get_image().has_mipmaps())
		textures[map.get_rid()] = true
		decoded += map.get_image().get_data().size()
	assert(textures.size() == 4 and decoded <= 64 * 1024 * 1024)
	var other := WeaponZat.new()
	started = Time.get_ticks_usec()
	stage.add_child(other)
	var cached_ms := (Time.get_ticks_usec() - started) / 1000.0
	var copy := other.get_node("WeaponModel/ImportedGLB/ZatBody") as MeshInstance3D
	assert(copy.mesh == mi.mesh and copy.get_surface_override_material(0) == material)
	var trace_origin: Array[Vector3] = []
	zat.fired.connect(func(origin: Vector3, _dir: Vector3, _end: Vector3, _hit: Node) -> void:
		trace_origin.append(origin)
	)
	assert(zat.try_fire(0.0, Vector3.FORWARD) and zat.current_heat == 22.0)
	assert(trace_origin.size() == 1 and trace_origin[0].is_equal_approx(zat.muzzle_point.global_position))
	var credits := preload("res://resources/asset_credits.tres")
	assert("client/assets/weapons/loop_frame_zat.glb" in credits.get_meta("asset_files", []))
	assert("Loop-frame ion sidearm" in str(credits.get_meta("attributions", "")))
	print("test_imported_zat_visual: PASS cold_ms=", cold_ms, " cached_ms=", cached_ms, " decoded_bytes=", decoded)
	await preload("res://tests/support/finish.gd").success(self)
