extends SceneTree
## Milestone 2: Verify ImporterMesh hardware LODs are attached to heavy runtime GLBs
## (P90, Browning M2 + Tripod, MP5SD, M249, SGC Airman) without altering LOD0 triangles or skinning.

const TURRET := preload("res://scenes/props/DeployableTurret.tscn")
const AIRMAN := preload("res://scenes/entities/SGCAirman.tscn")


func _init() -> void:
	call_deferred("run")


func _check_mesh_lods(mi: MeshInstance3D, label: String, expected_lod0_tris: int = -1) -> int:
	assert(mi != null and mi.mesh != null, "Missing mesh for " + label)
	var surf_count := mi.mesh.get_surface_count()
	var total_tris0 := 0
	var total_index_bytes0 := 0
	var total_index_bytes_lowest := 0
	var total_lods := 0
	for s in range(surf_count):
		var arrays := mi.mesh.surface_get_arrays(s)
		var tris0 := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		total_tris0 += tris0
		var rs: Dictionary = RenderingServer.mesh_get_surface(mi.mesh.get_rid(), s)
		var lod0_bytes := (rs.get("index_data", PackedByteArray()) as PackedByteArray).size()
		total_index_bytes0 += lod0_bytes
		var lods: Array = rs.get("lods", [])
		total_lods += lods.size()
		if lods.is_empty():
			total_index_bytes_lowest += lod0_bytes
		else:
			var lowest_raw: Variant = lods[lods.size() - 1]
			if lowest_raw is Dictionary:
				total_index_bytes_lowest += ((lowest_raw as Dictionary).get("index_data", PackedByteArray()) as PackedByteArray).size()
			elif lowest_raw is Array and (lowest_raw as Array).size() >= 2 and (lowest_raw as Array)[1] is PackedByteArray:
				total_index_bytes_lowest += ((lowest_raw as Array)[1] as PackedByteArray).size()
			elif lowest_raw is PackedByteArray:
				total_index_bytes_lowest += (lowest_raw as PackedByteArray).size()
	if expected_lod0_tris >= 0:
		assert(total_tris0 == expected_lod0_tris, "%s LOD0 tris %d != %d" % [label, total_tris0, expected_lod0_tris])
	assert(total_lods > 0, "%s expected generated LODs" % label)
	assert(total_index_bytes_lowest < total_index_bytes0, "%s lowest LOD %dB not reduced from %dB" % [label, total_index_bytes_lowest, total_index_bytes0])
	print("LOD_VERIFIED %s: surfs=%d lods=%d tris0=%d bytes=%d->%d" % [label, surf_count, total_lods, total_tris0, total_index_bytes0, total_index_bytes_lowest])
	return total_lods


func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)

	var p90 := WeaponP90.new()
	holder.add_child(p90)
	_check_mesh_lods(p90.get_node("WeaponModel/ImportedGLB").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D, "P90", 38083)

	var mp5 := WeaponMP5.new()
	holder.add_child(mp5)
	_check_mesh_lods(mp5.get_node("WeaponModel/ImportedGLB").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D, "MP5SD", 10669)

	var m249 := WeaponM249.new()
	holder.add_child(m249)
	_check_mesh_lods(m249.get_node("WeaponModel/ImportedGLB").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D, "M249")

	var turret := TURRET.instantiate() as DeployableTurret
	holder.add_child(turret)
	_check_mesh_lods(turret.get_node("TurretHead/M2Gun") as MeshInstance3D, "M2Gun")
	_check_mesh_lods(turret.get_node("M2Tripod") as MeshInstance3D, "M2Tripod")

	var airman := AIRMAN.instantiate() as SGCAirmanAI
	holder.add_child(airman)
	airman.set_physics_process(false)
	var rig := airman.get_node(^"Visuals/AirmanRig")
	var skin_lods := 0
	for child: Node in rig.skin_visual.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var total_tris := 0
		for s in range(mi.mesh.get_surface_count()):
			total_tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if total_tris >= 2000:
			skin_lods += _check_mesh_lods(mi, "Airman/" + mi.name)
	assert(skin_lods > 0, "Expected LODs on heavyweight Airman meshes")

	holder.queue_free()
	await physics_frame
	await physics_frame
	print("test_asset_lods: PASS")
	await preload("res://tests/support/finish.gd").success(self)
