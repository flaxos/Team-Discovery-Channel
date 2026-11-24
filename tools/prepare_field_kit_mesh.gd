extends SceneTree
## Bake the needed tangent space into the staged, oriented rigid GLB before packing maps.

func _init() -> void:
	call_deferred("run")


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		printerr("usage: -- <staged rigid .glb> <tangent-ready .glb>")
		quit(1)
		return
	var model := RuntimeGLB.load_scene(arguments[0])
	var parts := model.find_children("*", "MeshInstance3D", true, false) if model != null else []
	if parts.size() != 1:
		if model != null:
			model.free()
		printerr("Expected one staged rigid mesh")
		quit(1)
		return
	var part := parts[0] as MeshInstance3D
	var source := part.mesh as ArrayMesh
	var prepared := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var tool := SurfaceTool.new()
		tool.create_from(source, surface)
		if not source.surface_get_format(surface) & Mesh.ARRAY_FORMAT_NORMAL:
			tool.generate_normals()
		tool.generate_tangents()
		tool.set_material(source.surface_get_material(surface))
		tool.commit(prepared)
	part.mesh = prepared
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(model, state)
	if result == OK:
		result = document.write_to_filesystem(state, arguments[1])
	model.free()
	quit(0 if result == OK else 1)
