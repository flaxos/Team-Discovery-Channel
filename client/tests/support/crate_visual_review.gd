extends SceneTree
## AP-1c review captures of the dressed SGC armoury ammo crates, with the original boxes for
## comparison and a render cost line for each. Needs a display (Forward+), not --headless:
##
##   DISPLAY=:0 godot --path client --script res://tests/support/crate_visual_review.gd
##
## Writes build/asset-review/plastic-crate/*.png and prints one CRATE_COST line per state.
## Captures are evidence for owner art review, not acceptance.

const VIEWS: Array[Dictionary] = [
	{"id": "close", "camera": Vector3(44.3, 1.55, 34.6), "target": Vector3(42.0, 0.45, 32.5)},
	{"id": "gameplay", "camera": Vector3(37.0, 1.7, 36.0), "target": Vector3(44.0, 0.7, 36.0)},
	{"id": "wide", "camera": Vector3(49.5, 2.3, 36.0), "target": Vector3(42.0, 0.6, 36.0)},
]


func _init() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func cost(label: String, camera: Camera3D) -> void:
	var view: Dictionary = VIEWS[2]
	camera.position = view.camera
	camera.look_at(view.target)
	for i in range(30):
		await process_frame
	var viewport := root.get_viewport_rid()
	var gpu := 0.0
	var count := 0
	var begun := Time.get_ticks_usec()
	while Time.get_ticks_usec() - begun < 3000000:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		count += 1
	print("CRATE_COST state=%s view=wide frames=%d render_gpu_ms=%.3f primitives=%d draw_calls=%d" % [
		label, count, gpu / count,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	])


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	await (room.get_node("SGCMap") as SGCMap).navigation_ready
	room.set_process(false)
	room.get_node("TacticalHUD").hide()
	for shroud: Node in room.get_node("SectorShrouds").get_children():
		shroud.queue_free()
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.current = true
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var output := ProjectSettings.globalize_path("res://../build/asset-review/plastic-crate")
	DirAccess.make_dir_recursive_absolute(output)
	var stations: Array[ArmoryResupplyStation] = []
	for crate_name: String in ["AmmoCrate1", "AmmoCrate2"]:
		stations.append(room.find_child(crate_name, true, false) as ArmoryResupplyStation)
	for view in VIEWS:
		camera.position = view.camera
		camera.look_at(view.target)
		await capture(output.path_join("dressed-%s.png" % view.id))
	room.sector_shrouds.clear()
	room.set_emergency_lights(true)
	room._process(0.2)
	camera.position = VIEWS[1].camera
	camera.look_at(VIEWS[1].target)
	await capture(output.path_join("dressed-gameplay-alert.png"))
	room.set_emergency_lights(false)
	room._process(0.2)
	await cost("dressed", camera)
	# The original boxes, as drawn before AP-1c.
	for station in stations:
		var box := station.get_node(^".") as CSGBox3D
		station.crate_visual.free()
		box.transparency = 0.0
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for view in VIEWS:
		camera.position = view.camera
		camera.look_at(view.target)
		await capture(output.path_join("original-%s.png" % view.id))
	await cost("original", camera)
	print("Crate review frames: ", output)
	await preload("res://tests/support/finish.gd").success(self)
