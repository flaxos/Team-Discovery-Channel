extends RefCounted
## Fit a prepared rigid mesh into the placeholder's visual space. Physics nodes stay separate.

static var _meshes: Dictionary = {}


static func fit(target: MeshInstance3D, path: String) -> void:
	if target == null or target.mesh == null:
		return
	var model := _meshes.get(path) as ArrayMesh
	if model == null:
		model = _load_mesh(path)
		if model == null:
			return
		_meshes[path] = model
	var original := target.mesh.get_aabb()
	var imported := model.get_aabb()
	var fit_scale := minf(original.size.x / imported.size.x,
		minf(original.size.y / imported.size.y, original.size.z / imported.size.z))
	var centre_offset := original.get_center() - imported.get_center() * fit_scale
	target.mesh = model
	target.transform *= Transform3D(Basis.from_scale(Vector3.ONE * fit_scale), centre_offset)


static func _load_mesh(path: String) -> ArrayMesh:
	var scene := RuntimeGLB.load_scene(path)
	if scene == null:
		return null
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var model: ArrayMesh
	if meshes.size() == 1:
		var node := meshes[0] as MeshInstance3D
		if node.transform.is_equal_approx(Transform3D.IDENTITY):
			model = node.mesh as ArrayMesh
	scene.free()
	if model == null or not model.get_aabb().has_volume():
		return null
	for surface in range(model.get_surface_count()):
		var material := model.surface_get_material(surface) as BaseMaterial3D
		if material != null:
			material.metallic = 0.0
			RuntimeGLB.add_mipmaps(material)
	return model
