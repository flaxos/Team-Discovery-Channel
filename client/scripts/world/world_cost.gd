extends SceneTree
## Frame cost of a mission on this machine, to compare one world with two (roadmap GT-1).
## Needs a graphical display (not --headless); it opens the game window for a few seconds:
##
##   godot --path client --script res://scripts/world/world_cost.gd -- --mission sgc_uat
##   godot --path client --script res://scripts/world/world_cost.gd -- --mission two_worlds_dev
##
## Optional: --seconds 10. It hosts the mission through the production coordinator, waits for
## it to settle, turns vertical sync off and prints one WORLD_COST line. Frames per second is
## then the machine's real throughput; the host is the only operative and stands still.
## `objects_drawn` rising far above a mission's usual figure means shadows are being redrawn
## every frame (see MissionSession._settle_shadows).


func _init() -> void:
	call_deferred("run")


func option(name: String, fallback: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(name)
	return arguments[index + 1] if index >= 0 and index + 1 < arguments.size() else fallback


func run() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var mission := option("--mission", SGCNetworkManager.MISSION_SGC_UAT)
	var seconds := float(option("--seconds", "10"))
	if not SGCNetworkManager.MISSIONS.has(mission):
		push_error("Unknown mission: " + mission)
		quit(1)
		return
	net.selected_mission_id = mission
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await process_frame
	if net.host_game(0) != OK:
		quit(1)
		return
	net.request_start_game()
	for i in range(1800):
		await process_frame
		var started := true
		for world in main.worlds():
			if world.get("is_started") == false:
				started = false
		if not main.worlds().is_empty() and started:
			break
	# Let spawning, navigation and shader compilation finish before measuring.
	await create_timer(4.0).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await create_timer(1.0).timeout
	var render_cpu := 0.0
	var render_gpu := 0.0
	var count := 0
	var begun := Time.get_ticks_usec()
	while Time.get_ticks_usec() - begun < int(seconds * 1000000.0):
		await process_frame
		count += 1
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var elapsed := float(Time.get_ticks_usec() - begun) / 1000000.0
	print("WORLD_COST mission=%s worlds=%d fps=%.1f frame_ms=%.2f render_cpu_ms=%.2f render_gpu_ms=%.2f objects_drawn=%d nodes=%d" % [
		mission, main.worlds().size(), count / elapsed, elapsed / count * 1000.0,
		render_cpu / count, render_gpu / count,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	])
	quit(0)
