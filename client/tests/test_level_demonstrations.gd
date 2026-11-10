extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for brief: Array in [
		["neutral_installation", &"neutral", [&"jaffa_barracks", &"security_control", &"cargo"]],
		["goauld_compound", &"goauld", [&"ring_transport", &"generator"]],
		["asgard_ship", &"asgard", [&"command", &"laboratory_medical", &"ring_transport"]]
	]:
		var source := load("res://resources/levels/ai_" + brief[0] + ".tres") as LevelLayout
		assert(source != null and source.default_theme == brief[1])
		assert(LevelLayoutValidator.validate(source).is_empty())
		var roles := {}
		var degree := {}
		for item in source.instances:
			assert(LevelCatalogue.module_by_id(item.module.id) != null)
			if item.room_preset != null:
				roles[item.room_preset.id] = true
			assert(LevelThemeResolver.describe(source, item).visual_source == "neutral")
		for required: StringName in brief[2]:
			assert(roles.has(required))
		for edge in source.connections:
			degree[edge.from_instance] = int(degree.get(edge.from_instance, 0)) + 1
			degree[edge.to_instance] = int(degree.get(edge.to_instance, 0)) + 1
		if brief[0] == "goauld_compound":
			var branch := false
			for count: int in degree.values():
				if count >= 3:
					branch = true
			assert(branch, "Compound must have a real branching graph")
		var assembly := LevelAssembly.new()
		assembly.layout = source
		root.add_child(assembly)
		while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
			await process_frame
		assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
		var goal := assembly.marker(source.destination_instance, source.destination_marker)
		var route := assembly.local_path(
			assembly.marker(source.entry_instance, source.entry_marker), goal
		)
		assert(not route.is_empty() and route[-1].distance_to(goal) < .5)
		var source_hash := FileAccess.get_sha256(source.resource_path)
		assert(
			not (
				LevelBuildPipeline
				. export(assembly, "user://protected.tscn", source.resource_path)
				. is_empty()
			)
		)
		assert(FileAccess.get_sha256(source.resource_path) == source_hash)
		var module_path := source.instances[0].module.scene.resource_path
		var module_hash := FileAccess.get_sha256(module_path)
		assert(
			not (
				LevelBuildPipeline
				. export(assembly, module_path, "user://protected_nav.tres")
				. is_empty()
			)
		)
		assert(FileAccess.get_sha256(module_path) == module_hash)
		var errors := LevelBuildPipeline.export(
			assembly, "user://demo_" + brief[0] + ".tscn", "user://demo_" + brief[0] + ".tres"
		)
		assert(errors.is_empty(), str(errors))
		assembly.queue_free()
		await process_frame
		var reopened := load("user://demo_" + brief[0] + ".tscn").instantiate() as LevelAssembly
		root.add_child(reopened)
		while not reopened.ready_for_navigation and reopened.last_errors.is_empty():
			await process_frame
		assert(reopened.last_errors.is_empty() and reopened.layout.default_theme == brief[1])
		reopened.queue_free()
		await process_frame
	print(
		"PASS all three natural-language briefs: existing prefabs/roles, faction-neutral fallback, branching, full validation/navigation and native exported-scene reload"
	)
	await preload("res://tests/support/finish.gd").success(self)
