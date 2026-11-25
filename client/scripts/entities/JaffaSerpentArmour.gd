extends RefCounted
## Fits the armour in the shared humanoid's initial +Z-forward ready frame.

const CACHE := &"serpent_armour_resources"
const HELMET_CACHE := &"serpent_helmet_review_scene"
const ANCHORS: Array[StringName] = [
	&"Head", &"Chest", &"Hips", &"LeftUpperArm", &"RightUpperArm",
	&"LeftLowerArm", &"RightLowerArm", &"LeftLowerLeg", &"RightLowerLeg",
]

var kit: Dictionary
var fitting_axes: Basis


func fit(skeleton: Skeleton3D, bones: BoneMap, model_basis: Basis, helmet_path: String) -> bool:
	var indices: Dictionary = {}
	for anchor: StringName in ANCHORS:
		var index := skeleton.find_bone(bones.get_skeleton_bone_name(anchor))
		if index < 0:
			return false
		indices[anchor] = index

	var root := skeleton.get_tree().root
	if not root.has_meta(CACHE):
		root.set_meta(CACHE, make_kit())
	kit = root.get_meta(CACHE)
	fitting_axes = skeleton.global_basis.orthonormalized().inverse() * model_basis.orthonormalized()

	var head := attach(skeleton, indices[&"Head"], &"SerpentHelmet")
	var helmet := load_review_helmet(root, helmet_path)
	if helmet == null:
		fit_native_helmet(head)
	else:
		head.add_child(helmet)
		helmet.position = Vector3(0.0, -0.244, -0.065)
		helmet.scale = Vector3.ONE * 0.096

	fit_body(skeleton, indices)
	return true


func load_review_helmet(root: Window, path: String) -> Node3D:
	if path.is_empty():
		return null
	if not root.has_meta(HELMET_CACHE):
		var candidate := RuntimeGLB.load_scene(path)
		var packed: PackedScene
		if candidate != null:
			var materials: Dictionary[BaseMaterial3D, bool] = {}
			for part: MeshInstance3D in candidate.find_children("*", "MeshInstance3D", true, false):
				for surface in range(part.mesh.get_surface_count()):
					var material := part.get_active_material(surface) as BaseMaterial3D
					if material != null and not materials.has(material):
						RuntimeGLB.add_mipmaps(material)
						materials[material] = true
			if not materials.is_empty():
				for node: Node in candidate.find_children("*", "", true, false):
					node.owner = candidate
				packed = PackedScene.new()
				if packed.pack(candidate) != OK:
					packed = null
			candidate.free()
		if packed == null:
			push_warning("Unable to fit the supplied Serpent helmet. Using the native preview helmet.")
		root.set_meta(HELMET_CACHE, {"scene": packed})
	var cached := root.get_meta(HELMET_CACHE).scene as PackedScene
	return cached.instantiate() as Node3D if cached != null else null


func fit_native_helmet(head: Node3D) -> void:
	part(head, kit.hood, kit.bronze, Vector3.ZERO, Vector3.ONE)
	part(head, kit.round, kit.iron, Vector3(0, 0.106, 0.039), Vector3(0.274, 0.342, 0.278))
	part(head, kit.round, kit.bronze, Vector3(0, 0.033, 0.126), Vector3(0.216, 0.167, 0.156))
	part(head, kit.round, kit.iron, Vector3(0, 0.133, 0.164), Vector3(0.238, 0.076, 0.047))
	for side: float in [-1.0, 1.0]:
		var eye := part(head, kit.round, kit.eyes, Vector3(side * 0.054, 0.137, 0.186), Vector3(0.070, 0.021, 0.018))
		eye.rotation.z = side * 0.24
		for rib in range(3):
			var band := part(head, kit.round, kit.trim, Vector3(side * (0.154 + rib * 0.026), 0.106 + rib * 0.048, 0.031), Vector3(0.066, 0.21, 0.036))
			band.rotation.z = side * -0.43
	part(head, kit.round, kit.trim, Vector3(0, 0.227, 0.128), Vector3(0.042, 0.164, 0.054))


