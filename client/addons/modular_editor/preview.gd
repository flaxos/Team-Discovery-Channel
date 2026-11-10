extends Node


func _ready() -> void:
	var scene_path := "res://scenes/level/EditorPreview.tscn"
	if "--scene" in OS.get_cmdline_user_args():
		var args := OS.get_cmdline_user_args()
		scene_path = args[args.find("--scene") + 1]
	var level := load(scene_path).instantiate() as LevelAssembly
	add_child(level)
	await level.navigation_ready
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.05, 0.06, 0.08)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	var palette := LevelThemeResolver.lighting(level.layout)
	if palette != null:
		settings.ambient_light_color = palette.ambient_color
		settings.ambient_light_energy = palette.ambient_energy
	environment.environment = settings
	level.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	level.add_child(sun)
	# Cutaway is preview-only; ceiling collision and bake source remain intact.
	for item in level.layout.instances:
		for mesh in level.get_node(str(item.id) + "/Visuals").get_children():
			if str(mesh.name).begins_with("Roof"):
				mesh.hide()
	if "--capture" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		level.add_child(camera)
		var bounds := (
			level.layout.instances[0].placement(
				float(level.layout.decks[str(level.layout.instances[0].deck)])
			)
			* level.layout.instances[0].module.occupied
		)
		for item in level.layout.instances:
			bounds = bounds.merge(
				item.placement(float(level.layout.decks[str(item.deck)])) * item.module.occupied
			)
		var span := maxf(bounds.size.x, bounds.size.z)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.far = maxf(500, span * 10)
		camera.position = bounds.get_center() + Vector3(span * .25, span * 2, span * .35)
		camera.look_at(bounds.get_center())
		var projected := camera.global_transform.affine_inverse() * bounds
		var aspect := get_viewport().get_visible_rect().size.aspect()
		camera.position += (
			camera.basis * Vector3(projected.get_center().x, projected.get_center().y, 0)
		)
		camera.size = maxf(projected.size.y, projected.size.x / aspect) * 1.2
		camera.current = true
		for i in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var destination := "/tmp/modular-overview.png"
		var args := OS.get_cmdline_user_args()
		if "--capture-output" in args:
			destination = args[args.find("--capture-output") + 1]
		if get_viewport().get_texture().get_image().save_png(destination) != OK:
			push_error("Cannot save preview capture: " + destination)
			get_tree().quit(1)
			return
		call_deferred("_finish_capture")
		return
	else:
		var players := Node3D.new()
		players.name = "Players"
		level.add_child(players)
		var pawn := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
		pawn.name = "1"
		players.add_child(pawn)
		pawn.position = level.marker(level.layout.entry_instance, &"entry") + Vector3(0, 0.03, 0)


func _finish_capture() -> void:
	# Return from _ready before teardown so its renderer resource references retire.
	preload("res://tests/support/finish.gd").success(get_tree())
