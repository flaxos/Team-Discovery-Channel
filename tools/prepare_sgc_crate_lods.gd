extends SceneTree
## Dump the actual Godot vertex order or bake the offline index levels into a shared ArrayMesh.

const SOURCE := "res://assets/props/plastic_crate_02_1k.glb"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["dump", "bake"]:
		push_error("Use -- dump <working-dir> or -- bake <working-dir>")
		quit(1)
		return
	var working := args[1]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(SOURCE, state) == OK, "Cannot read the source crate")
	var scene := doc.generate_scene(state)
	var models := scene.find_children("*", "MeshInstance3D", true, false)
	assert(models.size() == 1, "Expected one crate mesh")
	var source := (models[0] as MeshInstance3D).mesh as ArrayMesh
	assert(source.get_surface_count() == 1, "Expected one crate surface")
	var arrays := source.surface_get_arrays(0)
	if args[0] == "dump":
		var positions: Array[float] = []
		var attributes: Array[float] = []
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
			var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
			var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
			positions.append_array([v.x, v.y, v.z])
			attributes.append_array([n.x, n.y, n.z, uv.x, uv.y])
		var file := FileAccess.open(working.path_join("source.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"positions": positions, "attributes": attributes, "indices": Array(arrays[Mesh.ARRAY_INDEX]),
		}))
	else:
		var levels: Array = JSON.parse_string(FileAccess.get_file_as_string(working.path_join("levels.json")))
		var lods := {}
		for level: Dictionary in levels:
			lods[float(level["distance"])] = PackedInt32Array(level["indices"])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
		assert(ResourceSaver.save(mesh, working.path_join("plastic_crate_02_lods.res")) == OK)
	scene.free()
	quit()
