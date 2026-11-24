extends Node3D
## The shared Airman skin and animation instances for SGC personnel and operatives.

const MODEL_PATH := "res://assets/characters/sgc_airman.glb"
const MODEL_CACHE := &"sgc_human_rig_cache"
const SOURCE_FORWARD_TO_GAME := PI
const MODEL_SCALE := 0.96
const BONE_MAP := preload("res://resources/characters/sgc_airman_bone_map.tres")
const GROUNDING := preload("res://resources/characters/sgc_airman_grounding.tres")
const Limb := preload("res://scripts/entities/SkeletalLimb.gd")
const Turning := preload("res://scripts/entities/AirmanTurnPose.gd")
const MOTION_CLIPS: Array[StringName] = [
	&"idle", &"walk", &"run", &"crouch_idle", &"crouch_walk", &"aim_idle", &"aim_walk",
	&"aim_crouch_idle", &"aim_crouch_walk", &"ready_idle", &"ready_walk", &"ready_run", &"shoot", &"downed",
	&"prone_crawl", &"death", &"revive_kneel", &"revived",
]
const ONE_SHOTS: Array[StringName] = [&"shoot", &"death", &"revived"]

var animation: AnimationPlayer
var skeleton: Skeleton3D
var skin_visual: Node3D
var grip_bones: Array[int] = []
var arms: Array[Limb] = []
var turning: Turning
var previous_position: Vector3
var ground_speed := 0.0
var pose: StringName


func load_rig(heading: float) -> bool:
	var root := get_tree().root
	if not root.has_meta(MODEL_CACHE):
		root.set_meta(MODEL_CACHE, {"model": prepare_model()})
	var cached_model := root.get_meta(MODEL_CACHE).model as PackedScene
	if cached_model == null:
		return false
	var model := cached_model.instantiate() as Node3D
	if model == null:
		return false
	add_child(model)
	model.rotation.y = SOURCE_FORWARD_TO_GAME
	model.scale = Vector3.ONE * MODEL_SCALE
	skin_visual = model
	animation = find_animation_player(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if animation == null or skeletons.size() != 1:
		model.queue_free()
		return false
	skeleton = skeletons[0] as Skeleton3D
	for semantic: StringName in [&"RightHand", &"RightMiddleProximal", &"LeftHand", &"LeftMiddleProximal"]:
		grip_bones.append(skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(semantic)))
	var legs: Array[Limb] = []
	for side: String in ["Left", "Right"]:
		arms.append(mapped_limb(side, "UpperArm", "LowerArm", "Hand"))
		legs.append(mapped_limb(side, "UpperLeg", "LowerLeg", "Foot"))
	if not legs.has(null):
		turning = Turning.new(legs, heading)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	previous_position = global_position
	return true


func sample_motion(delta: float, speed_limit: float) -> bool:
	var advance := global_position - previous_position
	previous_position = global_position
	var shifting_vertically := absf(advance.y) > 0.025
	advance.y = 0.0
	if delta > 0.0:
		var speed := minf(advance.length() / delta, speed_limit) if advance.length() < 1.5 else 0.0
		ground_speed = lerpf(ground_speed, speed, minf(delta * 12.0, 1.0))
	return shifting_vertically


func update_pose(next_pose: StringName, restart: bool, delta: float) -> void:
	if pose != next_pose or restart:
		activate(next_pose)
	animation.advance(delta)
	if turning != null:
		skin_visual.position.y += turning.pelvis_drop
	update_grounding(minf(delta * 20.0, 1.0))


func has_fitted_grips(turret: DeployableTurret) -> bool:
	return (
		is_instance_valid(turret) and turret.left_grip != null and turret.right_grip != null
		and turret.turret_head.has_node(^"M2Gun")
	)


func update_grounding(blend: float) -> void:
	if not animation.is_playing():
		return
	var offsets: Dictionary = GROUNDING.get_meta("clip_floor_lifts")
	var samples: PackedFloat32Array = offsets[pose]
	var phase := animation.current_animation_position / animation.current_animation_length
	var index := clampf(phase, 0.0, 1.0) * (samples.size() - 1)
	var lower := floori(index)
	var upper := mini(lower + 1, samples.size() - 1)
	var lift := lerpf(samples[lower], samples[upper], index - lower)
	skin_visual.position.y = lerpf(skin_visual.position.y, lift, blend)


func hand_center(wrist: int, knuckle: int) -> Vector3:
	var center := skeleton.get_bone_global_pose(wrist).origin.lerp(skeleton.get_bone_global_pose(knuckle).origin, 0.50)
	return to_local(skeleton.to_global(center))


func mapped_limb(side: String, start: String, middle: String, tip: String) -> Limb:
	var indices: Array[int] = []
	for joint: String in [start, middle, tip]:
		indices.append(skeleton.find_bone(BONE_MAP.get_skeleton_bone_name(side + joint)))
	return Limb.new(skeleton, indices[0], indices[1], indices[2]) if not indices.has(-1) else null


func pose_mounted_hands(turret: DeployableTurret) -> void:
	if arms.has(null) or grip_bones.has(-1):
		return
	var grips: Array[Marker3D] = [turret.left_grip, turret.right_grip]
	for index in range(arms.size()):
		var arm := arms[index]
		var grip := grips[index]
		var side := float(index * 2 - 1)
		var head_basis := grip.global_basis.orthonormalized()
		var palm := grip.to_global(Vector3(side * 0.024, 0.0, 0.015))
		var elbow_direction := head_basis * Vector3(side, -0.8, 0.26)
		reach_palm(index, palm, elbow_direction)


func reach_palm(index: int, palm: Vector3, elbow_direction: Vector3) -> void:
	var arm := arms[index]
	var hand := arm.world_end()
	var knuckle := 3 if index == 0 else 1
	var palm_offset := skeleton.to_global(skeleton.get_bone_global_pose(grip_bones[knuckle]).origin) - hand.origin
	arm.reach(Transform3D(hand.basis, palm - palm_offset * 0.5), elbow_direction)


func activate(clip: StringName) -> void:
	var blend := 0.12 if pose != &"" and clip != &"shoot" else 0.0
	if pose == clip:
		animation.stop(true)
	var playback := 2.4 if clip == &"shoot" else 1.0
	animation.play(clip, blend, playback)
	animation.advance(0.0)
	pose = clip


func prepare_model() -> PackedScene:
	var started := Time.get_ticks_usec()
	var model := RuntimeGLB.load_scene(MODEL_PATH)
	if model == null:
		return null
	var player := find_animation_player(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if player == null or skeletons.size() != 1:
		model.free()
		return null
	for clip in MOTION_CLIPS:
		if not player.has_animation(clip):
			model.free()
			return null
		player.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip in ONE_SHOTS else Animation.LOOP_LINEAR
	var updated: Dictionary[StandardMaterial3D, bool] = {}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as StandardMaterial3D
			if material != null and not updated.has(material):
				material.metallic = minf(material.metallic, 0.22)
				RuntimeGLB.add_mipmaps(material)
				updated[material] = true
	for node: Node in model.find_children("*", "", true, false):
		node.owner = model
	var result := PackedScene.new()
	var status := result.pack(model)
	model.free()
	if status != OK:
		return null
	print("SGC Airman visual prepared in %.1f ms" % (float(Time.get_ticks_usec() - started) / 1000.0))
	return result


func find_animation_player(model: Node3D) -> AnimationPlayer:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if players.size() == 1 else null
