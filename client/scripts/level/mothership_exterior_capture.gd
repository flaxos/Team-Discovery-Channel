extends SceneTree
## Automated Forward+ GPU captures for Sprint 34 Goa'uld Mothership Exterior Silhouette review.
## Captures:
## 1. 01_mothership_hero_silhouette_full: Full exterior silhouette in space (pyramid, outriggers, thrusters)
## 2. 02_mothership_silhouette_near: Close-up of gold pyramid core, glowing capstone, and turret hardpoint
## 3. 03_bridge_viewport_fleet_vista: Bridge observation viewport framing escort Ha'tak silhouette against nebula
## 4. 04_hangar_bay_space_threshold: Hangar forcefield threshold overlooking the space fleet formation

const SILHOUETTE_SCENE := "res://scenes/props/MothershipExteriorSilhouette.tscn"
const VIEWPORT_SCENE := "res://scenes/props/MothershipViewportFrame.tscn"
const HANGAR_VISTA_SCENE := "res://scenes/props/MothershipHangarVista.tscn"
const LAYOUT_PATH := "res://resources/levels/ai2_goauld_mothership_objective.tres"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var output_dir := "build/sprint34/captures"
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Setup base environment
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.015, 0.02, 0.035, 1.0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.35, 0.30, 0.25, 1.0)
	env_res.ambient_light_energy = 1.0
	env.environment = env_res
	root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.6, -0.7).normalized(), Vector3.UP), Vector3(0, 50, 0))
	sun.light_color = Color(1.0, 0.90, 0.72)
	sun.light_energy = 1.4
	root.add_child(sun)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 70.0
	root.add_child(camera)

	var cam_light := OmniLight3D.new()
	cam_light.omni_range = 35.0
	cam_light.light_color = Color(1.0, 0.92, 0.82)
	cam_light.light_energy = 1.2
	camera.add_child(cam_light)

	# --- Shot 01: Hero full exterior silhouette ---
	var scn_silhouette: PackedScene = load(SILHOUETTE_SCENE)
	var hero_ship := scn_silhouette.instantiate() as Node3D
	root.add_child(hero_ship)

	# Background nebula for shot 01 & 02
	var backdrop_quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(250, 150)
	var qm_mat := StandardMaterial3D.new()
	qm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm_mat.albedo_color = Color(0.015, 0.02, 0.035, 1.0)
	qm.material = qm_mat
	backdrop_quad.mesh = qm
	backdrop_quad.position = Vector3(0, 10, -120)
	root.add_child(backdrop_quad)

	var nebula_quad := MeshInstance3D.new()
	var nm := QuadMesh.new()
	nm.size = Vector2(120, 70)
	var nm_mat := StandardMaterial3D.new()
	nm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm_mat.albedo_color = Color(0.45, 0.20, 0.70, 0.7)
	nm.material = nm_mat
	nebula_quad.mesh = nm
	nebula_quad.position = Vector3(20, 15, -110)
	root.add_child(nebula_quad)

	camera.global_position = Vector3(60.0, 32.0, 75.0)
	camera.look_at(Vector3(0, 6.0, 0), Vector3.UP)

	for f in range(10):
		await process_frame
	save_capture(output_dir, "01_mothership_hero_silhouette_full")

	# --- Shot 02: Close-up of pyramid core, glowing capstone, and turret ---
	camera.global_position = Vector3(18.0, 16.0, -22.0)
	camera.look_at(Vector3(0, 12.0, -3.0), Vector3.UP)

	for f in range(10):
		await process_frame
	save_capture(output_dir, "02_mothership_silhouette_near")

	hero_ship.queue_free()
	backdrop_quad.queue_free()
	nebula_quad.queue_free()
	for f in range(5):
		await process_frame

	# --- Shot 03: Bridge observation viewport framing escort Ha'tak silhouette ---
	var layout: LevelLayout = load(LAYOUT_PATH)
	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)

	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame

	var bridge := assembly.get_node("bridge") as LevelModule
	var cam_local := Vector3(4.0, 1.4, 0.5)
	var target_local := Vector3(4.0, 1.3, -3.4)
	camera.global_position = bridge.global_transform * cam_local
	camera.look_at(bridge.global_transform * target_local, Vector3.UP)

	for f in range(10):
		await process_frame
	save_capture(output_dir, "03_bridge_viewport_fleet_vista")

	assembly.queue_free()
	for f in range(5):
		await process_frame

	# --- Shot 04: Hangar bay space threshold overlooking the fleet formation ---
	var hangar_vista_scn: PackedScene = load(HANGAR_VISTA_SCENE)
	var hangar_vista := hangar_vista_scn.instantiate() as Node3D
	root.add_child(hangar_vista)

	camera.global_position = Vector3(0, 3.2, -10.0)
	camera.look_at(Vector3(0, 4.5, 35.0), Vector3.UP)

	for f in range(10):
		await process_frame
	save_capture(output_dir, "04_hangar_bay_space_threshold")

	hangar_vista.queue_free()

	print("PASS All Sprint 34 captures written to " + output_dir)
	quit(0)


func save_capture(output_dir: String, shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var file_path := output_dir + "/" + shot_name + ".png"
	img.save_png(file_path)
	print("Saved capture: " + file_path)
