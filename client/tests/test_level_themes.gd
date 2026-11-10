extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var themes := LevelThemeResolver.registry()
	for id: StringName in [&"neutral", &"tauri_sgc", &"goauld", &"asgard", &"tokra", &"replicator"]:
		assert(themes.has(id) and LevelThemeResolver.validate_theme(themes[id]).is_empty())
	var model := Model.new()
	model.restore(
		model.placed(load("res://resources/level_modules/Room01Straight.tres"), Vector2.ZERO, 0)
	)
	var source := model.layout
	var item := source.instances[0]
	var assembly := LevelAssembly.new()
	assembly.layout = source
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert(assembly.last_errors.is_empty())
	var module := assembly.get_node(str(item.id)) as LevelModule
	var body := module.get_node("Structure/Collision/Wall2/Shape") as CollisionShape3D
	var shape := body.shape
	var navigation := assembly.navigation.navigation_mesh
	var occupied := item.module.occupied
	var socket := item.module.sockets[0].local_transform
	for id: StringName in [&"neutral", &"tauri_sgc", &"goauld", &"asgard", &"tokra", &"replicator"]:
		source.default_theme = id
		assert(LevelLayoutValidator.validate(source).is_empty())
		assert(LevelThemeResolver.apply(source, item, module).is_empty())
		assert(LevelThemeResolver.describe(source, item).visual_source == "neutral")
		assert(
			(
				body.shape == shape
				and assembly.navigation.navigation_mesh == navigation
				and item.module.occupied == occupied
				and item.module.sockets[0].local_transform == socket
			)
		)
	var zone := LevelThemeZone.new()
	zone.id = &"command_zone"
	zone.theme_id = &"asgard"
	source.theme_zones.append(zone)
	item.theme_zone = zone.id
	assert(LevelThemeResolver.selected(source, item).id == &"asgard")
	item.style = &"goauld"
	assert(LevelThemeResolver.selected(source, item).id == &"goauld")
	item.theme_id = &"neutral"
	assert(LevelThemeResolver.selected(source, item).id == &"neutral")
	item.theme = themes[&"tokra"]
	assert(LevelThemeResolver.selected(source, item).id == &"tokra")
	var copy := Model.copy(source)
	copy.theme_zones[0].theme_id = &"neutral"
	assert(source.theme_zones[0].theme_id == &"asgard")
	assert(ResourceSaver.save(source, "user://theme_roundtrip.tres") == OK)
	var reloaded := (
		ResourceLoader.load("user://theme_roundtrip.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
		as LevelLayout
	)
	assert(
		(
			reloaded.default_theme == source.default_theme
			and reloaded.instances[0].theme_zone == zone.id
		)
	)
	var custom := LevelVisualTheme.new()
	custom.id = &"custom_visual"
	custom.art_status = "authored"
	var variant := LevelThemeVariant.new()
	variant.id = &"wall"
	variant.slot = &"wall"
	variant.scene_path = "res://tests/fixtures/theme_wall.tscn"
	custom.variants.append(variant)
	item.theme = custom
	assert(LevelThemeResolver.validate_theme(custom).is_empty())
	assert(LevelThemeResolver.apply(source, item, module).is_empty())
	assert(module.get_node("Visuals/Wall2/ThemeVisual") is MeshInstance3D)
	assert(body.shape == shape and assembly.navigation.navigation_mesh == navigation)
	variant.local_transform.origin.x = 10
	assert(not LevelThemeResolver.apply(source, item, module).is_empty())
	assert(
		(
			not module.has_node("Visuals/Wall2/ThemeVisual")
			and (module.get_node("Visuals/Wall2") as MeshInstance3D).mesh != null
		)
	)
	variant.scene_path = "res://tests/fixtures/does_not_exist.tscn"
	assert(LevelThemeResolver.validate_theme(custom).is_empty())
	assert(LevelThemeResolver.apply(source, item, module).is_empty())
	variant.scene_path = "res://tests/fixtures/theme_physics.tscn"
	assert("forbidden node" in str(LevelThemeResolver.validate_theme(custom)))
	assert(body.shape == shape)
	custom.variants.clear()
	custom.fallback_id = &"missing"
	assert("Unknown theme fallback" in str(LevelThemeResolver.validate_theme(custom)))
	custom.fallback_id = &"neutral"
	item.theme = null
	item.theme_id = &"missing"
	assert("Unknown room theme" in str(LevelLayoutValidator.validate(source)))
	item.theme_id = &""
	item.style = &"legacy_unregistered_style"
	assert(
		(
			LevelLayoutValidator.validate(source).is_empty()
			and LevelThemeResolver.selected(source, item).id == &"neutral"
		)
	)
	assembly.queue_free()
	await process_frame
	print(
		"PASS six themes/fallbacks, legacy precedence, sparse map/zone/room state, resource reload and cosmetic-only replacement safety"
	)
	await preload("res://tests/support/finish.gd").success(self)
