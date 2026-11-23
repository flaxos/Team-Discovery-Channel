extends SceneTree
## Checks all four exterior fits and their existing in-game visibility and removal states.

const SATCHEL := preload("res://scenes/props/C4Satchel.tscn")
const MINE := preload("res://scenes/props/ClaymoreMine.tscn")
const SHIELD := preload("res://scenes/props/DeployableShield.tscn")
const SMOKE := preload("res://scenes/weapons/SmokeGrenade.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var mine := MINE.instantiate() as ClaymoreMine
	var shield := SHIELD.instantiate() as DeployableShield
	root.add_child(mine)
	root.add_child(shield)
	var remote := SATCHEL.instantiate() as C4Satchel
	var timed := SATCHEL.instantiate() as C4Satchel
	remote.freeze = true
	timed.freeze = true
	timed.position = Vector3(4, 0, 0)
	timed.set_timer_mode(5.0)
	root.add_child(remote)
	root.add_child(timed)
	var satchel := remote.get_node("MeshInstance3D") as MeshInstance3D
	var timed_satchel := timed.get_node("MeshInstance3D") as MeshInstance3D
	var satchel_shape := remote.get_node("CollisionShape3D").shape as BoxShape3D
	var asset_fallback := OS.get_cmdline_user_args().has("--expect-fallback")
	var satchel_envelope := AABB(Vector3(-0.2, -0.1, -0.15), Vector3(0.4, 0.2, 0.3))
	if (asset_fallback and not satchel.mesh is BoxMesh) \
		or (not asset_fallback and not fits(remote, satchel, satchel_envelope.grow(0.001))) \
		or satchel.mesh != timed_satchel.mesh or not satchel_shape.size.is_equal_approx(satchel_envelope.size) \
		or remote.led_light.visible or timed.led_light.visible:
		push_error("C4 variants must share a fitted mesh within the original volume")
		quit(1)
		return
	var smoke := SMOKE.instantiate() as SmokeGrenade
	var second_smoke := SMOKE.instantiate() as SmokeGrenade
	smoke.freeze = true
	second_smoke.freeze = true
	root.add_child(smoke)
	root.add_child(second_smoke)
	var canister := smoke.get_node("CanisterMesh") as MeshInstance3D
	var duplicate := second_smoke.get_node("CanisterMesh") as MeshInstance3D
	var canister_shape := smoke.get_node("CollisionShape3D").shape as CylinderShape3D
	if (asset_fallback and not canister.mesh is CylinderMesh) \
		or (not asset_fallback and not fits(smoke, canister, AABB(Vector3(-0.08, -0.11, -0.08), Vector3(0.16, 0.22, 0.16)))) \
		or canister.mesh != duplicate.mesh or not is_equal_approx(canister_shape.radius, 0.08) \
		or not is_equal_approx(canister_shape.height, 0.22):
		push_error("Smoke visual does not fit or share its original canister envelope")
		quit(1)
		return
	if not asset_fallback:
		var material := canister.mesh.surface_get_material(0) as BaseMaterial3D
		if material == null or material.albedo_texture == null or not material.albedo_texture.get_image().has_mipmaps():
			push_error("Smoke canister is missing its packed mipmapped material")
			quit(1)
			return
	var arming := mine.get_node("BodyMesh/ArmingLens") as MeshInstance3D
	var armed := mine.get_node("BodyMesh/ArmedLens") as MeshInstance3D
	var shield_volume := shield.get_node("CollisionShape3D") as CollisionShape3D
	var carrier_shape := shield_volume.shape as BoxShape3D
	var collision_bounds := AABB(shield_volume.position - carrier_shape.size / 2.0, carrier_shape.size)
	var mine_visual := mine.get_node("BodyMesh") as MeshInstance3D
	var shield_visual := shield.get_node("Visuals/ShieldMesh") as MeshInstance3D
	if not arming.visible or armed.visible or mine.tripwire_area.monitoring \
		or not fits(mine, mine_visual, AABB(Vector3(-0.25, -0.001, -0.075), Vector3(0.50, 0.301, 0.15))) \
		or not fits(shield, shield_visual, collision_bounds.grow(0.001)) \
		or not carrier_shape.size.is_equal_approx(Vector3(2.2, 0.9, 0.25)) \
		or not shield_volume.position.is_equal_approx(Vector3(0, 0.45, 0)):
		push_error("Field-kit exterior, arming indicator or collision envelope is incorrect")
		quit(1)
		return
	await create_timer(1.1).timeout
	if not mine.is_armed or not mine.tripwire_area.monitoring or arming.visible or not armed.visible:
		push_error("Claymore indicator did not follow the existing arming transition")
		quit(1)
		return

	if canister.visible or not smoke.is_detonated or smoke.cloud_area == null \
		or not smoke.cloud_area.global_position.is_equal_approx(smoke.global_position):
		push_error("Smoke visual did not hand off to the existing cloud at its origin")
		quit(1)
		return
	if not remote.led_light.visible or not timed.led_light.visible or not timed.is_armed \
		or timed.mode != C4Satchel.C4Mode.TIMER_5S:
		push_error("The shared satchel visual must leave the existing timed and remote cues active")
		quit(1)
		return
	var emitted: Array[Vector3] = []
	var remote_origin := remote.global_position
	remote.exploded.connect(func(origin: Vector3) -> void: emitted.append(origin))
	remote.detonate()
	if emitted != [remote_origin]:
		push_error("The remote satchel effect must originate at the original scene anchor")
		quit(1)
		return
	shield.health_component.take_damage(shield.health_component.max_health + 1.0)
	if shield.collision_layer != 0 or shield.is_in_group("cover"):
		push_error("Destroyed shield must release its original cover")
		quit(1)
		return
	await create_timer(0.4).timeout
	if is_instance_valid(shield):
		push_error("The shield and its visual children must expire together")
		quit(1)
		return
	print("test_field_kit_visuals: PASS four exterior fits and existing effect and removal states")
	await preload("res://tests/support/finish.gd").success(self)


func fits(prop: Node3D, visual: MeshInstance3D, bounds: AABB) -> bool:
	if visual.mesh == null or not visual.mesh is ArrayMesh:
		return false
	var parts: Array[MeshInstance3D] = [visual]
	for child: Node in visual.find_children("*", "MeshInstance3D", true, false):
		parts.append(child as MeshInstance3D)
	for item: MeshInstance3D in parts:
		var box := prop.global_transform.affine_inverse() * item.global_transform * item.get_aabb()
		if not bounds.encloses(box):
			return false
	return true
