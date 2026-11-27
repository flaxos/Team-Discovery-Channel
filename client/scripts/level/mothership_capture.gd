extends SceneTree
## Automated captures for Sprint 32 Goa'uld Mothership Boarding review.
## Captures:
## 1. 01_boarding_gate: Boarding insertion Stargate & DHD in hangar
## 2. 02_bulkhead_vestibule: Transition vestibule with Goa'uld architecture
## 3. 03_cargo_bay: Cargo bay with heavy ordnance crates & records console
## 4. 04_ramp_and_rings: Access ramp and lower transport ring platform
## 5. 05_upper_checkpoint: Deck 1 interior checkpoint with boarding bulkhead & crates

const LAYOUT_PATH := "res://resources/levels/ai2_goauld_mothership_boarding.tres"

const SHOTS := {
	"01_boarding_gate": [&"gate", Vector3(0, 2.0, 10.0), Vector3(0, 1.5, -4.0)],
	"02_bulkhead_vestibule": [&"vestibule", Vector3(0, 1.6, -3.2), Vector3(0, 1.4, 3.5)],
	"03_cargo_bay": [&"cargo_bay", Vector3(-2.8, 1.8, -2.8), Vector3(1.5, 1.2, 1.5)],
	"04_ramp_and_rings": [&"cargo_bay", Vector3(0, 1.7, 0), Vector3(4.0, 1.4, 0)],
	"05_upper_checkpoint": [&"interior_checkpoint", Vector3(2.8, 1.8, 2.8), Vector3(-1.5, 1.2, -1.5)]
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var layout: LevelLayout = load(LAYOUT_PATH)
	if layout == null:
		push_error("Layout not found: " + LAYOUT_PATH)
		quit(1)
		return

	var output_dir := "build/sprint32/captures"
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
	env_res.background_color = Color(0.05, 0.04, 0.03, 1.0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.45, 0.38, 0.28, 1.0)
	env_res.ambient_light_energy = 1.2
	env.environment = env_res
	root.add_child(env)

	# Atmospheric Goa'uld amber lighting
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

		var module := assembly.get_node(str(room_id)) as LevelModule
		if module == null:
			continue

		var cam_world := module.global_transform * cam_local
		var target_world := module.global_transform * target_local

		camera.global_position = cam_world
		camera.look_at(target_world, Vector3.UP)

		# Settle frames for lighting & shaders
		for f in range(8):
			await process_frame

		var img := root.get_viewport().get_texture().get_image()
		var file_path := output_dir + "/" + shot_name + ".png"
		img.save_png(file_path)
		print("Saved capture: " + file_path)

	print("PASS All Sprint 32 captures written to " + output_dir)
	quit(0)
