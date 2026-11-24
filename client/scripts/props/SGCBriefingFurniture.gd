extends MeshInstance3D
## Collision remains on the authored furniture box. The full hull gives cover;
## the top, apron and upholstery give each box a readable silhouette.

enum Form { SEAT, TABLE, DESK }

@export var form := Form.SEAT


func _ready() -> void:
	var body := get_parent() as CSGBox3D
	if body == null or not body.material is StandardMaterial3D:
		return
	var yaw := roundi(rotation.y / (PI / 2.0))
	var size := Vector3(body.size.z, body.size.y, body.size.x) if absi(yaw) % 2 == 1 else body.size
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new().get_mesh_arrays()
	if form == Form.SEAT:
		build_seat(tool, cube, size)
	else:
		build_casework(tool, cube, size)
	tool.index()
	mesh = tool.commit()
	if not AABB(-body.size / 2.0, body.size).grow(0.002).encloses(transform * get_aabb()):
		mesh = null
		return
	var finish := body.material.duplicate() as StandardMaterial3D
	finish.vertex_color_use_as_albedo = true
	if form == Form.DESK:
		finish.roughness_texture = null
		finish.roughness = 0.58
	material_override = finish
	body.transparency = 1.0
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_seat(tool: SurfaceTool, cube: Array, size: Vector3) -> void:
	var edge := size / 2.0
	add_panel(tool, cube, Vector3(0, -edge.y + 0.035, 0), Vector3(size.x, 0.07, size.z), Color(0.38, 0.39, 0.42))
	add_panel(tool, cube, Vector3(0, -size.y * 0.25, 0.01), Vector3(size.x - 0.036, size.y * 0.47, size.z - 0.036), Color(0.7, 0.72, 0.76))
	add_panel(tool, cube, Vector3(0, -0.02, 0.037), Vector3(size.x - 0.026, 0.13, size.z - 0.09), Color(1.0, 0.96, 0.92))
	add_panel(tool, cube, Vector3(0, edge.y * 0.47, -edge.z + 0.061), Vector3(size.x - 0.015, edge.y * 1.06, 0.12), Color(0.96, 0.94, 0.92))
	for side: float in [-1.0, 1.0]:
		add_panel(tool, cube, Vector3(side * (edge.x - 0.033), 0.06, -0.004), Vector3(0.065, 0.11, size.z - 0.06), Color(0.55, 0.58, 0.62))


func build_casework(tool: SurfaceTool, cube: Array, size: Vector3) -> void:
	var edge := size / 2.0
	add_panel(tool, cube, Vector3(0, edge.y - 0.045, 0), Vector3(size.x, 0.09, size.z), Color.WHITE)
	add_panel(tool, cube, Vector3(0, 0.006, 0), Vector3(size.x - 0.032, size.y - 0.16, size.z - 0.032), Color(0.81, 0.76, 0.73))
	add_panel(tool, cube, Vector3(0, -edge.y + 0.046, 0), Vector3(size.x - 0.06, 0.092, size.z - 0.06), Color(0.43, 0.39, 0.37))
	if form == Form.DESK:
		for z: float in [-0.45, 0.45]:
			for y: float in [-0.17, 0.10]:
				add_panel(tool, cube, Vector3(edge.x - 0.015, y, z), Vector3(0.02, 0.24, 0.56), Color(0.93, 0.84, 0.80))
				add_panel(tool, cube, Vector3(edge.x - 0.012, y + 0.04, z), Vector3(0.024, 0.036, 0.18), Color(0.31, 0.28, 0.25))


func add_panel(tool: SurfaceTool, cube: Array, center: Vector3, size: Vector3, tint: Color) -> void:
	for index: int in cube[Mesh.ARRAY_INDEX]:
		var vertex: Vector3 = cube[Mesh.ARRAY_VERTEX][index]
		tool.set_normal(cube[Mesh.ARRAY_NORMAL][index])
		tool.set_color(tint)
		tool.add_vertex(center + vertex * size)
