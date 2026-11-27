extends RefCounted
## Original low-poly falcon silhouette, in metres in the guard's +Z-forward fitting frame.

const BILL_AXES := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)


static func build() -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name = "HorusHelmet"
	var shell := loft([
		Vector4(-0.148, 0.062, 0.055, -0.025),
		Vector4(-0.103, 0.091, 0.081, -0.024),
		Vector4(-0.012, 0.129, 0.109, -0.021),
		Vector4(0.072, 0.156, 0.122, -0.028),
		Vector4(0.162, 0.159, 0.128, -0.038),
		Vector4(0.229, 0.137, 0.123, -0.053),
		Vector4(0.278, 0.080, 0.088, -0.084),
		Vector4(0.296, 0.0, 0.0, -0.106),
	], 16)
	var crest := loft([
		Vector4(0.082, 0.061, 0.039, -0.153),
		Vector4(0.183, 0.054, 0.047, -0.166),
		Vector4(0.276, 0.043, 0.062, -0.173),
		Vector4(0.337, 0.027, 0.057, -0.211),
		Vector4(0.388, 0.014, 0.038, -0.248),
		Vector4(0.412, 0.0, 0.0, -0.280),
	], 10)
	var bill := loft([
		Vector4(0.038, 0.089, 0.065, -0.131),
		Vector4(0.117, 0.096, 0.060, -0.130),
		Vector4(0.180, 0.080, 0.048, -0.108),
		Vector4(0.229, 0.057, 0.035, -0.080),
		Vector4(0.266, 0.038, 0.028, -0.040),
		Vector4(0.288, 0.019, 0.025, -0.001),
		Vector4(0.291, 0.0, 0.0, 0.038),
	], 14, BILL_AXES)
	var steel := SurfaceTool.new()
	steel.append_from(shell, 0, Transform3D.IDENTITY)
	steel.append_from(crest, 0, Transform3D.IDENTITY)
	steel.set_material(finish(Color(0.15, 0.22, 0.25), 0.60, 0.46))
	steel.commit(result)

	var trim := SurfaceTool.new()
	trim.append_from(bill, 0, Transform3D.IDENTITY)
	var feather := loft([
		Vector4(-0.109, 0.0, 0.0, 0.014),
		Vector4(-0.072, 0.026, 0.031, 0.009),
		Vector4(0.061, 0.037, 0.029, -0.024),
		Vector4(0.115, 0.020, 0.021, -0.051),
		Vector4(0.129, 0.0, 0.0, -0.063),
	], 8)
	for side: float in [-1.0, 1.0]:
		for layer in range(3):
			var tilt := Basis.from_euler(Vector3(0.26, side * 0.12, -side * 0.19))
			var offset := Vector3(side * (0.119 + 0.011 * layer), 0.054 - 0.044 * layer, -0.105 - 0.033 * layer)
			trim.append_from(feather, 0, Transform3D(tilt, offset))
	trim.set_material(finish(Color(0.52, 0.40, 0.24), 0.63, 0.43))
	trim.commit(result)

	var eye := SphereMesh.new()
	eye.radial_segments = 12
	eye.rings = 4
	var sockets := SurfaceTool.new()
	var visor := SurfaceTool.new()
	for side: float in [-1.0, 1.0]:
		var facing := Basis.from_euler(Vector3(-0.09, side * 0.62, side * 0.27))
		var position := Vector3(side * 0.104, 0.158, 0.063)
		sockets.append_from(eye, 0, Transform3D(facing * Basis.from_scale(Vector3(0.112, 0.053, 0.038)), position))
		visor.append_from(eye, 0, Transform3D(facing * Basis.from_scale(Vector3(0.081, 0.018, 0.016)), position + facing.z * 0.019))
		var vent := Basis.from_euler(Vector3(0.24, side * 1.13, side * 0.32))
		sockets.append_from(eye, 0, Transform3D(vent * Basis.from_scale(Vector3(0.047, 0.016, 0.009)), Vector3(side * 0.083, 0.135, 0.168)))
		var cheek := Basis.from_euler(Vector3(-0.65, side * 0.43, side * -0.50))
		sockets.append_from(eye, 0, Transform3D(cheek * Basis.from_scale(Vector3(0.045, 0.135, 0.041)), Vector3(side * 0.121, 0.054, 0.058)))
	sockets.set_material(finish(Color(0.035, 0.078, 0.093), 0.3, 0.54))
	sockets.commit(result)
	var light := finish(Color(0.11, 0.56, 0.60), 0.12, 0.26)
	light.emission_enabled = true
	light.emission = Color(0.08, 0.68, 0.75)
	light.emission_energy_multiplier = 0.75
	visor.set_material(light)
	visor.commit(result)
	return result


# Each row holds the axis position, half-width, half-depth and depth offset.
static func loft(rows: Array[Vector4], segments: int, axes := Basis.IDENTITY) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows.size() - 1):
		var lower := rows[row]
		var upper := rows[row + 1]
		for segment in range(segments):
			var a := TAU * float(segment) / segments
			var b := TAU * float(segment + 1) / segments
			var low_a := section_point(lower, a)
			var low_b := section_point(lower, b)
			var high_a := section_point(upper, a)
			var high_b := section_point(upper, b)
			if lower.y > 0.0:
				tool.add_vertex(axes * low_a)
				tool.add_vertex(axes * low_b)
				tool.add_vertex(axes * high_a)
			if upper.y > 0.0:
				tool.add_vertex(axes * low_b)
				tool.add_vertex(axes * high_b)
				tool.add_vertex(axes * high_a)
	tool.index()
	tool.generate_normals()
	return tool.commit()


static func section_point(row: Vector4, angle: float) -> Vector3:
	return Vector3(row.y * cos(angle), row.x, row.w + row.z * sin(angle))


static func finish(tint: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.metallic = metallic
	result.roughness = roughness
	return result
