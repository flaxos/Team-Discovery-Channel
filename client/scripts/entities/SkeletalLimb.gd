extends RefCounted
## Two-joint visual reach. The animation supplies the limb lengths and twist.

var skeleton: Skeleton3D
var upper: int
var lower: int
var end: int


func _init(rig: Skeleton3D, upper_bone: int, lower_bone: int, end_bone: int) -> void:
	skeleton = rig
	upper = upper_bone
	lower = lower_bone
	end = end_bone


func world_end() -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(end)


func drop_to_reach(goal: Vector3) -> float:
	var start := skeleton.to_global(skeleton.get_bone_global_pose(upper).origin)
	var middle := skeleton.to_global(skeleton.get_bone_global_pose(lower).origin)
	var tip := world_end().origin
	var reach_length := start.distance_to(middle) + middle.distance_to(tip) - 0.002
	var delta := start - goal
	var horizontal := Vector2(delta.x, delta.z).length()
	var vertical := sqrt(maxf(0.0, reach_length * reach_length - horizontal * horizontal))
	return maxf(0.0, delta.y - vertical)


func reach(goal: Transform3D, bend_direction: Vector3) -> void:
	var local_goal := skeleton.global_transform.affine_inverse() * goal
	var shoulder := skeleton.get_bone_global_pose(upper)
	var elbow := skeleton.get_bone_global_pose(lower)
	var wrist := skeleton.get_bone_global_pose(end)
	var upper_length := shoulder.origin.distance_to(elbow.origin)
	var lower_length := elbow.origin.distance_to(wrist.origin)
	var heading := shoulder.origin.direction_to(local_goal.origin)
	if heading.is_zero_approx() or minf(upper_length, lower_length) < 0.001:
		return

	var bend := (skeleton.global_basis.inverse() * bend_direction).slide(heading).normalized()
	if bend.is_zero_approx():
		return
	var reach_distance := clampf(
		shoulder.origin.distance_to(local_goal.origin),
		absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001
	)
	var along := (reach_distance * reach_distance + upper_length * upper_length - lower_length * lower_length) / (2.0 * reach_distance)
	var out := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var next_elbow := shoulder.origin + heading * along + bend * out
	var next_wrist := shoulder.origin + heading * reach_distance
	var upper_basis := swung(shoulder.basis, elbow.origin - shoulder.origin, next_elbow - shoulder.origin)
	var lower_basis := swung(elbow.basis, wrist.origin - elbow.origin, next_wrist - next_elbow)
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(upper))
	set_relative_rotation(upper, parent.basis, upper_basis)
	set_relative_rotation(lower, upper_basis, lower_basis)
	set_relative_rotation(end, lower_basis, local_goal.basis)


func swung(basis: Basis, original: Vector3, target: Vector3) -> Basis:
	return Basis(Quaternion(original.normalized(), target.normalized())) * basis


func set_relative_rotation(bone: int, parent: Basis, desired: Basis) -> void:
	var rotation := (parent.inverse() * desired).orthonormalized().get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, rotation)
