class_name SGCCivilianVisual
extends "res://scripts/entities/SGCHumanRig.gd"
## Stationary, peer-local presentation for the authored SGC civilian stations.

enum Role { LABORATORY, MEDICAL, ADMINISTRATION }

const HEAD_PATH := "res://assets/characters/sgc_civilian_head.glb"
const HEAD_CACHE := &"sgc_civilian_head_cache"
const WARDROBES: Array[PackedScene] = [
	preload("res://scenes/entities/SGCLabWardrobe.tscn"),
	preload("res://scenes/entities/SGCMedicalWardrobe.tscn"),
	preload("res://scenes/entities/SGCAdminWardrobe.tscn"),
]
const CLOTHING := {
	&"Object_107": 0, # Shirt and sleeves
	&"Object_113": 1, # Trousers
	&"Object_115": 2, # Hands
	&"Object_123": 3, # Footwear
}
const PALETTES := [
	[Color(0.84, 0.86, 0.84), Color(0.11, 0.145, 0.18), Color(0.27, 0.36, 0.41), Color(0.075, 0.078, 0.083)],
	[Color(0.105, 0.39, 0.37), Color(0.075, 0.26, 0.26), Color(0.22, 0.38, 0.39), Color(0.10, 0.14, 0.15)],
	[Color(0.30, 0.42, 0.57), Color(0.13, 0.145, 0.17), Color(0.53, 0.38, 0.29), Color(0.10, 0.087, 0.076)],
]
const HEAD_HOME := Vector3(0.027, 1.378, -0.081)
const STANDING_LIFT := 0.030
const WORK_CYCLE := 8.0

@export var role: Role = Role.LABORATORY

var work_prop: Node3D
var head: Node3D
var work_amount := 0.0
var work_elapsed := 0.0
var work_home: Transform3D
var head_attachment: BoneAttachment3D
var hand_spread_bones: Array[Vector2i] = []
var planted_boots: Array[Transform3D] = []
var right_toe := -1
var right_toe_rotation := Quaternion.IDENTITY
var has_skeletal_body := false


func _ready() -> void:
	var wardrobe := WARDROBES[role].instantiate() as Node3D
	wardrobe.name = "Wardrobe"
	add_child(wardrobe)
	work_prop = wardrobe.get_node(^"WorkProp")
	work_home = work_prop.transform
	head = build_head()
	has_skeletal_body = load_rig(global_rotation.y)
	if not has_skeletal_body:
		build_fallback(wardrobe)
		set_process(false)
		return

	activate(&"idle")
	update_grounding(1.0)
	fit_clothes()
	set_boot_targets()
	for side: String in ["Left", "Right"]:
		hand_spread_bones.append(Vector2i(
			skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(side + "IndexProximal")),
			skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(side + "LittleProximal"))
		))
	attach_to_bone(wardrobe.get_node(^"ChestDetails"), &"UpperChest")
	head_attachment = attach_to_bone(head, &"Head")
	skin_visual.position.y += STANDING_LIFT
	plant_boots()
	work_elapsed = role * 1.8
	pose_work()
	set_process(DisplayServer.get_name() != "headless")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	work_elapsed = fposmod(work_elapsed + delta, WORK_CYCLE)
	# Sample the calm opening of the shared clip to retain a square workstation stance.
	animation.seek(0.04 + 0.025 * sin(work_elapsed * TAU / WORK_CYCLE), true)
	update_grounding(1.0)
	skin_visual.position.y += STANDING_LIFT
	plant_boots()
	pose_work()


func fit_clothes() -> void:
	var paint: Array = PALETTES[role]
	for part: MeshInstance3D in skin_visual.find_children("*", "MeshInstance3D", true, false):
		part.visible = CLOTHING.has(part.name)
		if not part.visible:
			continue
		var material := cloth(paint[CLOTHING[part.name]])
		if part.name in [&"Object_107", &"Object_113"]:
			var source := part.get_active_material(0) as StandardMaterial3D
			if source != null:
				material.normal_enabled = source.normal_enabled
				material.normal_texture = source.normal_texture
				material.normal_scale = 0.40
		part.set_surface_override_material(0, material)


