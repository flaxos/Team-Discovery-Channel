extends SceneTree
## AP-1f: AK's CC BY 4.0 SAW is a visual child; gameplay and the bore stay aligned.
const MUZZLE := Vector3(0, 0.03, -0.62)
const TRIANGLES := 13328


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("client/")
	var credits := FileAccess.get_file_as_string(repo.path_join("credits/ATTRIBUTIONS.md"))
	assert(credits.contains("m249.glb") and credits.contains("skaf13"), "SAW credited")
	assert(FileAccess.file_exists(repo.path_join("credits/licenses/CC-BY-4.0.txt")))
	assert(WeaponBase.load_glb_model("res://assets/weapons/missing.glb") == null)
	var holder := Node3D.new()
	root.add_child(holder)
	var gun := WeaponM249.new()
	var started := Time.get_ticks_usec()
	holder.add_child(gun)
	var first_ms := (Time.get_ticks_usec() - started) / 1000.0
	await process_frame
	assert(gun.weapon_id == "m249" and gun.damage == 34.0 and gun.mag_capacity == 100)
	assert(gun.reserve_capacity == 300 and gun.fire_rate_rpm == 750.0 and gun.reload_time_s == 3.6)
	assert(gun.base_spread_deg == 3.2 and gun.max_range_m == 60.0 and gun.noise_radius == 40.0)
	assert(gun.muzzle_point.position.is_equal_approx(MUZZLE), "Gameplay muzzle unchanged")
	var imported := gun.get_node_or_null("WeaponModel/ImportedGLB") as Node3D
	if OS.get_cmdline_user_args().has("--expect-fallback"):
		assert(imported == null and gun.get_node("WeaponModel").get_child_count() == 3,
			"Missing GLB keeps the original receiver, drum and barrel")
		print("test_imported_m249_visual: PASS (procedural fallback)")
		holder.queue_free()
		await preload("res://tests/support/finish.gd").success(self)
		return
	assert(imported != null, "Imported SAW attached")
	var points: Array[Vector3] = []
	var triangles := 0
	var bounds := AABB()
	var first := true
	for node: Node in imported.find_children("*", "", true, false):
		assert(not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D))
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		var placed := gun.global_transform.affine_inverse() * mi.global_transform
		bounds = placed * mi.get_aabb() if first else bounds.merge(placed * mi.get_aabb())
		first = false
		for s in range(mi.mesh.get_surface_count()):
			triangles += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var material := mi.get_surface_override_material(s) as StandardMaterial3D
			assert(material != null and is_zero_approx(material.metallic), "D-015")
			assert(not material.vertex_color_use_as_albedo, "Part-ID colours do not tint the textures")
			for texture: Texture2D in [material.albedo_texture, material.normal_texture,
					material.roughness_texture, material.ao_texture]:
				assert(texture != null and texture.get_image().has_mipmaps())
				assert(texture.get_width() <= 1024 and texture.get_height() <= 1024)
			for point: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				points.append(placed * point)
	assert(triangles == TRIANGLES, "All SAW geometry retained")
	assert(absf(bounds.size.z - 0.962854) < 0.003, "Measured 963 mm length: %s" % bounds)
	assert(absf(bounds.size.x - 0.467035) < 0.003, "Source bipod stays extended: %s" % bounds)
	assert(absf(bounds.size.y - 0.500543) < 0.003, "Measured source height: %s" % bounds)
	var front := INF
	for point in points:
		front = minf(front, point.z)
	var bore := Vector3.ZERO
	var count := 0
	for point in points:
		if point.z <= front + 0.0001:
			bore += point
			count += 1
	bore /= maxi(count, 1)
	assert(bore.distance_to(MUZZLE) < 0.003, "Measured barrel crown on muzzle: %s" % bore)
	assert(front >= MUZZLE.z - 0.003, "Nothing in front of gameplay muzzle")
	var second := WeaponM249.new()
	started = Time.get_ticks_usec()
	holder.add_child(second)
	var repeat_ms := (Time.get_ticks_usec() - started) / 1000.0
	var a := imported.find_child("M249_low", true, false) as MeshInstance3D
	var b := second.get_node("WeaponModel/ImportedGLB").find_child("M249_low", true, false) as MeshInstance3D
	assert(a.mesh == b.mesh and a.get_surface_override_material(0) == b.get_surface_override_material(0))
	print("M249_COST first_ms=%.3f repeat_ms=%.3f triangles_per_copy=%d" % [first_ms, repeat_ms, triangles])
	print("test_imported_m249_visual: PASS")
	holder.queue_free()
	await preload("res://tests/support/finish.gd").success(self)
