extends SceneTree
## AP-1d: the CC BY 4.0 Beretta M9 by emran.bayati replaces the procedural sidearm visual. The
## weapon's id, stats and MuzzlePoint are unchanged; the model's bore sits on the MuzzlePoint.
const MUZZLE := Vector3(0, 0.02, -0.18)
const TRIANGLES := 10185


func _init() -> void:
	call_deferred("run")


func weapon_space(gun: Node3D, node: Node3D) -> Transform3D:
	return gun.global_transform.affine_inverse() * node.global_transform


func check_credits() -> void:
	var repo_root := ProjectSettings.globalize_path("res://").trim_suffix("client/").trim_suffix("client")
	var credits := FileAccess.get_file_as_string(repo_root.path_join("credits/ATTRIBUTIONS.md"))
	assert(credits.contains("beretta_m9.glb") and credits.contains("emran.bayati"), "M9 credited")
	assert(FileAccess.file_exists(repo_root.path_join("credits/licenses/CC-BY-4.0.txt")), "CC BY text bundled")


func run() -> void:
	check_credits()
	assert(WeaponBase.load_glb_model("res://assets/weapons/missing.glb") == null, "Missing model")
	var holder := Node3D.new()
	root.add_child(holder)
	var gun := WeaponM9.new()
	holder.add_child(gun)
	await process_frame
	assert(gun.weapon_id == "m9" and gun.damage == 28.0 and gun.mag_capacity == 15, "Stats unchanged")
	assert(gun.muzzle_point != null and gun.muzzle_point.position.is_equal_approx(MUZZLE),
		"MuzzlePoint unchanged")
	var imported := gun.get_node_or_null("WeaponModel/ImportedGLB") as Node3D
	assert(imported != null, "Imported M9 attached under WeaponModel")
	var triangles := 0
	var bounds := AABB()
	var first := true
	var front := INF
	var bore := Vector3.ZERO
	for node: Node in imported.find_children("*", "", true, false):
		assert(not (node is CollisionObject3D or node is CollisionShape3D), "Visual only")
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		var placed := weapon_space(gun, mi)
		bounds = placed * mi.get_aabb() if first else bounds.merge(placed * mi.get_aabb())
		first = false
		for s in range(mi.mesh.get_surface_count()):
			triangles += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var material := mi.get_surface_override_material(s) as StandardMaterial3D
			assert(material != null and is_zero_approx(material.metallic), "D-015 metallic 0")
			for texture: Texture2D in [material.albedo_texture, material.normal_texture,
					material.roughness_texture]:
				assert(texture != null and texture.get_image().has_mipmaps(), "Textures mipmapped")
		if mi.name == "Gun":
			var points := mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var moved: Array[Vector3] = []
			for p in points:
				moved.append(placed * p)
				front = minf(front, moved[-1].z)
			var count := 0
			for p in moved:
				if p.z <= front + 0.002:
					bore += p
					count += 1
			bore /= maxi(count, 1)
	assert(triangles == TRIANGLES, "Gun and seated magazine only: %d" % triangles)
	assert(absf(bounds.size.z - 0.2172) < 0.003, "Real length 217 mm along -Z: %s" % bounds)
	assert(absf(bounds.size.x - 0.032) < 0.003, "Real width 32 mm: %s" % bounds)
	assert(bounds.size.y > 0.13 and bounds.size.y < 0.15, "Real height about 142 mm: %s" % bounds)
	assert(bore.distance_to(MUZZLE) < 0.003, "Bore %s sits on the MuzzlePoint" % bore)
	assert(bounds.position.z > MUZZLE.z - 0.003, "Nothing in front of the muzzle")
	# Every operative's copy shares the parsed model instead of decoding it again.
	var second := WeaponM9.new()
	var started := Time.get_ticks_usec()
	holder.add_child(second)
	var built_ms := (Time.get_ticks_usec() - started) / 1000.0
	var first_gun := imported.find_child("Gun", true, false) as MeshInstance3D
	var second_gun := second.get_node("WeaponModel/ImportedGLB").find_child("Gun", true, false) as MeshInstance3D
	assert(first_gun.mesh == second_gun.mesh, "Weapon copies share one mesh")
	assert(first_gun.get_surface_override_material(0) == second_gun.get_surface_override_material(0),
		"Weapon copies share one material")
	assert(built_ms < 20.0, "A second M9 does not decode textures again: %.1f ms" % built_ms)
	print("test_imported_m9_visual: PASS")
	holder.queue_free()
	await preload("res://tests/support/finish.gd").success(self)
