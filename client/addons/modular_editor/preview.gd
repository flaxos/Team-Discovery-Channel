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
		camera.position = Vector3(20, 42, 25)
		camera.look_at(Vector3(-4, 0, -4))
		camera.current = true
		for i in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/modular-overview.png")
		await preload("res://tests/support/finish.gd").success(get_tree())
	else:
		var players := Node3D.new()
		players.name = "Players"
		level.add_child(players)
		var pawn := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
		pawn.name = "1"
		players.add_child(pawn)
		pawn.position = level.marker(level.layout.entry_instance, &"entry") + Vector3(0, 0.03, 0)
