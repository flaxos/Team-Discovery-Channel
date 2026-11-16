extends SceneTree
## Actual mission lighting, on a display with Forward+. Writes build/asset-review/stargate/.


func _init() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mission := args[0] if not args.is_empty() else "sgc_uat"
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	net.selected_mission_id = mission
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await process_frame
	assert(net.host_game(0) == OK)
	net.request_start_game()
	var gate: StargateRing
	for i in range(1800):
		await process_frame
		for world in main.worlds():
			gate = world.find_child("Stargate", true, false) as StargateRing
			if gate != null:
				break
		if gate != null:
			break
	assert(gate != null)
	await create_timer(3.0).timeout
	# Art inspection only: optionally cull other geometry without changing mission lights,
	# gate placement or production scenes. Keep an ordinary view to document SGC occlusion.
	if args.has("--isolate"):
		for node: Node in main.find_children("*", "GeometryInstance3D", true, false):
			if not gate.is_ancestor_of(node):
				(node as GeometryInstance3D).layers = 1 << 19
	for node: Node in main.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).hide()
	root.size = Vector2i(1440, 900)
	var camera := Camera3D.new()
	gate.add_child(camera)
	# Stay inside the gate chamber, behind the SGC catwalk which otherwise occludes it.
	camera.position = Vector3(0.3, 0.1, 3.2)
	camera.fov = 100.0
	camera.cull_mask = 1
	camera.look_at(gate.global_position)
	camera.current = true
	var output := ProjectSettings.globalize_path("res://../build/asset-review/stargate")
	DirAccess.make_dir_recursive_absolute(output)
	var prefix := output.path_join(mission + ("-isolated" if args.has("--isolate") else ""))
	await capture(prefix + "-inactive.png")
	gate.close_wormhole()
	gate.reserve_connection(false)
	for i in range(1, 4):
		gate.lock_chevron(i)
	await capture(prefix + "-dialing.png")
	for i in range(4, 8):
		gate.lock_chevron(i)
	await create_timer(gate.kawoosh_duration_s + 0.2).timeout
	await capture(prefix + "-active.png")
	gate.close_wormhole()
	var visual := gate.get_node_or_null("CommunityVisual")
	if visual != null:
		visual.queue_free()
	(gate.get_node("GateRingMesh") as MeshInstance3D).show()
	for node: Node in gate.chevron_container.get_children():
		var box := node as CSGBox3D
		box.transparency = 0.0
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await capture(prefix + "-original.png")
	print("STARGATE_REVIEW ", prefix)
	main.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)
