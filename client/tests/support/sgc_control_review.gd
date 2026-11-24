extends SceneTree
## Capture the live SGC console, gate rim, horizon and manual iris repair.


func _init() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var base := ProjectSettings.globalize_path("res://../build/asset-review/sprint14")
	DirAccess.make_dir_recursive_absolute(base)
	assert(root.get_texture().get_image().save_png(base.path_join(name + ".png")) == OK)


func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(1440, 900)
	var room := preload("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	room.set_process(false)
	room.hud.hide()
	room.sector_shrouds.clear()
	for shroud: Node3D in room.get_node("SectorShrouds").get_children():
		shroud.hide()
	var waves := room.get_node("WaveManager") as WaveManager
	waves.set_physics_process(false)
	waves.set_difficulty(WaveManager.DifficultyTier.EASY)
	waves.completed_incursions = waves.target_activations
	var dialer := room.dhd_console as SGCDialingConsole
	var cam := Camera3D.new()
	cam.fov = 52
	room.add_child(cam)
	cam.position = Vector3(0.5, 3.2, 16.85)
	cam.look_at(Vector3(0, 2.7, 10.6))
	cam.make_current()
	await capture("control-standby")

	var actor := preload("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	actor.name = "1"
	room.players_container.add_child(actor)
	actor.set_physics_process(false)
	actor.position = dialer.global_position + Vector3(1.55, 0, 1.05)
	actor.hide()
	cam.make_current()
	dialer.start_dialing(actor)
	for i in range(3):
		dialer.input_glyph(dialer.chevron_sequence[i])
	assert((dialer.get_node("CRTScreenCenter/StatusReadout") as Label3D).text == "CHEVRONS 3/7")
	await capture("control-dialing")
	dialer.cancel_dialing()
	await capture("control-cancelled")
	room.toggle_control_window()
	await create_timer(1.28).timeout
	await capture("control-shutter")
	room.toggle_control_window()
	await create_timer(1.28).timeout

	var gate := room.stargate_mesh
	var iris := gate.get_node("SGCGateTrim/IrisFace") as MeshInstance3D
	var servo := room.get_node("IrisServoHousing") as IrisServoHousing
	cam.position = Vector3(1.7, 4.15, -6)
	cam.look_at(Vector3(-1.25, 4.1, -14.6))
	await capture("gate-rim")
	assert(gate.reserve_connection(true))
	servo.reset_for_breach()
	for i in range(1, 8):
		gate.lock_chevron(i)
	var deadline := Time.get_ticks_msec() + 12000
	while gate.current_state != StargateRing.GateState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(gate.current_state == StargateRing.GateState.ACTIVE and not iris.visible)
	await capture("iris-jammed")
	actor.global_position = servo.global_position + Vector3(0, 0, 1.5)
	servo.start_repair(actor)
	for i in range(3):
		servo.update_repair(2.6)
	await process_frame
	await process_frame
	assert(iris.visible and gate.event_horizon_mesh.visible)
	await capture("iris-secured")
	cam.position = servo.global_position + Vector3(0.8, 1.5, 2.4)
	cam.look_at(servo.global_position + Vector3(0, 0.72, 0))
	await capture("iris-drive")
	gate.close_wormhole()
	actor.collision_layer = 0
	await physics_frame
	await physics_frame
	actor.queue_free()
	await process_frame
	print("Captured control, gate rim, jammed inbound and secured inbound")
	await preload("res://tests/support/finish.gd").success(self)
