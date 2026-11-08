class_name SmokeGrenade
extends RigidBody3D
## M18 Tactical Smoke Grenade.
## Bounces on the floor and detonates after 1.0s, generating a 4.5m radius smoke cloud
## that persists for 12.0s, breaking Jaffa line-of-sight and staff weapon targeting.

signal detonated(cloud_position: Vector3)
signal dissipated()

@export var fuse_time_s: float = 1.0
@export var cloud_duration_s: float = 12.0
@export var cloud_radius: float = 4.5

var is_detonated: bool = false
var cloud_area: Area3D = null


func _ready() -> void:
	add_to_group("smoke_grenade")
	# Arm fuse timer
	var timer := get_tree().create_timer(fuse_time_s)
	timer.timeout.connect(_detonate)


func _detonate() -> void:
	if is_detonated:
		return
	is_detonated = true
	freeze = true
	gravity_scale = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Hide grenade canister body
	var canister := get_node_or_null("CanisterMesh") as VisualInstance3D
	if canister != null:
		canister.visible = false

	# Create volumetric smoke cloud Area3D
	cloud_area = Area3D.new()
	cloud_area.name = "SmokeCloudArea"
	cloud_area.add_to_group("smoke_cloud")
	add_child(cloud_area)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = cloud_radius
	shape.shape = sphere
	cloud_area.add_child(shape)

	# Procedural visual smoke puffs
	var puff_container := Node3D.new()
	puff_container.name = "SmokePuffs"
	cloud_area.add_child(puff_container)

	var puff_offsets: Array[Vector3] = [
		Vector3(0, 0.8, 0),
		Vector3(1.2, 0.6, 0.8),
		Vector3(-1.2, 0.6, -0.8),
		Vector3(-0.9, 0.9, 1.1),
		Vector3(1.0, 0.9, -1.0),
		Vector3(0, 1.6, 0)
	]

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.albedo_color = Color(0.85, 0.88, 0.85, 0.55)

	for off: Vector3 in puff_offsets:
		var puff := MeshInstance3D.new()
		var p_mesh := SphereMesh.new()
		p_mesh.radius = cloud_radius * 0.55
		p_mesh.height = cloud_radius * 1.0
		puff.mesh = p_mesh
		puff.material_override = smoke_mat
		puff.position = off
		puff.scale = Vector3(0.1, 0.1, 0.1)
		puff_container.add_child(puff)

		# Expansion tween
		var t := puff.create_tween()
		t.tween_property(puff, "scale", Vector3(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	detonated.emit(global_position)
	print("SmokeGrenade: Detonated! 4.5m smoke cloud deployed for %.1fs." % cloud_duration_s)

	# Fade out before cleanup
	var life_timer := get_tree().create_timer(cloud_duration_s - 2.0)
	life_timer.timeout.connect(func() -> void:
		if not is_instance_valid(smoke_mat):
			return
		var fade_tween := create_tween()
		fade_tween.tween_property(smoke_mat, "albedo_color:a", 0.0, 2.0)
		fade_tween.tween_callback(func() -> void:
			dissipated.emit()
			queue_free()
		)
	)
