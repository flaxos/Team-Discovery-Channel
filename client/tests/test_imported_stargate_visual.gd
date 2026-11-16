extends SceneTree
## The imported ring fits the current aperture/envelope; the seven controls stay in charge.


func _init() -> void:
	call_deferred("run")


func lit_count(visual: StargateVisual) -> int:
	var count := 0
	for light in visual.lights:
		if (light.get_surface_override_material(0) as StandardMaterial3D).emission_enabled:
			count += 1
	return count


func run() -> void:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("client/")
	var credits := FileAccess.get_file_as_string(repo.path_join("credits/ATTRIBUTIONS.md"))
	assert(credits.contains("stargate_sg1.glb") and credits.contains("rossrobotics"))
	assert(FileAccess.file_exists(repo.path_join("credits/licenses/CC-BY-4.0.txt")))
	var scene := load("res://scenes/props/Stargate.tscn") as PackedScene
	var baseline := scene.instantiate() as StargateRing
	var holder := Node3D.new()
	root.add_child(holder)
	var gate := scene.instantiate() as StargateRing
	var started := Time.get_ticks_usec()
	holder.add_child(gate)
	var first_ms := (Time.get_ticks_usec() - started) / 1000.0
	await process_frame
	await process_frame
	assert(gate.max_chevrons == 7 and gate.kawoosh_duration_s == baseline.kawoosh_duration_s)
	for path: String in ["GateRingMesh", "EventHorizon", "GateLight", "KawooshArea",
			"KawooshArea/CollisionShape3D", "KawooshArea/VortexMesh", "ExtractionArea",
			"ExtractionArea/CollisionShape3D", "Chevrons"]:
		assert((gate.get_node(path) as Node3D).transform.is_equal_approx((baseline.get_node(path) as Node3D).transform),
			"Unchanged gameplay transform: " + path)
	assert(gate.kawoosh_area.collision_mask == 6 and gate.extraction_area.collision_mask == 2)
	assert((gate.get_node("ExtractionArea/CollisionShape3D") as CollisionShape3D).shape ==
		(baseline.get_node("ExtractionArea/CollisionShape3D") as CollisionShape3D).shape)
	assert((gate.get_node("KawooshArea/CollisionShape3D") as CollisionShape3D).shape ==
		(baseline.get_node("KawooshArea/CollisionShape3D") as CollisionShape3D).shape)
	for i in range(7):
		var anchor := gate.chevron_container.get_child(i) as CSGBox3D
		var before := baseline.get_node("Chevrons").get_child(i) as CSGBox3D
		assert(anchor.transform.is_equal_approx(before.transform) and anchor.size == before.size)
		assert(anchor.use_collision == before.use_collision)
	var visual := gate.get_node_or_null("CommunityVisual") as StargateVisual
	if OS.get_cmdline_user_args().has("--expect-fallback"):
		assert(visual == null and (gate.get_node("GateRingMesh") as MeshInstance3D).visible)
		for node: Node in gate.chevron_container.get_children():
			assert(is_zero_approx((node as CSGBox3D).transparency))
		baseline.free()
		holder.queue_free()
		print("test_imported_stargate_visual: PASS (fallback)")
		await preload("res://tests/support/finish.gd").success(self)
		return
	assert(visual != null, "Imported ring attached")
	assert(not (gate.get_node("GateRingMesh") as MeshInstance3D).visible)
	assert(visual.lights.size() == 14 and lit_count(visual) == 0, "Seven front/back light pairs")
	var triangles := 0
	var meshes := 0
	var ring_min := INF
	var ring_max := 0.0
	for node: Node in visual.find_children("*", "", true, false):
		assert(not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D))
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		meshes += 1
		var placed := gate.global_transform.affine_inverse() * mi.global_transform
		for s in range(mi.mesh.get_surface_count()):
			triangles += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			assert(mat != null and is_zero_approx(mat.metallic))
			assert(mat.albedo_texture.get_image().has_mipmaps())
			if mi.name == &"gate_ring":
				for point: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var p := placed * point
					ring_min = minf(ring_min, Vector2(p.x, p.y).length())
					ring_max = maxf(ring_max, Vector2(p.x, p.y).length())
	assert(meshes == 29 and triangles == 12057, "One glyph ring and seven four-part inserts")
	assert(ring_min >= 2.748 and ring_min < 2.76 and ring_max < 3.35,
		"Existing 2.75 m aperture and 3.35 m envelope: %f, %f" % [ring_min, ring_max])
	assert(StargateVisual.ENVELOPE.grow(0.02).encloses(visual.bounds))
	gate.sync_gate_snapshot(StargateRing.GateState.ACTIVE, StargateRing.GateDirection.OUTBOUND, 4, true)
	await process_frame
	await process_frame
	assert(lit_count(visual) == 8 and gate.event_horizon_mesh.visible and gate.extraction_authorized,
		"Late join snapshot drives four existing chevron controls")
	gate.sync_close_wormhole()
	await process_frame
	await process_frame
	assert(lit_count(visual) == 0 and not gate.event_horizon_mesh.visible)
	gate.reserve_connection(false)
	for i in range(1, 8):
		gate.lock_chevron(i)
	await process_frame
	await process_frame
	assert(lit_count(visual) == 14 and gate.current_state == StargateRing.GateState.KAWOOSH)
	assert(gate.kawoosh_mesh.visible and gate.event_horizon_mesh.visible)
	await create_timer(gate.kawoosh_duration_s + 0.15).timeout
	assert(gate.current_state == StargateRing.GateState.ACTIVE)
	gate.sync_reset_chevrons()
	await process_frame
	await process_frame
	assert(lit_count(visual) == 0)
	gate.close_wormhole()
	# A missing source leaves an untouched, unscripted copy of the original visuals.
	var fallback := Node3D.new()
	fallback.add_child(baseline.get_node("GateRingMesh").duplicate())
	fallback.add_child(baseline.get_node("Chevrons").duplicate())
	holder.add_child(fallback)
	assert(StargateVisual.attach(fallback, "res://assets/props/missing.glb") == null)
	assert((fallback.get_node("GateRingMesh") as MeshInstance3D).visible)
	var second := scene.instantiate() as StargateRing
	started = Time.get_ticks_usec()
	holder.add_child(second)
	var repeat_ms := (Time.get_ticks_usec() - started) / 1000.0
	var ring_a := visual.get_node("gate_ring") as MeshInstance3D
	var ring_b := second.get_node("CommunityVisual/gate_ring") as MeshInstance3D
	assert(ring_a.mesh == ring_b.mesh and ring_a.get_surface_override_material(0) == ring_b.get_surface_override_material(0))
	print("STARGATE_COST first_ms=%.3f repeat_ms=%.3f triangles_per_gate=%d bounds=%s" %
		[first_ms, repeat_ms, triangles, visual.bounds])
	print("test_imported_stargate_visual: PASS")
	baseline.free()
	holder.queue_free()
	await preload("res://tests/support/finish.gd").success(self)
