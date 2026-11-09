extends SceneTree


## DISPLAY=:0 godot --path client --script res://tests/support/sgc_visual_review.gd
func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	room.set_process(false)
	room.get_node("TacticalHUD").hide()
	for shroud: Node in room.get_node("SectorShrouds").get_children():
		shroud.queue_free()
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.current = true
	root.size = Vector2i(1440, 900)
	var output := ProjectSettings.globalize_path("res://../build/sgc-review")
	DirAccess.make_dir_recursive_absolute(output)
	var views: Array[Dictionary] = [
		{"id": "embarkation", "camera": Vector3(6, 2.0, -12), "target": Vector3(0, 5.0, 8)},
		{"id": "control", "camera": Vector3(0, 3.1, 13), "target": Vector3(0, 4.3, -15)},
		{"id": "briefing", "camera": Vector3(1, 8.5, 20), "target": Vector3(-1, 6.7, 11)},
		{"id": "spiral", "camera": Vector3(-1, 8.8, 16), "target": Vector3(-4.5, 3.5, 11)},
		{"id": "corridor", "camera": Vector3(23, 2.3, 5), "target": Vector3(23, 1.4, 18)},
		{"id": "support", "camera": Vector3(17, 13.5, 23), "target": Vector3(12, 12.2, 15)}
	]
	for view in views:
		camera.position = view.camera
		camera.look_at(view.target)
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.id + ".png"))
	room.toggle_control_window()
	room.toggle_observation_shutters(true)
	for i in range(90):
		await physics_frame
	camera.position = Vector3(6, 2.0, -12)
	camera.look_at(Vector3(0, 5.0, 8))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("shutters-closed.png"))
	room.toggle_control_window()
	room.toggle_observation_shutters(false)
	for i in range(90):
		await physics_frame
	room.sector_shrouds.clear()
	room.set_emergency_lights(true)
	room._process(0.2)
	camera.position = Vector3(1, 8.5, 20)
	camera.look_at(Vector3(-1, 6.7, 11))
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("briefing-alert.png"))
	room.set_emergency_lights(false)
	room.stargate_mesh.sync_gate_snapshot(
		StargateRing.GateState.ACTIVE, StargateRing.GateDirection.INBOUND, 7, false
	)
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("briefing-gate-active.png"))
	print("Visual review frames: ", output)
	await preload("res://tests/support/finish.gd").success(self)