func fit_body(skeleton: Skeleton3D, indices: Dictionary) -> void:
	var chest := attach(skeleton, indices[&"Chest"], &"Cuirass")
	part(chest, kit.round, kit.iron, Vector3(0, 0.078, 0.011), Vector3(0.53, 0.38, 0.43))
	part(chest, kit.round, kit.bronze, Vector3(0, 0.123, 0.208), Vector3(0.408, 0.188, 0.086))
	for tier in range(4):
		var width := 0.41 - tier * 0.038
		part(chest, kit.round, kit.trim, Vector3(0, 0.062 - tier * 0.045, 0.219 - tier * 0.014), Vector3(width, 0.056, 0.065))
	var waist := attach(skeleton, indices[&"Hips"], &"WaistArmour")
	part(waist, kit.round, kit.iron, Vector3(0, -0.004, 0.005), Vector3(0.47, 0.19, 0.34))
	part(waist, kit.round, kit.trim, Vector3(0, -0.004, 0.166), Vector3(0.106, 0.087, 0.064))

	for side: String in ["Left", "Right"]:
		var outward := 1.0 if side == "Left" else -1.0
		var shoulder := attach(skeleton, indices[StringName(side + "UpperArm")], StringName(side + "Pauldron"))
		var cap := part(shoulder, kit.round, kit.bronze, Vector3(outward * 0.018, 0.006, 0.012), Vector3(0.226, 0.143, 0.245))
		cap.rotation.z = -outward * 0.20
		var edge := part(shoulder, kit.round, kit.trim, Vector3(outward * 0.033, -0.039, 0.035), Vector3(0.210, 0.056, 0.21))
		edge.rotation.z = cap.rotation.z
		var arm := attach(skeleton, indices[StringName(side + "LowerArm")], StringName(side + "Vambrace"))
		part(arm, kit.round, kit.iron, Vector3(0, -0.047, 0.025), Vector3(0.135, 0.164, 0.147))
		var leg := attach(skeleton, indices[StringName(side + "LowerLeg")], StringName(side + "Greave"))
		part(leg, kit.round, kit.bronze, Vector3(0, -0.09, 0.054), Vector3(0.164, 0.278, 0.115))
		part(leg, kit.round, kit.trim, Vector3(0, -0.019, 0.087), Vector3(0.127, 0.066, 0.045))


func attach(skeleton: Skeleton3D, index: int, label: StringName) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = skeleton.get_bone_name(index)
	skeleton.add_child(attachment)
	var fitting_frame := Node3D.new()
	fitting_frame.basis = skeleton.get_bone_global_pose(index).basis.orthonormalized().inverse() * fitting_axes
	attachment.add_child(fitting_frame)
	return fitting_frame


func part(parent: Node3D, mesh: Mesh, finish: Material, at: Vector3, size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = finish
	instance.position = at
	instance.scale = size
	parent.add_child(instance)
	return instance


func make_kit() -> Dictionary:
	var round := SphereMesh.new()
	round.radial_segments = 16
	round.rings = 8
	var eyes := finish(Color(0.51, 0.063, 0.024), 0.15)
	eyes.emission_enabled = true
	eyes.emission = Color(0.82, 0.108, 0.034)
	eyes.emission_energy_multiplier = 0.72
	return {
		"round": round,
		"hood": make_hood(),
		"bronze": finish(Color(0.27, 0.19, 0.107), 0.33),
		"trim": finish(Color(0.43, 0.31, 0.173), 0.31),
		"iron": finish(Color(0.092, 0.092, 0.087), 0.26),
		"eyes": eyes,
	}


func finish(tint: Color, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.metallic = metallic
	result.roughness = 0.65
	return result


func make_hood() -> ArrayMesh:
	# Each row stores height, half width and half depth. The collar flares up from the neck.
	var sections: Array[Vector3] = [
		Vector3(-0.09, 0.015, 0.015), Vector3(-0.056, 0.112, 0.103),
		Vector3(0.065, 0.196, 0.098), Vector3(0.178, 0.237, 0.085),
		Vector3(0.272, 0.214, 0.073), Vector3(0.332, 0.141, 0.055),
		Vector3(0.362, 0.013, 0.009),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in range(sections.size() - 1):
		for angle in range(20):
			var a := TAU * angle / 20.0
			var b := TAU * (angle + 1) / 20.0
			var lower := sections[section]
			var upper := sections[section + 1]
			for point: Vector3 in [
				hood_point(lower, a), hood_point(lower, b), hood_point(upper, a),
				hood_point(lower, b), hood_point(upper, b), hood_point(upper, a),
			]:
				tool.add_vertex(point)
	tool.index()
	tool.generate_normals()
	return tool.commit()


func hood_point(section: Vector3, angle: float) -> Vector3:
	return Vector3(section.y * cos(angle), section.x, -0.086 + section.z * sin(angle))
