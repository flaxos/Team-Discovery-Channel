extends "res://scripts/entities/SGCHumanRig.gd"
## Cosmetic state playback on the same Airman scene on the server and every peer.

const MP5_PRIMARY_GRIP := Vector3(-12.0, -12.5, 0.0)

var airman: SGCAirmanAI
var weapon_model: Node3D
var previous_state: int
var shot_pending := false
var crouch_recoil := 0.0


func _ready() -> void:
	set_process(false)
	airman = get_parent().get_parent() as SGCAirmanAI
	if airman == null or not load_rig(airman.global_rotation.y):
		return
	if not grip_bones.has(-1):
		weapon_model = WeaponBase.load_glb_model(WeaponBase.GLB_MODELS["mp5"])
		if weapon_model != null:
			weapon_model.name = "AirmanMP5"
			add_child(weapon_model)
	previous_state = airman.current_state
	if airman.current_state == SGCAirmanAI.State.DEAD or (airman.health_component != null and airman.health_component.is_dead):
		snap_to_end(&"death")
	else:
		activate(select_pose(false, false, false))
		update_grounding(1.0)
	get_parent().get_node(^"BodyMesh").hide()
	get_parent().get_node(^"HelmetMesh").hide()
	airman.mp5_visual_fired.connect(queue_shot)
	set_process(true)


func _process(delta: float) -> void:
	var shifting_vertically := sample_motion(delta, airman.move_speed)
	var state := airman.current_state
	var turret := airman.mounted_turret
	var mounted := is_instance_valid(turret)
	var fitted_grips := has_fitted_grips(turret)
	var recovering := previous_state == SGCAirmanAI.State.DOWNED and state != previous_state
	previous_state = state
	var next_pose := select_pose(ground_speed > 0.22, recovering, fitted_grips)
	if next_pose == &"death" and pose != &"death" and airman.health_component != null and airman.health_component.snapped_from_snapshot:
		snap_to_end(&"death")
	else:
		update_pose(next_pose, next_pose == &"shoot" and shot_pending, delta)
	shot_pending = false
	if turning != null:
		var can_step := (
			ground_speed < 0.22 and not shifting_vertically
			and not mounted
			and pose in [&"ready_idle", &"aim_idle", &"aim_crouch_idle"]
		)
		turning.update(airman.global_position, airman.global_rotation.y, skin_visual, SOURCE_FORWARD_TO_GAME, can_step, delta)
	if fitted_grips and not pose in [&"downed", &"death", &"prone_crawl"]:
		pose_mounted_hands(turret)
	if weapon_model != null:
		update_weapon()
	crouch_recoil = move_toward(crouch_recoil, 0.0, delta * 0.24)


func select_pose(moving: bool, recovering: bool, fitted_grips: bool) -> StringName:
	match airman.current_state:
		SGCAirmanAI.State.DEAD:
			return &"death"
		SGCAirmanAI.State.DOWNED:
			return &"prone_crawl" if moving else &"downed"
	if fitted_grips:
		return &"aim_crouch_idle"
	if airman.current_state == SGCAirmanAI.State.MAN_TURRET:
		return &"aim_idle"
	if recovering or (pose == &"revived" and animation.is_playing()):
		return &"revived"
	if not airman.is_crouching and (shot_pending or (pose == &"shoot" and animation.is_playing())):
		return &"shoot"
	match airman.current_state:
		SGCAirmanAI.State.REVIVE_PLAYER:
			return &"walk" if moving else &"revive_kneel"
		SGCAirmanAI.State.COMBAT, SGCAirmanAI.State.COVER_FIRE, SGCAirmanAI.State.HOLD_CORNER:
			if airman.is_crouching:
				return &"aim_crouch_walk" if moving else &"aim_crouch_idle"
			return &"aim_walk" if moving else &"aim_idle"
	if airman.is_crouching:
		return &"aim_crouch_walk" if moving else &"aim_crouch_idle"
	if moving:
		return &"ready_run" if ground_speed >= 3.5 else &"ready_walk"
	return &"ready_idle"


func update_weapon() -> void:
	weapon_model.visible = (
		pose not in [&"downed", &"death", &"revived", &"prone_crawl", &"revive_kneel", &"walk"]
		and airman.current_state != SGCAirmanAI.State.MAN_TURRET
		and not is_instance_valid(airman.mounted_turret)
	)
	if not weapon_model.visible:
		return
	var primary := hand_center(grip_bones[0], grip_bones[1])
	var support := hand_center(grip_bones[2], grip_bones[3])
	var direction := (support - primary).normalized()
	var forward := Basis(Vector3.UP, skin_visual.rotation.y - SOURCE_FORWARD_TO_GAME) * Vector3.FORWARD
	if direction.dot(forward) < 0.45:
		direction = forward
	var basis := Basis.looking_at(direction) * WeaponBase.MP5_MODEL_BASIS
	weapon_model.transform = Transform3D(basis, primary - basis * MP5_PRIMARY_GRIP - direction * crouch_recoil)


func queue_shot() -> void:
	shot_pending = true
	if airman.is_crouching:
		crouch_recoil = 0.021
