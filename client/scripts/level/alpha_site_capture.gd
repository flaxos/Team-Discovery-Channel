extends SceneTree
## Automated captures for Sprint 31 Alpha Site outpost review.
## Captures:
## 1. Hub / pre-fab shelter interior corridors
## 2. Cargo storage wing with field crates
## 3. Command center with records terminal
## 4. Observation & communications room with field console, comms rack and civilian
## 5. View through the observation aperture looking at the exterior mountain vista

const LAYOUT_PATH := "res://resources/levels/ai2_tauri_alpha_site.tres"

const SHOTS := {
	"01_outpost_hub": [&"hub", Vector3(0, 1.7, 3.2), Vector3(0, 1.4, -3.5)],
	"02_stores_cargo": [&"stores_store_small", Vector3(-2.8, 1.7, 2.8), Vector3(1.0, 1.0, -1.0)],
	"03_command_center": [&"cmd_command", Vector3(0, 1.8, -4.0), Vector3(4.0, 1.2, 2.0)],
	"04_observation_room": [&"cmd_observation", Vector3(-2.8, 1.7, -2.8), Vector3(0.5, 1.2, 1.5)],
	"05_aperture_vista": [&"cmd_observation", Vector3(0, 1.6, 1.0), Vector3(0, 1.8, 12.0)]
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var layout: LevelLayout = load(LAYOUT_PATH)
	if layout == null:
		push_error("Layout not found: " + LAYOUT_PATH)
		quit(1)
		return

	var output_dir := "build/sprint31/captures"
	DirAccess.make_dir_recursive_absolute(output_dir)

	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)

	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame

	if not assembly.last_errors.is_empty():
		push_error("Assembly errors: " + str(assembly.last_errors))
		quit(1)
		return

	# Add camera and environment
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 75.0
	root.add_child(camera)

	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.12, 0.15, 0.18, 1.0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.35, 0.38, 0.40, 1.0)
	env_res.ambient_light_energy = 1.0
	env.environment = env_res
	root.add_child(env)

	# Sun light matching exterior vista
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.6, -0.7).normalized(), Vector3.UP), Vector3(0, 20, 0))
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.2
	root.add_child(sun)

	for shot_name: String in SHOTS:
		var shot: Array = SHOTS[shot_name]
		var room_id: StringName = shot[0]
		var cam_local: Vector3 = shot[1]
		var target_local: Vector3 = shot[2]

		var module := assembly.get_node(str(room_id)) as LevelModule
		if module == null:
			continue

		var cam_world := module.global_transform * cam_local
		var target_world := module.global_transform * target_local

		camera.global_position = cam_world
		camera.look_at(target_world, Vector3.UP)

		# Settle frames for lighting & textures
		for f in range(6):
			await process_frame

		var img := root.get_viewport().get_texture().get_image()
		var file_path := output_dir + "/" + shot_name + ".png"
		img.save_png(file_path)
		print("Saved capture: " + file_path)

	print("PASS All Sprint 31 captures written to " + output_dir)
	quit(0)
