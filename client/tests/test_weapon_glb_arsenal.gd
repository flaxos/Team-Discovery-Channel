extends SceneTree
## Automated verification suite for Milestone AP-1b: Full 6-weapon .glb arsenal ingestion
## (WeaponP90, WeaponMP5, WeaponM249, WeaponM9, WeaponZat, WeaponStaff), D-015 material
## sanitization (metallic == 0.0), headless-safe importer="keep" sidecars, MuzzlePoint
## alignment in -Z, and provenance recording in credits/ATTRIBUTIONS.md.


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func run() -> void:
	var repo_root := ProjectSettings.globalize_path("res://").trim_suffix("client/").trim_suffix("client")
	var attr_path := repo_root.path_join("credits/ATTRIBUTIONS.md")
	var lic_path := repo_root.path_join("credits/licenses/CC0-1.0.txt")
	assert(FileAccess.file_exists(attr_path), "Provenance manifest exists: " + attr_path)
	assert(FileAccess.file_exists(lic_path), "CC0-1.0 license text exists: " + lic_path)
	var attr_text := FileAccess.get_file_as_string(attr_path)

	var expected_weapons := [
		[WeaponP90, "p90", "p90_smg.glb", -0.30],
		[WeaponMP5, "mp5", "mp5_silenced.glb", -0.36],
		[WeaponM249, "m249", "m249_saw.glb", -0.62],
		[WeaponM9, "m9", "m9_pistol.glb", -0.18],
		[WeaponZat, "zat", "zat_sidearm.glb", -0.20],
		[WeaponStaff, "staff_weapon", "staff_weapon.glb", -1.05],
	]

	var stage := Node3D.new()
	stage.name = "ArsenalTestStage"
	root.add_child(stage)
	await frames(1)

	for spec: Array in expected_weapons:
		var script_cls: GDScript = spec[0]
		var wid: String = spec[1]
		var glb_file: String = spec[2]
		var expected_muzzle_z: float = spec[3]

		assert(WeaponBase.GLB_MODELS.has(wid), "WeaponBase.GLB_MODELS contains " + wid)
		assert(WeaponBase.GLB_MODELS[wid].ends_with(glb_file), "GLB path matches " + glb_file)
		assert(attr_text.contains(glb_file), "credits/ATTRIBUTIONS.md documents " + glb_file)

		# Verify .glb.import sidecar uses importer="keep" for headless safety
		var import_global := ProjectSettings.globalize_path(WeaponBase.GLB_MODELS[wid] + ".import")
		assert(FileAccess.file_exists(import_global), "Missing .import sidecar for " + glb_file)
		var import_text := FileAccess.get_file_as_string(import_global)
		assert(import_text.contains('importer="keep"'), "Sidecar must set importer=\"keep\" for " + glb_file)

		var gun := script_cls.new() as WeaponBase
		stage.add_child(gun)
		await frames(1)

		assert(gun.weapon_id == wid, "Weapon ID matches " + wid)
		var imported := gun.get_node_or_null("WeaponModel/ImportedGLB") as Node3D
		assert(imported != null, "WeaponModel/ImportedGLB node attached for " + wid)

		var meshes := imported.find_children("*", "MeshInstance3D", true, false)
		if imported is MeshInstance3D:
			meshes.push_front(imported)
		assert(not meshes.is_empty(), "ImportedGLB contains MeshInstance3D nodes for " + wid)

		var total_surfaces := 0
		for node in meshes:
			var mi := node as MeshInstance3D
			assert(mi.mesh != null, "MeshInstance3D has non-null mesh on " + wid)
			var aabb := mi.mesh.get_aabb()
			assert(aabb.size.length() > 0.1, "Mesh AABB non-empty for " + wid + ": " + str(aabb.size))
			for s in range(mi.mesh.get_surface_count()):
				total_surfaces += 1
				var mat := mi.get_surface_override_material(s) as BaseMaterial3D
				if mat == null:
					mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
				assert(mat != null, "Surface material exists on " + wid + " surface " + str(s))
				assert(is_zero_approx(mat.metallic), "D-015 metallic == 0.0 on " + wid + " surface " + str(s))

		assert(total_surfaces >= 2, "Multi-surface visual detail present on " + wid)
		assert(gun.muzzle_point != null, "MuzzlePoint exists on " + wid)
		assert(is_equal_approx(gun.muzzle_point.position.z, expected_muzzle_z), "MuzzlePoint Z matches for " + wid)
		assert(gun.muzzle_point.position.z < -0.15, "MuzzlePoint oriented forward in -Z for " + wid)

		gun.queue_free()
		await frames(1)

	stage.queue_free()
	await frames(1)
	print("PASS: test_weapon_glb_arsenal verified all 6 .glb weapons")
	quit(0)
