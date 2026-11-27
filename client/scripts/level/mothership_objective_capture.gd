extends SceneTree
## Automated Forward+ GPU captures for Sprint 33 Goa'uld Mothership Objective review.
## Captures:
## 1. 01_engineering_reactor_core: Hyperdrive reactor core & containment rings in engineering
## 2. 02_engineering_diagnostics: Engineering console & power raceway
## 3. 03_security_blast_door: Blast door transition between engineering & bridge
## 4. 04_bridge_command_helm: Bridge helm console, tactical stations & gold trim
## 5. 05_bridge_viewport_vista: Forward observation viewport framing deep space vista
## 6. 06_alarm_escape_lighting: Bridge under red shipboard alert / alarm escape lighting

const LAYOUT_PATH := "res://resources/levels/ai2_goauld_mothership_objective.tres"

const SHOTS := {
	"01_engineering_reactor_core": [&"engineering", Vector3(-2.2, 1.8, 1.5), Vector3(0, 1.5, 4.5), false],
	"02_engineering_diagnostics": [&"engineering", Vector3(-1.0, 1.6, 0.0), Vector3(2.2, 1.2, -2.2), false],
	"03_security_blast_door": [&"engineering", Vector3(0, 1.6, 0.5), Vector3(0, 1.5, -4.0), false],
	"04_bridge_command_helm": [&"bridge", Vector3(4.0, 2.2, 9.5), Vector3(4.0, 1.4, 3.5), false],
	"05_bridge_viewport_vista": [&"bridge", Vector3(4.0, 1.4, 0.5), Vector3(4.0, 1.3, -3.4), false],
	"06_alarm_escape_lighting": [&"bridge", Vector3(4.0, 1.8, 7.5), Vector3(4.0, 1.4, 3.5), true]
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var layout: LevelLayout = load(LAYOUT_PATH)
	if layout == null:
		push_error("Layout not found: " + LAYOUT_PATH)
		quit(1)
		return

	var output_dir := "build/sprint33/captures"
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

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 75.0
	root.add_child(camera)

	var cam_light := OmniLight3D.new()
	cam_light.omni_range = 25.0
	cam_light.light_color = Color(1.0, 0.92, 0.80)
	cam_light.light_energy = 1.2
	camera.add_child(cam_light)

	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.04, 0.03, 0.02, 1.0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.48, 0.38, 0.26, 1.0)
	env_res.ambient_light_energy = 1.2
	env.environment = env_res
	root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.3, -0.7, -0.6).normalized(), Vector3.UP), Vector3(0, 20, 0))
	sun.light_color = Color(1.0, 0.88, 0.65)
	sun.light_energy = 1.0
	root.add_child(sun)

	for shot_name: String in SHOTS:
		var shot: Array = SHOTS[shot_name]
		var room_id: StringName = shot[0]
		var cam_local: Vector3 = shot[1]
		var target_local: Vector3 = shot[2]
		var is_alarm: bool = shot[3]

		if is_alarm:
			env_res.ambient_light_color = Color(0.65, 0.15, 0.10, 1.0)
			sun.light_color = Color(1.0, 0.25, 0.15)
			sun.light_energy = 1.6
			cam_light.light_color = Color(1.0, 0.2, 0.15)
			cam_light.light_energy = 1.4
		else:
			env_res.ambient_light_color = Color(0.48, 0.38, 0.26, 1.0)
			sun.light_color = Color(1.0, 0.88, 0.65)
			sun.light_energy = 1.0
			cam_light.light_color = Color(1.0, 0.92, 0.80)
			cam_light.light_energy = 1.2

		var module := assembly.get_node(str(room_id)) as LevelModule
		if module == null:
			continue

		var cam_world := module.global_transform * cam_local
		var target_world := module.global_transform * target_local

		camera.global_position = cam_world
		camera.look_at(target_world, Vector3.UP)

		for f in range(8):
			await process_frame

		var img := root.get_viewport().get_texture().get_image()
		var file_path := output_dir + "/" + shot_name + ".png"
		img.save_png(file_path)
		print("Saved capture: " + file_path)

	print("PASS All Sprint 33 captures written to " + output_dir)
	quit(0)
