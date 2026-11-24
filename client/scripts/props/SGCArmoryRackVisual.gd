extends MeshInstance3D
## Two identical equipment cabinets share this visual mesh. Their CSG parents still provide cover.

static var cabinet_mesh: ArrayMesh
static var cabinet_material: StandardMaterial3D


func _ready() -> void:
	if cabinet_mesh == null:
		cabinet_mesh = build_cabinet()
		cabinet_material = StandardMaterial3D.new()
		cabinet_material.vertex_color_use_as_albedo = true
		cabinet_material.roughness = 0.67
	mesh = cabinet_mesh
	material_override = cabinet_material


static func build_cabinet() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new().get_mesh_arrays()
	var frame := Color("303b3a")
	var panel := Color("4b5650")
	var trim := Color("68736b")
	var vents := Color("252e2d")
	add_box(tool, cube, Vector3(0.046, 0, 0), Vector3(0.708, 2.8, 4.0), frame)
	for y: float in [-1.30, 1.30]:
		add_box(tool, cube, Vector3(-0.355, y, 0), Vector3(0.09, 0.20, 4.0), frame)
	for bay in range(4):
		var z := float(bay) - 1.5
		add_box(tool, cube, Vector3(-0.342, 0, z), Vector3(0.065, 2.32, 0.94), panel)
		add_box(tool, cube, Vector3(-0.382, 0.37, z + 0.12), Vector3(0.018, 0.90, 0.58), frame)
		add_box(tool, cube, Vector3(-0.393, 0.34, z - 0.28), Vector3(0.014, 0.30, 0.07), trim)
		add_box(tool, cube, Vector3(-0.383, 0.89, z - 0.21), Vector3(0.014, 0.08, 0.25), trim)
		for louver in range(5):
			var y := -0.56 - louver * 0.075
			add_box(tool, cube, Vector3(-0.381, y, z), Vector3(0.012, 0.016, 0.60), vents)
	tool.index()
	return tool.commit()


static func add_box(tool: SurfaceTool, cube: Array, center: Vector3, size: Vector3, tint: Color) -> void:
	for index: int in cube[Mesh.ARRAY_INDEX]:
		var vertex: Vector3 = cube[Mesh.ARRAY_VERTEX][index]
		tool.set_normal(cube[Mesh.ARRAY_NORMAL][index])
		tool.set_color(tint)
		tool.add_vertex(center + vertex * size)
