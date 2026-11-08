extends Node3D
## Continuous helical collision surface; visual treads never block the capsule.
const CENTER: Vector3 = Vector3(-5.0, 0.0, 11.0)
const RADIUS: float = 1.6
const WIDTH: float = 1.2
const BASE_Y: float = 0.95
const TOP_Y: float = 5.5
const SWEEP: float = TAU * 1.25

func path_point(t: float) -> Vector3:
	return CENTER + Vector3(cos(t * SWEEP) * RADIUS, lerpf(BASE_Y, TOP_Y, t), sin(t * SWEEP) * RADIUS)

func _ready() -> void:
	var faces := PackedVector3Array()
	for i: int in range(120):
		var a: float = float(i) / 120.0
		var b: float = float(i + 1) / 120.0
		var a_dir := Vector3(cos(a * SWEEP), 0, sin(a * SWEEP))
		var b_dir := Vector3(cos(b * SWEEP), 0, sin(b * SWEEP))
		var p0: Vector3 = path_point(a) - a_dir * WIDTH * 0.5
		var p1: Vector3 = path_point(a) + a_dir * WIDTH * 0.5
		var p2: Vector3 = path_point(b) - b_dir * WIDTH * 0.5
		var p3: Vector3 = path_point(b) + b_dir * WIDTH * 0.5
		faces.append_array(PackedVector3Array([p0, p2, p1, p1, p2, p3]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.name = "HelicalWalkSurface"
	body.add_child(collider)
	add_child(body)
