extends "res://scripts/entities/SGCHumanRig.gd"
## Presents the replicated operative with the shared temporary SGC uniform.

# Palm centres in the existing WeaponModel's local space (right, then left).
const PALM_GRIPS := {
	"m249": [Vector3(0, -0.065, -0.13), Vector3(-0.022, -0.028, -0.34)],
	"mp5": [Vector3(0, -0.068, 0.084), Vector3(-0.028, -0.045, -0.17)],
	"p90": [Vector3(0, -0.055, -0.012), Vector3(-0.026, -0.045, -0.16)],
	"staff_weapon": [Vector3(0, 0, 0.12), Vector3(-0.018, 0, -0.24)],
	"m9": [Vector3(0, -0.052, 0.045), Vector3(-0.033, -0.060, 0.021)],
	"zat": [Vector3(0, -0.060, 0.022), Vector3(-0.032, -0.049, -0.021)],
}

var player: PlayerController3D
var skin_meshes: Array[Node] = []
var was_downed := false
var shot_pending := false
var recoil := 0.0


func _ready() -> void:
	set_process(false)
	player = get_parent().get_parent() as PlayerController3D
	if player == null or not load_rig(global_rotation.y):
		return
	activate(&"ready_idle")
	update_grounding(1.0)
	skin_meshes = skin_visual.find_children("*", "MeshInstance3D", true, false)
	for path: NodePath in [^"BodyMesh", ^"VisorMesh", ^"ClassGear"]:
		(get_parent().get_node(path) as Node3D).hide()
	set_process(true)


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
		update_held_weapon()
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


func update_held_weapon() -> void:
	var weapon := player.current_weapon
	if weapon == null or grip_bones.has(-1):
		return
	var model := weapon.get_node_or_null(^"WeaponModel") as Node3D
	if model == null:
		return
	model.visible = pose not in [&"death", &"revived", &"revive_kneel"] and not player.health_component.is_stunned
	if not model.visible:
		return
	var grips: Array = PALM_GRIPS[weapon.weapon_id]
	var primary := to_global(hand_center(grip_bones[0], grip_bones[1]))
	var orientation := weapon.global_basis.orthonormalized()
	model.global_transform = Transform3D(orientation, primary - orientation * grips[0] + orientation.z * recoil)
	if not arms.has(null) and pose not in [&"downed", &"prone_crawl"]:
		reach_palm(0, model.to_global(grips[1]), orientation * Vector3(-1.0, -0.8, 0.26))


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