func attach_to_bone(part: Node3D, bone: StringName) -> BoneAttachment3D:
	var bone_name := BONE_MAP.get_skeleton_bone_name(bone)
	var index := skeleton.find_bone(bone_name)
	if index < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = String(bone) + "Clothing"
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachment.transform = skeleton.get_bone_global_pose(index)
	part.reparent(attachment)
	return attachment


func build_head() -> Node3D:
	var viewport_root := get_tree().root
	if not viewport_root.has_meta(HEAD_CACHE):
		var packed := PackedScene.new()
		var model := RuntimeGLB.load_scene(HEAD_PATH)
		if model != null:
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				var material := mesh.get_active_material(0) as StandardMaterial3D
				if material != null:
					RuntimeGLB.add_mipmaps(material)
			for child: Node in model.find_children("*", "", true, false):
				child.owner = model
			packed.pack(model)
			model.free()
		viewport_root.set_meta(HEAD_CACHE, packed)
	var result := Node3D.new()
	result.name = "CivilianHead"
	add_child(result)
	result.position = HEAD_HOME
	var cached := viewport_root.get_meta(HEAD_CACHE) as PackedScene
	if cached.can_instantiate():
		result.add_child(cached.instantiate())
	else:
		var face := SphereMesh.new()
		face.radius = 0.089
		face.height = 0.235
		place_mesh(result, &"FallbackHead", face, Vector3(0, 0.13, 0), Color(0.53, 0.38, 0.29))
	return result


func set_boot_targets() -> void:
	if turning == null:
		return
	for index in range(turning.limbs.size()):
		var foot := global_transform.affine_inverse() * turning.limbs[index].world_end()
		foot.origin.x = -0.115 if index == 0 else 0.115
		foot.origin.z = 0.012 if index == 0 else -0.036
		planted_boots.append(foot)
	flatten_right_boot()


func flatten_right_boot() -> void:
	var boots := skin_visual.find_child("Object_123", true, false) as MeshInstance3D
	if boots == null or boots.skin == null:
		return
	var left_toe := skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(&"LeftToes"))
	var other_toe := skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(&"RightToes"))
	if left_toe < 0 or other_toe < 0:
		return
	var mirror := Basis(Vector3.LEFT, Vector3.UP, Vector3.BACK)
	var left_ankle := planted_boots[0]
	var right_ankle := planted_boots[1]
	var left_bind := boot_bind_basis(boots.skin, turning.limbs[0].end)
	var right_bind := boot_bind_basis(boots.skin, turning.limbs[1].end)
	# The source idle bends the right boot. Mirror the left boot's deformation
	# in bind space to retain the shoe's shape while both soles face the floor.
	right_ankle.basis = mirror * left_ankle.basis * left_bind.inverse() * mirror * right_bind
	right_ankle.origin.y = left_ankle.origin.y
	planted_boots[1] = right_ankle
	var left_pose := (global_basis.inverse() * skeleton.global_basis
		* skeleton.get_bone_global_pose(left_toe).basis)
	var mirrored_toe := mirror * left_pose * boot_bind_basis(boots.skin, left_toe).inverse() * mirror
	right_toe_rotation = (right_ankle.basis.inverse() * mirrored_toe
		* boot_bind_basis(boots.skin, other_toe)).orthonormalized().get_rotation_quaternion()
	right_toe = other_toe


func boot_bind_basis(skin: Skin, bone: int) -> Basis:
	for index in range(skin.get_bind_count()):
		if skin.get_bind_bone(index) == bone or skin.get_bind_name(index) == skeleton.get_bone_name(bone):
			return global_basis.inverse() * skeleton.global_basis * skin.get_bind_pose(index).basis.inverse()
	return Basis.IDENTITY


func plant_boots() -> void:
	for index in range(planted_boots.size()):
		turning.limbs[index].reach(global_transform * planted_boots[index], -global_basis.z)
	if right_toe >= 0:
		skeleton.set_bone_pose_rotation(right_toe, right_toe_rotation)


