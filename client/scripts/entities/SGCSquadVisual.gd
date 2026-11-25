extends "res://scripts/entities/SGCHumanRig.gd"
## Presents the replicated operative on the shared SGC rig.

# Palm centres in the existing WeaponModel's local space (right, then left).
const PALM_GRIPS := {
	"m249": [Vector3(0, -0.065, -0.13), Vector3(-0.022, -0.028, -0.34)],
	"mp5": [Vector3(0, -0.068, 0.084), Vector3(-0.028, -0.045, -0.17)],
	"p90": [Vector3(0, -0.055, -0.012), Vector3(-0.026, -0.045, -0.16)],
	"staff_weapon": [Vector3(0, 0, 0.12), Vector3(-0.018, 0, -0.24)],
	"m9": [Vector3(0, -0.052, 0.045), Vector3(-0.033, -0.060, 0.021)],
	"zat": [Vector3(0, -0.060, 0.022), Vector3(-0.032, -0.049, -0.021)],
}
const RECON_RADIO := preload("res://scenes/entities/SGCReconRadio.tscn")
const TECH_SCANNER := preload("res://scenes/entities/SGCTechScanner.tscn")
const RECON := SGCNetworkManager.CLASS_ONEILL_RECON
const TECH := SGCNetworkManager.CLASS_CARTER_TECH
const ROLE_PALETTES := {
	RECON: {
		"Mil_Suit_R5": Color(0.83, 0.88, 1.28),
		"Mil_Suit_R5__Plate": Color(1.16, 0.99, 0.80),
		"Mil_Suit_R5_Puches": Color(1.16, 0.99, 0.80),
		"GreenCap": Color(0.74, 0.81, 1.13),
	},
	TECH: {
		"Mil_Suit_R5": Color(1.30, 1.06, 0.76),
		"Mil_Suit_R5__Plate": Color(0.73, 1.12, 1.28),
		"Mil_Suit_R5_Puches": Color(0.81, 1.03, 1.13),
		"GreenCap": Color(0.69, 0.81, 0.85),
	},
}
const ROLE_GRIPS := {
	RECON: {
		"p90": [Vector3(0.025, -0.060, -0.014), Vector3(-0.032, -0.048, -0.149)],
		"m9": [Vector3(0.014, -0.055, 0.033), Vector3(-0.022, -0.055, 0.028)],
	},
	TECH: {
		"mp5": [Vector3(0.014, -0.065, 0.084), Vector3(-0.019, -0.027, -0.158)],
		"zat": [Vector3(0.012, -0.059, 0.027), Vector3(-0.023, -0.045, -0.029)],
	},
}

var player: PlayerController3D
var skin_meshes: Array[Node] = []
var was_downed := false
var shot_pending := false
var recoil := 0.0
var recon_mount: BoneAttachment3D
var tech_mount: BoneAttachment3D
var chest_fit_transform: Transform3D
var visual_role := ""
var iris_servo: IrisServoHousing
var reload_blend := 0.0
var previous_weapon: WeaponBase
var original_materials: Dictionary[MeshInstance3D, Material] = {}
var role_materials: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	set_process(false)
	player = get_parent().get_parent() as PlayerController3D
	if player == null or not load_rig(global_rotation.y):
		return
	activate(&"ready_idle")
	update_grounding(1.0)
	skin_meshes = skin_visual.find_children("*", "MeshInstance3D", true, false)
	var chest := skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(&"UpperChest"))
	if chest >= 0:
		var chest_pose := skeleton.global_transform * skeleton.get_bone_global_pose(chest)
		chest_fit_transform = chest_pose.affine_inverse() * global_transform
	var world := MissionWorld.of(player)
	if world != null:
		iris_servo = world.get_node_or_null(^"IrisServoHousing") as IrisServoHousing
	player.class_configured.connect(apply_class_appearance)
	apply_class_appearance(player.class_id)
	for path: NodePath in [^"BodyMesh", ^"VisorMesh", ^"ClassGear"]:
		(get_parent().get_node(path) as Node3D).hide()
	set_process(true)


