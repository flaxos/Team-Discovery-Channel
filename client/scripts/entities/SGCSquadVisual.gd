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
const RECON_PALETTE := {
	"Mil_Suit_R5": Color(0.83, 0.88, 1.28),
	"Mil_Suit_R5__Plate": Color(1.16, 0.99, 0.80),
	"Mil_Suit_R5_Puches": Color(1.16, 0.99, 0.80),
	"GreenCap": Color(0.74, 0.81, 1.13),
}
const RECON_GRIPS := {
	"p90": [Vector3(0.025, -0.060, -0.014), Vector3(-0.032, -0.048, -0.149)],
	"m9": [Vector3(0.014, -0.055, 0.033), Vector3(-0.022, -0.055, 0.028)],
}

var player: PlayerController3D
var skin_meshes: Array[Node] = []
var was_downed := false
var shot_pending := false
var recoil := 0.0
var recon_mount: BoneAttachment3D
var recon_radio_transform: Transform3D
var is_recon := false
var reload_blend := 0.0
var previous_weapon: WeaponBase
var original_materials: Dictionary[MeshInstance3D, Material] = {}
var recon_materials: Dictionary[StandardMaterial3D, StandardMaterial3D] = {}


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
		recon_radio_transform = chest_pose.affine_inverse() * global_transform
	player.class_configured.connect(apply_class_appearance)
	apply_class_appearance(player.class_id)
	for path: NodePath in [^"BodyMesh", ^"VisorMesh", ^"ClassGear"]:
		(get_parent().get_node(path) as Node3D).hide()
	set_process(true)


func apply_class_appearance(role: String) -> void:
	var recon := role == SGCNetworkManager.CLASS_ONEILL_RECON
	if is_recon == recon:
		return
	is_recon = recon
	reload_blend = 0.0
	for part: MeshInstance3D in skin_meshes:
		if part.skin == null:
			continue
		if not is_recon:
			if original_materials.has(part):
				part.set_surface_override_material(0, original_materials[part])
			continue
		var source := part.get_active_material(0) as StandardMaterial3D
		if source == null or not RECON_PALETTE.has(source.resource_name):
			continue
		if not recon_materials.has(source):
			var variant := source.duplicate() as StandardMaterial3D
			variant.albedo_color *= RECON_PALETTE[source.resource_name]
			recon_materials[source] = variant
		original_materials[part] = part.get_surface_override_material(0)
		part.set_surface_override_material(0, recon_materials[source])
	if is_recon and recon_mount == null:
		var chest_bone := BONE_MAP.get_skeleton_bone_name(&"UpperChest")
		if skeleton.find_bone(chest_bone) >= 0:
			recon_mount = BoneAttachment3D.new()
			recon_mount.name = "ReconKit"
			recon_mount.bone_name = chest_bone
			skeleton.add_child(recon_mount)
			var radio := RECON_RADIO.instantiate() as Node3D
			radio.transform = recon_radio_transform
			recon_mount.add_child(radio)
			for mesh: MeshInstance3D in radio.find_children("*", "MeshInstance3D", true, false):
				mesh.transparency = (skin_meshes[0] as MeshInstance3D).transparency
				skin_meshes.append(mesh)
	if recon_mount != null:
		recon_mount.visible = is_recon


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
	if is_recon and RECON_GRIPS.has(weapon_id):
		return RECON_GRIPS[weapon_id]
	return PALM_GRIPS[weapon_id]


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
	if previous_weapon != weapon:
		reload_blend = 0.0
		previous_weapon = weapon
	var grips := palm_grips(weapon.weapon_id)
	var primary := to_global(hand_center(grip_bones[0], grip_bones[1]))
	var orientation := weapon.global_basis.orthonormalized()
	var brace := pose not in [&"downed", &"prone_crawl"]
	if is_recon:
		var reload_target := 1.0 if weapon.is_reloading and brace else 0.0
		reload_blend = move_toward(reload_blend, reload_target, delta * 5.0) if brace else 0.0
		orientation = orientation.rotated(orientation.x, -deg_to_rad(22.0) * reload_blend)
	model.global_transform = Transform3D(orientation, primary - orientation * grips[0] + orientation.z * recoil)
	if not arms.has(null) and brace:
		reach_palm(0, model.to_global(grips[1]), orientation * Vector3(-1.0, -0.8, 0.26))
		if is_recon and recoil > 0.0:
			reach_palm(1, model.to_global(grips[0]), orientation * Vector3(1.0, -0.8, 0.26))


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
