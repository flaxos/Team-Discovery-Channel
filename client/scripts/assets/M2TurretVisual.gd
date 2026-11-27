extends RefCounted
## One shared import. The gun uses the existing aiming pivot and the tripod stays at the scene root.

const MODEL := "res://assets/weapons/browning_m2.glb"
const PART_NAMES := [&"M2Gun", &"M2Tripod"]
static var _parts: Dictionary = {}


static func attach(turret: Node3D, head: Node3D) -> bool:
	if head == null or (_parts.is_empty() and not _load_parts()):
		return false
	_add_part(PART_NAMES[0], head)
	_add_part(PART_NAMES[1], turret)
	return true


static func _load_parts() -> bool:
	var scene := RuntimeGLB.load_scene(MODEL)
	if scene == null:
		return false
	RuntimeGLB.apply_mesh_lods(scene)
	var materials := {}
	var parts := {}
	for name: StringName in PART_NAMES:
		var part := scene.find_child(name, true, false) as Node3D
		var mesh_node := part.get_node_or_null(String(name) + "Mesh") as MeshInstance3D if part != null else null
		if mesh_node == null or mesh_node.mesh == null:
			scene.free()
			return false
		var mesh := mesh_node.mesh as ArrayMesh
		if mesh == null:
			scene.free()
			return false
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and not materials.has(material):
				# Match the held weapons under the current SGC lighting, retaining the packed ORM maps.
				material.metallic = 0.0
				RuntimeGLB.add_mipmaps(material)
				materials[material] = true
		parts[name] = {"mesh": mesh, "transform": part.transform * mesh_node.transform}
	scene.free()
	_parts = parts
	return true


static func _add_part(name: StringName, parent: Node3D) -> void:
	var part: Dictionary = _parts[name]
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = part.mesh
	visual.transform = part.transform
	parent.add_child(visual)
