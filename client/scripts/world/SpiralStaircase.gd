extends Node3D
## Continuous walk surface with segmented guard infill. Decorative treads have no collision.
const CENTER := Vector3(-4.5, 0, 12)
const RADIUS: float = 1.6
const WIDTH: float = 1.6
const BASE_Y: float = SGCMapDefinition.CONTROL_FLOOR_Y
const TOP_Y: float = 5.5
const SWEEP: float = TAU * 1.25


func path_point(t: float) -> Vector3:
	return (
		CENTER
		+ Vector3(
			cos(t * SWEEP + PI / 2) * RADIUS,
			lerpf(BASE_Y, TOP_Y, t),
			sin(t * SWEEP + PI / 2) * RADIUS
		)
	)


func _ready() -> void:
	var faces := PackedVector3Array()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.23, 0.25)
	mat.metallic = 0.45
	mat.roughness = 0.65
	for i in range(120):
		var a := float(i) / 120
		var b := float(i + 1) / 120
		var ad := Vector3(cos(a * SWEEP + PI / 2), 0, sin(a * SWEEP + PI / 2))
		var bd := Vector3(cos(b * SWEEP + PI / 2), 0, sin(b * SWEEP + PI / 2))
		var p0 := path_point(a) - ad * WIDTH / 2
		var p1 := path_point(a) + ad * WIDTH / 2
		var p2 := path_point(b) - bd * WIDTH / 2
		var p3 := path_point(b) + bd * WIDTH / 2
		faces.append_array(PackedVector3Array([p0, p2, p1, p1, p2, p3]))
		if i % 3 == 0:
			var tread := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(WIDTH, 0.08, 0.35)
			tread.mesh = box
			tread.material_override = mat
			tread.position = path_point(a) - Vector3(0, 0.05, 0)
			tread.rotation.y = -(a * SWEEP + PI / 2)
			add_child(tread)
		for edge: float in [-1.0, 1.0]:
			# Full infill collider prevents slipping between balusters; caps are the handrail.
			var a_edge := path_point(a) + ad * (WIDTH / 2 + 0.06) * edge
			var b_edge := path_point(b) + bd * (WIDTH / 2 + 0.06) * edge
			var body := StaticBody3D.new()
			body.position = (a_edge + b_edge) / 2 + Vector3(0, 0.55, 0)
			var delta := b_edge - a_edge
			body.rotation.y = atan2(delta.x, delta.z)
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.10, 1.12, delta.length() + 0.025)
			collider.shape = shape
			body.add_child(collider)
			var visual := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.07, delta.length() + 0.025)
			visual.mesh = box
			visual.position.y = 0.5
			visual.material_override = mat
			body.add_child(visual)
			if i % 4 == 0:
				var post := MeshInstance3D.new()
				var post_box := BoxMesh.new()
				post_box.size = Vector3(0.06, 1.05, 0.06)
				post.mesh = post_box
				post.material_override = mat
				body.add_child(post)
			add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.name = "HelicalWalkSurface"
	body.add_child(collider)
	add_child(body)
	var surface := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.mesh = mesh
	surface.material_override = mat
	add_child(surface)
