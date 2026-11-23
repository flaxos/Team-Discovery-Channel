extends SceneTree
## Measures the actual runtime meshes and textures, including a clean release PCK.
## godot --headless --path client --script res://tests/support/held_weapon_audit.gd

const IDS: Array[String] = ["m9", "p90", "mp5", "m249", "staff_weapon", "zat"]
const WEAPONS: Array[GDScript] = [
	preload("res://scripts/weapons/WeaponM9.gd"), preload("res://scripts/weapons/WeaponP90.gd"),
	preload("res://scripts/weapons/WeaponMP5.gd"), preload("res://scripts/weapons/WeaponM249.gd"),
	preload("res://scripts/weapons/WeaponStaff.gd"), preload("res://scripts/weapons/WeaponZat.gd"),
]


func _init() -> void:
	call_deferred("run")


func validate_weapon(gun: WeaponBase, other: WeaponBase, credited: Array) -> Dictionary:
	var visual := gun.get_node_or_null("WeaponModel/ImportedGLB")
	var second := other.get_node_or_null("WeaponModel/ImportedGLB")
	var path: String = WeaponBase.GLB_MODELS.get(gun.weapon_id, "")
	var file := FileAccess.open(path, FileAccess.READ)
	if visual == null or second == null or file == null or ("client/" + path.trim_prefix("res://")) not in credited:
		return {}
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	var copies := second.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() or copies.size() != meshes.size():
		return {}

	var result := {"weapon": gun.weapon_id, "glb_bytes": file.get_length(), "triangles": 0,
		"surfaces": 0, "lod_surfaces": 0, "materials": 0,
		"texture_bytes": 0, "maps": []}
	var materials := {}
	var images := {}
	for n in range(meshes.size()):
		var mi := meshes[n] as MeshInstance3D
		var copy := copies[n] as MeshInstance3D
		if mi.mesh == null or copy.mesh != mi.mesh:
			return {}
		for surface in range(mi.mesh.get_surface_count()):
			var raw := RenderingServer.mesh_get_surface(mi.mesh.get_rid(), surface)
			if raw.is_empty() or int(raw.primitive) != Mesh.PRIMITIVE_TRIANGLES:
				return {}
			var index_count := int(raw.get("index_count", 0))
			var vert_count := int(raw.vertex_count)
			result["triangles"] += (index_count if index_count > 0 else vert_count) / 3
			result["surfaces"] += 1
			if not raw.get("lods", []).is_empty():
				result["lod_surfaces"] += 1

			var material := mi.get_surface_override_material(surface) as BaseMaterial3D
			if material == null or copy.get_surface_override_material(surface) != material:
				return {}
			if materials.has(material.get_rid()):
				continue
			materials[material.get_rid()] = true
			for slot: StringName in RuntimeGLB.TEXTURE_SLOTS:
				var texture := material.get(slot) as Texture2D
				if texture == null:
					continue
				var texture_id := texture.get_rid()
				if not images.has(texture_id):
					var data := texture.get_image()
					if data == null or not data.has_mipmaps():
						return {}
					var size := data.get_data_size()
					images[texture_id] = {"width": data.get_width(), "height": data.get_height(),
						"image_format": data.get_format(), "mip_levels": data.get_mipmap_count() + 1,
						"bytes": size, "slots": []}
					result["texture_bytes"] += size
				if slot not in images[texture_id]["slots"]:
					images[texture_id]["slots"].append(slot)
	result["materials"] = materials.size()
	result["maps"] = images.values()
	return result


func run() -> void:
	var credits := preload("res://resources/asset_credits.tres")
	var credited: Array = credits.get_meta("asset_files", [])
	for i in range(IDS.size()):
		var gun := WEAPONS[i].new() as WeaponBase
		var started := Time.get_ticks_usec()
		root.add_child(gun)
		var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
		var copy := WEAPONS[i].new() as WeaponBase
		started = Time.get_ticks_usec()
		root.add_child(copy)
		var cached_ms := (Time.get_ticks_usec() - started) / 1000.0
		var row := validate_weapon(gun, copy, credited)
		if gun.weapon_id != IDS[i] or row.is_empty() or int(row.triangles) <= 0 or row.maps.is_empty():
			push_error("Runtime arsenal audit failed for " + IDS[i])
			quit(1)
			return
		row["cold_ms"] = cold_ms
		row["cached_ms"] = cached_ms
		print("HELD_WEAPON_AUDIT ", JSON.stringify(row))
		gun.queue_free()
		copy.queue_free()
		await process_frame
	print("held_weapon_audit: PASS models=", IDS.size())
	await preload("res://tests/support/finish.gd").success(self)