func apply_class_appearance(role: String) -> void:
	if visual_role == role:
		return
	visual_role = role
	reload_blend = 0.0
	var palette: Dictionary = ROLE_PALETTES.get(role, {})
	var variants: Dictionary = role_materials.get_or_add(role, {})
	for part: MeshInstance3D in skin_meshes:
		if part.skin == null:
			continue
		if original_materials.has(part):
			part.set_surface_override_material(0, original_materials[part])
		var source := part.get_active_material(0) as StandardMaterial3D
		if source == null or not palette.has(source.resource_name):
			continue
		if not variants.has(source):
			var variant := source.duplicate() as StandardMaterial3D
			variant.albedo_color *= palette[source.resource_name]
			variants[source] = variant
		original_materials[part] = part.get_surface_override_material(0)
		part.set_surface_override_material(0, variants[source])
	if role == RECON and recon_mount == null:
		recon_mount = attach_chest_kit(RECON_RADIO, &"ReconKit")
	if role == TECH and tech_mount == null:
		tech_mount = attach_chest_kit(TECH_SCANNER, &"TechKit")
	if recon_mount != null:
		recon_mount.visible = role == RECON
	if tech_mount != null:
		tech_mount.visible = role == TECH


func attach_chest_kit(scene: PackedScene, label: StringName) -> BoneAttachment3D:
	var chest_bone := BONE_MAP.get_skeleton_bone_name(&"UpperChest")
	if skeleton.find_bone(chest_bone) < 0:
		return null
	var mount := BoneAttachment3D.new()
	mount.name = label
	mount.bone_name = chest_bone
	skeleton.add_child(mount)
	var gear := scene.instantiate() as Node3D
	gear.transform = chest_fit_transform
	mount.add_child(gear)
	for mesh: MeshInstance3D in gear.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = (skin_meshes[0] as MeshInstance3D).transparency
		skin_meshes.append(mesh)
	return mount


func _process(delta: float) -> void:
	var health := player.health_component
	if health == null or health.is_vaporized:
		return
	var shifting_vertically := sample_motion(delta, player.base_speed * player.sprint_multiplier)
	var moving := ground_speed > 0.22
	var turret := player.mounted_turret
	var mounted := is_instance_valid(turret)
	var fitted_grips := has_fitted_grips(turret)
	var next_pose := select_pose(moving, mounted, fitted_grips)
	was_downed = health.is_downed
	update_pose(next_pose, next_pose == &"shoot" and shot_pending, delta)
	shot_pending = false
	if turning != null:
		var can_step := not moving and not shifting_vertically and not mounted and pose in [
			&"ready_idle", &"aim_idle", &"aim_crouch_idle"
		]
		turning.update(global_position, global_rotation.y, skin_visual, SOURCE_FORWARD_TO_GAME, can_step, delta)
	if fitted_grips and not health.is_dead and not health.is_downed:
		pose_mounted_hands(turret)
	if not mounted:
		update_held_weapon(delta)
	else:
		reload_blend = 0.0
	recoil = move_toward(recoil, 0.0, delta * 0.24)


func select_pose(moving: bool, mounted: bool, fitted_grips: bool) -> StringName:
	var health := player.health_component
	if health.is_dead:
		return &"death"
	if health.is_downed:
		return &"prone_crawl" if moving else &"downed"
	if mounted:
		return &"aim_crouch_idle" if fitted_grips else &"aim_idle"
	if health.is_stunned:
		return &"downed"
	if was_downed or (pose == &"revived" and animation.is_playing()):
		return &"revived"
	if is_instance_valid(player.active_revive_target) and not moving:
		return &"revive_kneel"
	if not player.is_crouching and (shot_pending or (pose == &"shoot" and animation.is_playing())):
		return &"shoot"
	if player.is_crouching:
		return &"aim_crouch_walk" if moving else &"aim_crouch_idle"
	if player.is_aiming_down_sights or player.is_firing:
		return &"aim_walk" if moving else &"aim_idle"
	if moving:
		return &"ready_run" if player.is_sprinting else &"ready_walk"
	return &"ready_idle"


