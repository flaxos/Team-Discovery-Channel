extends MeshInstance3D
## The pipe and its couplings stay within the existing rectangular conduit slot.

const PIPE_COLOR := Color(0.30, 0.36, 0.38)
const COUPLING_COLOR := Color(0.14, 0.17, 0.18)
const COUPLING_LENGTH := 0.085


func fit_to_slot(size: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := minf(size.x, size.y) * 0.5
	append_cylinder(surface, radius * 0.73, size.z, 0.0, PIPE_COLOR)
	var half_span := (size.z - COUPLING_LENGTH) * 0.5
	var sections := maxi(1, ceili(size.z / 2.4))
	for joint in range(sections + 1):
		var center := lerpf(-half_span, half_span, float(joint) / sections)
		append_cylinder(surface, radius, COUPLING_LENGTH, center, COUPLING_COLOR)
	surface.index()
	mesh = surface.commit()


func append_cylinder(surface: SurfaceTool, radius: float, length: float, center: float, tint: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 12
	cylinder.rings = 0
	var arrays := cylinder.get_mesh_arrays()
	var along_z := Basis(Vector3.RIGHT, PI / 2.0)
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		surface.set_normal(along_z * arrays[Mesh.ARRAY_NORMAL][index])
		surface.set_color(tint)
		surface.add_vertex(along_z * arrays[Mesh.ARRAY_VERTEX][index] + Vector3(0, 0, center))