func pose_work() -> void:
	var stage := minf(work_elapsed, WORK_CYCLE - work_elapsed)
	work_amount = smoothstep(0.7, 2.2, stage)
	var gesture := (1.0 + sin(work_elapsed * TAU * 0.8)) * 0.010 * work_amount
	work_prop.position = work_home.origin + Vector3(0, 0.055, -0.025) * work_amount
	work_prop.basis = work_home.basis.rotated(Vector3.RIGHT, 0.15 * work_amount)
	if head_attachment != null:
		head_attachment.transform = skeleton.get_bone_global_pose(head_attachment.bone_idx)
	head.global_basis = global_basis.orthonormalized() * Basis(Vector3.RIGHT, -lerpf(0.06, 0.42, work_amount))
	if arms.has(null) or grip_bones.has(-1):
		return
	var left := work_prop.get_node(^"SupportPalm") as Marker3D
	var right := work_prop.get_node(^"ActionPalm") as Marker3D
	var resting := to_global(Vector3(0.21, 0.965, -0.065))
	var prop_frame := work_prop.global_basis.orthonormalized()
	var rest_frame := Basis.looking_at(-global_basis.y, global_basis.x)
	fit_palm(0, left.global_position, prop_frame)
	fit_palm(1, resting.lerp(right.global_position + Vector3.UP * gesture, work_amount),
		rest_frame.slerp(prop_frame, work_amount))


func fit_palm(index: int, target: Vector3, hand_frame: Basis) -> void:
	var arm := arms[index]
	var wrist := arm.world_end()
	var knuckle := grip_bones[3 if index == 0 else 1]
	var centre := skeleton.to_global(skeleton.get_bone_global_pose(knuckle).origin)
	var spread := hand_spread_bones[index]
	var elbow := global_basis * Vector3(-1.0 if index == 0 else 1.0, -0.8, 0.25)
	if spread.x < 0 or spread.y < 0:
		reach_palm(index, target, elbow)
		return
	var index_tip := skeleton.to_global(skeleton.get_bone_global_pose(spread.x).origin)
	var little_tip := skeleton.to_global(skeleton.get_bone_global_pose(spread.y).origin)
	var finger := (centre - wrist.origin).normalized()
	var transverse := (little_tip - index_tip).cross(finger).normalized()
	var turn := hand_frame * Basis.looking_at(finger, transverse).inverse()
	var offset := turn * ((centre - wrist.origin) * 0.5)
	arm.reach(Transform3D(turn * wrist.basis, target - offset), elbow)


func build_fallback(wardrobe: Node3D) -> void:
	var shirt := CapsuleMesh.new()
	shirt.radius = 0.205
	shirt.height = 0.62
	place_mesh(self, &"FallbackShirt", shirt, Vector3(0, 1.06, -0.025), PALETTES[role][0])
	var leg := CapsuleMesh.new()
	leg.radius = 0.088
	leg.height = 0.76
	place_mesh(self, &"FallbackLeftLeg", leg, Vector3(-0.10, 0.38, 0.0), PALETTES[role][1])
	place_mesh(self, &"FallbackRightLeg", leg, Vector3(0.10, 0.38, 0.0), PALETTES[role][1])
	var support := work_prop.get_node(^"SupportPalm") as Marker3D
	fallback_sleeve(&"FallbackSupportArm", Vector3(-0.165, 1.24, -0.018), to_local(support.global_position))
	fallback_sleeve(&"FallbackFreeArm", Vector3(0.165, 1.24, -0.018), Vector3(0.188, 0.90, -0.018))
	# The unskinned figure uses the same role colours and work prop on reduced geometry.
	wardrobe.get_node(^"ChestDetails").hide()
	head.position.y -= 0.02


func fallback_sleeve(label: StringName, shoulder: Vector3, hand: Vector3) -> void:
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.048
	sleeve.height = shoulder.distance_to(hand) + sleeve.radius
	place_mesh(self, label, sleeve, shoulder.lerp(hand, 0.5), PALETTES[role][0])
	var part := get_node(NodePath(label)) as Node3D
	part.quaternion = Quaternion(Vector3.UP, shoulder.direction_to(hand))
	var palm := SphereMesh.new()
	palm.radius = 0.034
	palm.height = 0.065
	place_mesh(self, StringName(String(label) + "Palm"), palm, hand, PALETTES[role][2])


func place_mesh(parent: Node3D, label: StringName, shape: Mesh, offset: Vector3, tint: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = shape
	part.material_override = cloth(tint)
	part.position = offset
	parent.add_child(part)


func cloth(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	return material
