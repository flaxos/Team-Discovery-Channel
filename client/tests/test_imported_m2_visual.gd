extends SceneTree
## Also run from a Linux release pack, where assertions may be disabled.

const TURRET := preload("res://scenes/props/DeployableTurret.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var first := TURRET.instantiate() as DeployableTurret
	var started := Time.get_ticks_usec()
	root.add_child(first)
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	var gun := first.get_node_or_null("TurretHead/M2Gun") as MeshInstance3D
	var tripod := first.get_node_or_null("M2Tripod") as MeshInstance3D
	var fallback := first.get_node("TripodBase") as MeshInstance3D
	if OS.get_cmdline_user_args().has("--expect-fallback"):
		if gun != null or tripod != null or not fallback.visible:
			push_error("Expected the original turret fallback")
			quit(1)
			return
		print("test_imported_m2_visual: PASS fallback")
		await preload("res://tests/support/finish.gd").success(self)
		return
	if gun == null or tripod == null or fallback.visible:
		push_error("The imported gun and tripod must replace the placeholders")
		quit(1)
		return

	var second := TURRET.instantiate() as DeployableTurret
	started = Time.get_ticks_usec()
	root.add_child(second)
	var cached_ms := (Time.get_ticks_usec() - started) / 1000.0
	var second_gun := second.get_node("TurretHead/M2Gun") as MeshInstance3D
	var second_tripod := second.get_node("M2Tripod") as MeshInstance3D
	var shape := first.get_node("InteractArea/CollisionShape3D").shape as CylinderShape3D
	var stationary := tripod.global_transform
	var bore := measured_bore(gun)
	var initial_marker := first.muzzle_point.global_position
	first.turret_head.rotation.y = 0.63
	if gun.mesh != second_gun.mesh or tripod.mesh != second_tripod.mesh \
			or not tripod.global_transform.is_equal_approx(stationary) \
			or initial_marker.distance_to(bore) > 0.003 \
			or first.muzzle_point.global_position.distance_to(measured_bore(gun)) > 0.003 \
			or first.muzzle_point.position != Vector3(0, 0, -1.2) \
			or not is_equal_approx(shape.radius, 1.8) or not is_equal_approx(shape.height, 2.0):
		push_error("M2 pivot, marker, interaction reach or cache did not match the contract")
		quit(1)
		return

	var images := {}
	var triangles := 0
	var limits := AABB()
	for item: MeshInstance3D in [gun, tripod]:
		var bounds := item.global_transform * item.get_aabb()
		limits = bounds if not limits.has_volume() else limits.merge(bounds)
		for surface in range(item.mesh.get_surface_count()):
			triangles += (item.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var material := item.mesh.surface_get_material(surface) as BaseMaterial3D
			for slot: StringName in RuntimeGLB.TEXTURE_SLOTS:
				var texture := material.get(slot) as Texture2D
				if texture == null or images.has(texture):
					continue
				var image := texture.get_image()
				if not image.has_mipmaps():
					push_error("M2 texture is missing mipmaps")
					quit(1)
					return
				images[texture] = image.get_data_size()
	var bytes := 0
	for size: int in images.values():
		bytes += size
	if triangles != 49589 or images.size() != 6 or bytes > 64 * 1024 * 1024:
		push_error("M2 triangle or texture budget mismatch")
		quit(1)
		return
	print("test_imported_m2_visual: PASS triangles=", triangles, " decoded_bytes=", bytes,
		" cold_ms=", cold_ms, " cached_ms=", cached_ms, " yawed_bounds=", limits)
	await preload("res://tests/support/finish.gd").success(self)


func measured_bore(gun: MeshInstance3D) -> Vector3:
	var tip := INF
	var points := PackedVector3Array()
	for surface in range(gun.mesh.get_surface_count()):
		for vertex: Vector3 in gun.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var point := gun.transform * vertex
			points.append(point)
			tip = minf(tip, point.z)
	var sum := Vector3.ZERO
	var count := 0
	for point: Vector3 in points:
		if point.z - tip <= 0.0006:
			count += 1
			sum += point
	return (gun.get_parent() as Node3D).to_global(sum / count)
