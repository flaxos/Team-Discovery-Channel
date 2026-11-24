extends RefCounted
## World-space boot contacts while the visible Airman catches up to an in-place yaw change.

const TURN_THRESHOLD := deg_to_rad(12.0)
const MAX_STEP_YAW := deg_to_rad(48.0)
const STEP_DURATION := 0.15
const STEP_HEIGHT := 0.11
const Limb := preload("res://scripts/entities/SkeletalLimb.gd")

var limbs: Array[Limb]
var heading: float
var planted: Array[Transform3D] = []
var stance: Array[Transform3D] = []
var foot_headings := Vector2.ZERO
var step_foot := -1
var elapsed := 0.0
var start_heading := 0.0
var landing_heading := 0.0
var landing: Transform3D
var pelvis_drop := 0.0


func _init(legs: Array[Limb], initial_heading: float) -> void:
	limbs = legs
	heading = initial_heading


func update(
	actor_position: Vector3, actor_heading: float, model: Node3D, model_forward: float,
	can_step: bool, delta: float
) -> void:
	pelvis_drop = 0.0
	if not can_step:
		step_foot = -1
		planted.clear()
		heading = actor_heading
		model.rotation.y = model_forward
		return

	if step_foot < 0:
		model.rotation.y = model_forward + angle_difference(actor_heading, heading)
		var remaining := angle_difference(heading, actor_heading)
		if planted.is_empty() or absf(remaining) < TURN_THRESHOLD:
			remember_stance(actor_position)
			return
		begin_step(0 if remaining > 0.0 else 1, actor_position, actor_heading)

	elapsed = minf(elapsed + delta, STEP_DURATION)
	var phase := elapsed / STEP_DURATION
	var eased := smoothstep(0.0, 1.0, phase)
	heading = lerp_angle(start_heading, landing_heading, eased)
	model.rotation.y = model_forward + angle_difference(actor_heading, heading)
	var lifted := planted[step_foot].interpolate_with(landing, eased)
	lifted.origin.y += sin(phase * PI) * STEP_HEIGHT
	var knee_direction := Basis(Vector3.UP, heading) * Vector3.FORWARD
	var support := 1 - step_foot
	pelvis_drop = minf(0.10, limbs[support].drop_to_reach(planted[support].origin))
	model.position.y -= pelvis_drop
	for foot in range(limbs.size()):
		limbs[foot].reach(lifted if foot == step_foot else planted[foot], knee_direction)
	if elapsed < STEP_DURATION:
		return

	planted[step_foot] = landing
	foot_headings[step_foot] = landing_heading
	var other := 1 - step_foot
	var body_turns := absf(angle_difference(heading, actor_heading)) > 0.001
	var foot_turns := absf(angle_difference(foot_headings[other], heading)) > 0.001
	if body_turns or foot_turns:
		begin_step(other, actor_position, actor_heading)
	else:
		step_foot = -1
		planted.clear()


func remember_stance(position: Vector3) -> void:
	var facing := Transform3D(Basis(Vector3.UP, heading), position)
	planted.clear()
	stance.clear()
	for limb: Limb in limbs:
		var contact: Transform3D = limb.world_end()
		planted.append(contact)
		stance.append(facing.affine_inverse() * contact)
	foot_headings = Vector2(heading, heading)


func begin_step(foot: int, position: Vector3, target_heading: float) -> void:
	step_foot = foot
	elapsed = 0.0
	start_heading = heading
	landing_heading = heading + clampf(angle_difference(heading, target_heading), -MAX_STEP_YAW, MAX_STEP_YAW)
	landing = Transform3D(Basis(Vector3.UP, landing_heading), position) * stance[foot]
