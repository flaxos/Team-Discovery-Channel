extends SceneTree
## Milestone 2: Verify per-module draw-call batching in LevelThemeResolver cuts
## visible MeshInstance3D nodes across Goa'uld compounds while preserving bounds & neutral reset.

const INFILTRATION := "res://resources/levels/goauld_infiltration_01.tres"
const MOTHERSHIP_OBJ := "res://resources/levels/ai2_goauld_mothership_objective.tres"


func _init() -> void:
	call_deferred("run")


func _assemble(path: String) -> LevelAssembly:
	var layout := load(path) as LevelLayout
	assert(layout != null)
	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
	return assembly


func run() -> void:
	for path: String in [INFILTRATION, MOTHERSHIP_OBJ]:
		var assembly := await _assemble(path)
		var visible_meshes := 0
		var batch_nodes := 0
		for module: Node in assembly.get_children():
			if not module is LevelModule:
				continue
			var visuals := module.get_node_or_null(^"Visuals") as Node3D
			if visuals == null:
				continue
			var info: Dictionary = module.get_meta("architectural_theme", {})
			var batch := visuals.get_node_or_null(^"ThemeBatch/BatchedMesh") as MeshInstance3D
			if info.get("coverage", "") == "pieces":
				assert(batch != null and batch.mesh != null and batch.mesh.get_surface_count() > 0,
					"Pieced module must batch theme visuals: " + module.name)
				batch_nodes += 1
				var source_bounds := AABB()
				var have_source := false
				for node: Node in visuals.find_children("*", "MeshInstance3D", true, false):
					var mi := node as MeshInstance3D
					if mi == batch or mi.get_parent() == visuals or str(mi.get_parent().name) == "Closures":
						continue
					assert(not mi.visible, "Batched leaf mesh must be hidden: %s/%s" % [module.name, mi.name])
					var rel := visuals.global_transform.affine_inverse() * mi.global_transform
					var box := rel * mi.mesh.get_aabb()
					source_bounds = box if not have_source else source_bounds.merge(box)
					have_source = true
				assert(have_source and batch.mesh.get_aabb().is_equal_approx(source_bounds),
					"Batched AABB must match source geometry on " + module.name)
			for node: Node in visuals.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.visible and mi.mesh != null:
					visible_meshes += 1
		assert(batch_nodes > 0)
		assert(visible_meshes < 250, "Expected < 250 visible modular meshes on %s, got %d" % [path, visible_meshes])
		print("PASS theme batching %s: batch_nodes=%d visible_meshes=%d" % [path.get_file(), batch_nodes, visible_meshes])

		# Resetting to neutral clears all ThemeBatch nodes cleanly.
		var first_mod := assembly.get_node(str(assembly.layout.instances[0].id)) as LevelModule
		var neutral := assembly.layout.duplicate(true) as LevelLayout
		neutral.default_theme = &"neutral"
		assert(LevelThemeResolver.apply(neutral, assembly.layout.instances[0], first_mod).is_empty())
		assert(first_mod.get_node(^"Visuals").get_node_or_null(^"ThemeBatch") == null, "Neutral reset removes ThemeBatch")

		assembly.queue_free()
		await physics_frame
		await physics_frame

	await preload("res://tests/support/finish.gd").success(self)
