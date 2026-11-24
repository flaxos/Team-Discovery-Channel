extends SceneTree
## Benchmarks source clips on a skinned child in the live Airman scene.
## Pass a staged GLB and the exact clip names after --.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		fail("Pass the staged GLB path followed by one or more clip names.")
		return
	var model := RuntimeGLB.load_scene(args[0])
	if model == null:
		fail("Could not load the staged GLB.")
		return
	var rig := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if rig.size() != 1 or players.size() != 1 or meshes.is_empty():
		model.free()
		fail("Expected one skeleton, one animation player and at least one mesh.")
		return
	var skeleton := rig[0] as Skeleton3D
	var animation := players[0] as AnimationPlayer
	var bound_meshes := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			bound_meshes += 1
	if bound_meshes == 0:
		model.free()
		fail("No weighted mesh binds to the source skeleton.")
		return

	var room := preload("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var airman := preload("res://scenes/entities/SGCAirman.tscn").instantiate() as SGCAirmanAI
	room.allies_container.add_child(airman)
	airman.set_physics_process(false)
	airman.position = Vector3(14, 11, 18)
	airman.get_node(^"Visuals").add_child(model)
	var muzzle := airman.get_node(^"MuzzlePoint") as Marker3D
	var body := airman.get_node(^"Visuals/BodyMesh") as MeshInstance3D
	var root_transform := airman.transform
	var muzzle_transform := muzzle.transform
	var body_transform := body.transform
	print("Source rig bone count=%d, bound mesh count=%d, clip count=%d." % [
		skeleton.get_bone_count(), bound_meshes, animation.get_animation_list().size()
	])

	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip: StringName in args.slice(1):
		if not animation.has_animation(clip):
			fail("Missing source clip %s." % clip)
			return
		var animated_bones := sample_clip(animation, skeleton, clip)
		if animated_bones == 0 or airman.transform != root_transform or muzzle.transform != muzzle_transform or body.transform != body_transform:
			fail("Clip %s must move bones within the visual branch." % clip)
			return
		print("%s moved %d bones." % [clip, animated_bones])
	print("PASS source skin and animation under the Airman visual branch")
	await preload("res://tests/support/finish.gd").success(self)


func sample_clip(animation: AnimationPlayer, skeleton: Skeleton3D, clip: StringName) -> int:
	var source := animation.get_animation(clip)
	animation.play(clip)
	animation.advance(0)
	var rotations: Array[Quaternion] = []
	for bone in range(skeleton.get_bone_count()):
		rotations.append(skeleton.get_bone_pose_rotation(bone))
	animation.seek(source.length * 0.37, true)
	var moving := 0
	for bone in range(skeleton.get_bone_count()):
		if not rotations[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)):
			moving += 1
	return moving


func fail(message: String) -> void:
	push_error(message)
	quit(1)
