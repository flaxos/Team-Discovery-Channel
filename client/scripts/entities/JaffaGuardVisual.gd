extends "res://scripts/entities/SGCHumanRig.gd"
## Native Serpent and Horus Jaffa guard rig visuals on the shared humanoid rig.

const Armour := preload("res://scripts/entities/JaffaGuardArmour.gd")
const UNDERLAY: Array[StringName] = [&"Object_107", &"Object_113", &"Object_115", &"Object_123"]
const CLOTH_CACHE := &"serpent_cloth_finish"
const HORUS_CLOTH_CACHE := &"horus_cloth_finish"
const REAR_PALM := Vector3(0.0, -0.023, 0.25)
const FRONT_PALM := Vector3(-0.018, -0.021, 0.07)

@export var horus := false

var guard: JaffaAI
var health: HealthComponent
var shot_pending := false


func _ready() -> void:
	set_process(false)
	var arguments := OS.get_cmdline_user_args()
	if "--expect-jaffa-fallback" in arguments:
		return
	guard = get_parent() as JaffaAI
	if guard == null:
		return
	health = guard.get_node(^"HealthComponent") as HealthComponent
	if not load_rig(global_rotation.y):
		return
	activate(&"ready_idle")
	update_grounding(1.0)
	var helmet_path := ""
	if not horus:
		for argument in arguments:
			if argument.begins_with("--serpent-helmet="):
				helmet_path = argument.trim_prefix("--serpent-helmet=")
	if not fit_underlayer() or not Armour.new().fit(skeleton, BONE_MAP, skin_visual.global_basis, helmet_path, horus):
		skin_visual.queue_free()
		return
	var visuals := guard.get_node(^"Visuals")
	for path: NodePath in [^"ArmorMesh", ^"SerpentHelm", ^"EyeSlits"]:
		(visuals.get_node(path) as Node3D).hide()
	if health.is_dead or guard.current_state == JaffaAI.State.DEAD:
		snap_to_end(&"death")
	guard.staff_visual_fired.connect(queue_shot)
	health.vaporized.connect(vaporize)
	set_process(true)


func fit_underlayer() -> bool:
	var root := get_tree().root
	var cache := HORUS_CLOTH_CACHE if horus else CLOTH_CACHE
	var cloth := root.get_meta(cache) as StandardMaterial3D if root.has_meta(cache) else null
	var pieces := 0
	for mesh: MeshInstance3D in skin_visual.find_children("*", "MeshInstance3D", true, false):
		if not mesh.name in UNDERLAY:
			mesh.hide()
			continue
		if cloth == null:
			var source := mesh.get_active_material(0) as StandardMaterial3D
			if source == null:
				return false
			cloth = source.duplicate() as StandardMaterial3D
			cloth.albedo_color = Color(0.48, 0.59, 0.67) if horus else Color(0.47, 0.49, 0.55)
			cloth.metallic = 0.0
			root.set_meta(cache, cloth)
		mesh.material_override = cloth
		pieces += 1
	return pieces == UNDERLAY.size()


func _process(delta: float) -> void:
	if health.is_vaporized:
		return
	var shifting_vertically := sample_motion(delta, guard.combat_run_speed)
	var moving := ground_speed > 0.22
	var next_pose := select_pose(moving)
	if next_pose == &"death" and pose != &"death" and health.snapped_from_snapshot:
		snap_to_end(&"death")
	else:
		update_pose(next_pose, next_pose == &"shoot" and shot_pending, delta)
	shot_pending = false
	if turning != null:
		var can_step := not moving and not shifting_vertically and pose in [
			&"ready_idle", &"aim_idle", &"aim_crouch_idle"
		]
		turning.update(global_position, global_rotation.y, skin_visual, SOURCE_FORWARD_TO_GAME, can_step, delta)
	update_staff()


func select_pose(moving: bool) -> StringName:
	if health.is_dead or guard.current_state == JaffaAI.State.DEAD:
		return &"death"
	if health.is_downed or health.is_stunned or guard.current_state in [JaffaAI.State.DOWNED, JaffaAI.State.STUNNED]:
		return &"downed"
	if guard.is_crouching:
		return &"aim_crouch_walk" if moving else &"aim_crouch_idle"
	if shot_pending or (pose == &"shoot" and animation.is_playing()):
		return &"shoot"
	if guard.current_state in [JaffaAI.State.ATTACK, JaffaAI.State.COMBAT, JaffaAI.State.COVER, JaffaAI.State.MELEE]:
		return &"aim_walk" if moving else &"aim_idle"
	if moving:
		return &"ready_run" if ground_speed > 3.5 else &"ready_walk"
	return &"ready_idle"


func update_staff() -> void:
	var shaft := guard.staff_mount.get_node_or_null(^"StaffVisual") as Node3D
	if shaft == null:
		return
	shaft.visible = pose not in [&"downed", &"death"]
	if not shaft.visible or arms.has(null) or grip_bones.has(-1):
		return
	var aim := guard.staff_mount.global_basis.orthonormalized()
	reach_palm(1, shaft.to_global(REAR_PALM), aim * Vector3(1.0, -0.8, 0.26))
	# Centre ready supports two hands. The side carry uses the right palm.
	if guard.staff_mount.position.x < 0.20:
		reach_palm(0, shaft.to_global(FRONT_PALM), aim * Vector3(-1.0, -0.8, 0.26))


func queue_shot() -> void:
	shot_pending = true


func vaporize() -> void:
	var staff := guard.staff_mount.get_node_or_null(^"StaffVisual") as Node3D
	if staff != null:
		staff.hide()
	create_tween().tween_property(skin_visual, "scale", Vector3.ONE * 0.01, 0.25)