func palm_grips(weapon_id: String) -> Array:
	var grips: Dictionary = ROLE_GRIPS.get(visual_role, {})
	return grips.get(weapon_id, PALM_GRIPS[weapon_id])


func update_held_weapon(delta: float) -> void:
	var weapon := player.current_weapon
	if weapon == null or grip_bones.has(-1):
		return
	var model := weapon.get_node_or_null(^"WeaponModel") as Node3D
	if model == null:
		return
	model.visible = pose not in [&"death", &"revived", &"revive_kneel"] and not player.health_component.is_stunned
	if not model.visible:
		return
	if visual_role == TECH and pose_iris_repair():
		model.hide()
		return
	if previous_weapon != weapon:
		reload_blend = 0.0
		previous_weapon = weapon
	var grips := palm_grips(weapon.weapon_id)
	var primary := to_global(hand_center(grip_bones[0], grip_bones[1]))
	var orientation := weapon.global_basis.orthonormalized()
	var brace := pose not in [&"downed", &"prone_crawl"]
	if visual_role == RECON:
		var reload_target := 1.0 if weapon.is_reloading and brace else 0.0
		reload_blend = move_toward(reload_blend, reload_target, delta * 5.0) if brace else 0.0
		orientation = orientation.rotated(orientation.x, -deg_to_rad(22.0) * reload_blend)
	model.global_transform = Transform3D(orientation, primary - orientation * grips[0] + orientation.z * recoil)
	if not arms.has(null) and brace:
		reach_palm(0, model.to_global(grips[1]), orientation * Vector3(-1.0, -0.8, 0.26))
		if visual_role == RECON and recoil > 0.0:
			reach_palm(1, model.to_global(grips[0]), orientation * Vector3(1.0, -0.8, 0.26))


func pose_iris_repair() -> bool:
	if not is_instance_valid(iris_servo) or not iris_servo.is_repairing or iris_servo.repairer_player != player:
		return false
	if pose not in [&"ready_idle", &"aim_crouch_idle"] or arms.has(null):
		return false
	if player.is_aiming_down_sights or player.is_firing or recoil > 0.0:
		return false
	var lever := iris_servo.get_node_or_null(^"LeverMesh/RepairLeverPalm") as Marker3D
	var brace := iris_servo.get_node_or_null(^"RepairBracePalm") as Marker3D
	if lever == null or brace == null:
		return false
	var heading := (lever.global_position - global_position).slide(Vector3.UP).normalized()
	if -global_basis.z.dot(heading) < 0.65 or not palm_can_reach(1, lever) or not palm_can_reach(0, brace):
		return false
	reach_palm(1, lever.global_position, global_basis * Vector3(1, -0.8, 0.2))
	reach_palm(0, brace.global_position, global_basis * Vector3(-1, -0.8, 0.2))
	return true


func palm_can_reach(index: int, target: Marker3D) -> bool:
	var arm := arms[index]
	var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(arm.upper).origin)
	var elbow := skeleton.to_global(skeleton.get_bone_global_pose(arm.lower).origin)
	var reach := shoulder.distance_to(elbow) + elbow.distance_to(arm.world_end().origin)
	# The hand solver aims the wrist just behind the palm contact.
	return shoulder.distance_to(target.global_position) <= reach + 0.025


func show_shot(origin: Vector3, plasma: bool, zat: bool) -> Vector3:
	shot_pending = true
	recoil = 0.021
	var weapon := player.current_weapon
	if weapon != null and weapon.is_plasma == plasma and weapon.is_zat == zat and weapon.muzzle_point != null:
		var model := weapon.get_node_or_null(^"WeaponModel") as Node3D
		if model != null and model.is_visible_in_tree():
			return model.to_global(weapon.muzzle_point.position)
	return origin


func set_camera_alpha(alpha: float) -> void:
	for mesh: MeshInstance3D in skin_meshes:
		mesh.transparency = 1.0 - alpha


func vaporize(tween: Tween) -> void:
	var weapon := player.current_weapon
	if weapon != null:
		weapon.hide()
	tween.tween_property(skin_visual, "scale", Vector3.ONE * 0.01, 0.25)
