extends SceneTree
## Sprint 7: decode geometry independently of the placement constants; exercise real reload/fire.
const MUZZLE := Vector3(0, 0.01, -0.36)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var gun := WeaponMP5.new()
	var start := Time.get_ticks_usec()
	holder.add_child(gun)
	var cold_ms := (Time.get_ticks_usec() - start) / 1000.0
	await process_frame
	assert(gun.weapon_id == "mp5" and gun.damage == 20.0 and gun.fire_rate_rpm == 800.0)
	assert(gun.mag_capacity == 30 and gun.reserve_ammo == 150 and gun.reload_time_s == 1.7)
	assert(gun.noise_radius == 6.0 and gun.base_spread_deg == 1.5 and gun.ammo_type == "9x19")
	assert(gun.muzzle_point.position.is_equal_approx(MUZZLE), "Gameplay muzzle unchanged")
	var imported := gun.get_node_or_null("WeaponModel/ImportedGLB") as Node3D
	if OS.get_cmdline_user_args().has("--expect-fallback"):
		assert(imported == null and gun.get_node("WeaponModel").get_child_count() == 2, "Original SMG fallback")
		print("test_imported_mp5_visual: PASS fallback")
		holder.queue_free()
		await process_frame
		await preload("res://tests/support/finish.gd").success(self)
		return
	assert(imported != null, "Faithful MP5SD is attached")
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var points: Array[Vector3] = []
	var triangles := 0
	var first_mesh: MeshInstance3D
	var maps: Dictionary = {}
	var decoded_bytes := 0
	for node: Node in imported.find_children("*", "", true, false):
		assert(not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D), "Visual only")
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		first_mesh = mi
		var placed := gun.global_transform.affine_inverse() * mi.global_transform
		for surface in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var p := placed * vertex
				points.append(p)
				lo = lo.min(p)
				hi = hi.max(p)
			var material := mi.get_surface_override_material(surface) as StandardMaterial3D
			assert(material != null and material.normal_enabled and is_zero_approx(material.metallic), "Preserve D-015")
			for texture: Texture2D in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
				assert(texture != null and texture.get_width() == 2048 and texture.get_image().has_mipmaps(), "2K maps and mipmaps")
				if not maps.has(texture.get_rid()):
					maps[texture.get_rid()] = true
					decoded_bytes += texture.get_image().get_data().size()
	assert(triangles == 10669, "Gun body only, no optional sight")
	assert(absf((hi - lo).z - 0.6919637) < 0.003 and absf((hi - lo).y - 0.2445354) < 0.003, "Measured source size")
	assert((hi - lo).x > 0.050 and (hi - lo).x < 0.052, "Measured width")
	# The front-most crown ring has nonuniform vertex spacing; use its bounding centre.
	var crown_lo := Vector3(INF, INF, INF)
	var crown_hi := Vector3(-INF, -INF, -INF)
	var crown_count := 0
	for p: Vector3 in points:
		if p.z < lo.z + 0.00002:
			crown_lo = crown_lo.min(p)
			crown_hi = crown_hi.max(p)
			crown_count += 1
	var crown := (crown_lo + crown_hi) * 0.5
	assert(crown_count == 22 and crown.distance_to(MUZZLE) < 0.003, "Bore sits on gameplay muzzle: " + str(crown))
	assert(lo.z >= MUZZLE.z - 0.003, "No geometry ahead of muzzle")
	assert(decoded_bytes <= 128 * 1024 * 1024, "Documented shared texture budget")
	var second := WeaponMP5.new()
	start = Time.get_ticks_usec()
	holder.add_child(second)
	var cached_ms := (Time.get_ticks_usec() - start) / 1000.0
	var copy := second.get_node("WeaponModel/ImportedGLB").find_child("MP5SD_Obj", true, false) as MeshInstance3D
	assert(copy.mesh == first_mesh.mesh and copy.get_surface_override_material(0) == first_mesh.get_surface_override_material(0), "Shared cached mesh/material")
	assert(cached_ms < 20.0, "Cached copy does not decode six maps again")
	var credits := str(preload("res://resources/asset_credits.tres").get_meta("attributions"))
	assert(credits.contains("WillyG99") and credits.contains("CC BY 4.0"), "Distributed attribution")
	# Existing authoritative handling remains functional with the imported visual attached.
	assert(gun.try_fire(0.0, Vector3.FORWARD), "Existing server fire succeeds")
	assert(gun.current_ammo == 29 and gun.fire_cooldown > 0.0, "Fire consumes one round")
	gun.reload()
	assert(gun.is_reloading)
	await create_timer(1.8).timeout
	assert(not gun.is_reloading and gun.current_ammo == 30 and gun.reserve_ammo == 149, "Existing reload completes")
	print("test_imported_mp5_visual: PASS cold_ms=", cold_ms, " cached_ms=", cached_ms,
		" triangles=", triangles, " texture_bytes=", decoded_bytes, " bore=", crown)
	holder.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)
