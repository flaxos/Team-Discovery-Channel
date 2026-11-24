extends MeshInstance3D
## These silhouettes fit the original Level 26 staging and storage colliders.

enum Style { CABINET, CASES }

@export var style := Style.CABINET

const FRAME := Color(0.27, 0.33, 0.35)
const CASING := Color(0.62, 0.69, 0.68)
const TEAL := Color(0.22, 0.48, 0.47)
const LABEL := Color(0.75, 0.81, 0.77)


func _ready() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new().get_mesh_arrays()
	match style:
		Style.CABINET:
			build_cabinet(tool, cube)
		Style.CASES:
			build_cases(tool, cube)
	tool.index()
	mesh = tool.commit()
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.75
	material_override = finish


func build_cabinet(tool: SurfaceTool, cube: Array) -> void:
	add_panel(tool, cube, Vector3(0, 0.01, -0.04), Vector3(1.56, 0.86, 0.91), CASING)
	add_panel(tool, cube, Vector3(0, 0.468, 0), Vector3(1.60, 0.064, 1), TEAL)
	add_panel(tool, cube, Vector3(0, -0.46, 0.02), Vector3(1.60, 0.08, 0.96), FRAME)
	for x: float in [-0.388, 0.388]:
		add_panel(tool, cube, Vector3(x, -0.02, 0.441), Vector3(0.73, 0.74, 0.064), CASING.darkened(0.12))
		add_panel(tool, cube, Vector3(x, 0.18, 0.479), Vector3(0.29, 0.048, 0.04), FRAME)
		add_panel(tool, cube, Vector3(x - 0.14, 0.29, 0.476), Vector3(0.29, 0.07, 0.012), LABEL)


func build_cases(tool: SurfaceTool, cube: Array) -> void:
	for y: float in [-0.6, 0.0, 0.6]:
		for x: float in [-0.375, 0.375]:
			add_panel(tool, cube, Vector3(x, y, 0), Vector3(0.73, 0.59, 1.36), FRAME)
			add_panel(tool, cube, Vector3(x, y + 0.23, -0.008), Vector3(0.738, 0.14, 1.384), TEAL)
			add_panel(tool, cube, Vector3(x, y - 0.15, 0.684), Vector3(0.72, 0.066, 0.032), FRAME.darkened(0.35))
			add_panel(tool, cube, Vector3(x, y + 0.04, 0.684), Vector3(0.16, 0.058, 0.027), LABEL)
			for offset: float in [-0.26, 0.26]:
				add_panel(tool, cube, Vector3(x + offset, y + 0.17, 0.684), Vector3(0.06, 0.11, 0.032), CASING)


func add_panel(tool: SurfaceTool, cube: Array, center: Vector3, size: Vector3, tint: Color) -> void:
	for index: int in cube[Mesh.ARRAY_INDEX]:
		var vertex: Vector3 = cube[Mesh.ARRAY_VERTEX][index]
		tool.set_normal(cube[Mesh.ARRAY_NORMAL][index])
		tool.set_color(tint)
		tool.add_vertex(center + vertex * size)
