extends SceneTree
## Automated Scene Cost Measurement for Sprint 35 Programme Acceptance.
## Measures triangle counts, surfaces, materials, textures, and decoded VRAM bytes.

const TARGETS: Dictionary = {
	"SGC Base (SGCUATBase)": "res://scenes/main/SGCUATBase.tscn",
	"Alpha Site Outpost": "res://scenes/mission/TauriAlphaSiteMission.tscn",
	"Mothership Boarding Route": "res://scenes/mission/GoauldMothershipBoardingMission.tscn",
	"Mothership Objective Route": "res://scenes/mission/GoauldMothershipObjectiveMission.tscn",
	"Mothership Exterior Silhouette": "res://scenes/props/MothershipExteriorSilhouette.tscn",
	"Mothership Hangar Vista": "res://scenes/props/MothershipHangarVista.tscn",
	"Mothership Viewport Frame": "res://scenes/props/MothershipViewportFrame.tscn",
	"SGC Airman Character Rig": "res://scenes/entities/SGCAirman.tscn",
	"SGC Civilian Visual": "res://scenes/entities/SGCCivilian.tscn"
}

func _init() -> void:
	call_deferred("run")

func measure_node(node: Node) -> Dictionary:
	var triangles: int = 0
	var surfaces: int = 0
	var materials: Dictionary = {}
	var textures: Dictionary = {}
	var mesh_count: int = 0
	
	var mesh_nodes: Array = []
	if node is MeshInstance3D:
		mesh_nodes.append(node)
	mesh_nodes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	
	for mesh_node: MeshInstance3D in mesh_nodes:
		if mesh_node.mesh == null:
			continue
		mesh_count += 1
		for surface in range(mesh_node.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size() / 3
			elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += verts.size() / 3
			
			var mat: Material = mesh_node.get_active_material(surface)
			if mat != null:
				materials[mat] = true
				if mat is StandardMaterial3D:
					var std_mat: StandardMaterial3D = mat as StandardMaterial3D
					for tex: Texture2D in [
						std_mat.albedo_texture,
						std_mat.normal_texture,
						std_mat.orm_texture,
						std_mat.roughness_texture,
						std_mat.metallic_texture,
						std_mat.emission_texture,
						std_mat.ao_texture
					]:
						if tex != null:
							textures[tex] = true

	var texture_bytes: int = 0
	for tex: Texture2D in textures:
		var img: Image = tex.get_image()
		if img != null:
			texture_bytes += img.get_data_size()
			
	return {
		"triangles": triangles,
		"surfaces": surfaces,
		"meshes": mesh_count,
		"materials": materials.size(),
		"textures": textures.size(),
		"texture_bytes": texture_bytes
	}

func run() -> void:
	print("================================================================================")
	print("SPRINT 35 PROGRAMME ACCEPTANCE: SCENE COST AUDIT")
	print("================================================================================")
	var results: Dictionary = {}
	
	for label: String in TARGETS:
		var path: String = TARGETS[label]
		var scene: PackedScene = load(path)
		if scene == null:
			print("FAIL: Could not load scene: ", path)
			continue
		var instance: Node = scene.instantiate()
		root.add_child(instance)
		
		# If the node has layout assembly or submodules, wait a tick
		for i in range(5):
			await process_frame
			
		var stats: Dictionary = measure_node(instance)
		results[label] = stats
		print("%-32s | Triangles: %7d | Meshes: %4d | Mats: %3d | Textures: %2d | VRAM: %6.2f MB" % [
			label,
			stats.triangles,
			stats.meshes,
			stats.materials,
			stats.textures,
			float(stats.texture_bytes) / (1024.0 * 1024.0)
		])
		
		instance.queue_free()
		await process_frame
		
	print("================================================================================")
	DirAccess.make_dir_recursive_absolute("build/sprint35")
	var file := FileAccess.open("build/sprint35/scene_costs.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "\t"))
		file.close()
		print("Saved measurements to build/sprint35/scene_costs.json")
	quit(0)
