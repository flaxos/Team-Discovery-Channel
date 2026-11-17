extends SceneTree
## Controlled native-mission evidence with the production operative camera and movement.
const Fixture = preload("res://tests/support/mission_events_fixture.gd")
var output: String


func _init() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in range(10):
		await physics_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/sprint6-captures")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 1000)
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room: ModularMission
	for i in range(1800):
		await physics_frame
		room = main.current_gate_room as ModularMission
		if room != null and room.is_started:
			break
	assert(room != null and room.is_started)
	Fixture.stand_down(room)
	var barracks := room.level.get_node("barracks") as LevelModule
	var index := 0
	for guard: JaffaAI in room.enemies.get_children():
		guard.global_position = barracks.to_global(Vector3((index % 3) * 0.7 - 0.7, 0.05, floori(index / 3.0) * 0.7))
		index += 1
	var player := room.players_container.get_node("1") as PlayerController3D
	var junction := room.level.get_node("inner") as LevelModule
	player.set_physics_process(false)
	player.health_component.current_health = player.health_component.max_health
	player.global_position = junction.to_global(Vector3(-1, 0.05, 0))
	player.rotation.y = junction.global_rotation.y - PI / 2
	player.switch_slot(2)
	player.tps_zoom_distance = 2.5
	player.camera_rig.global_position = player.global_position
	player._update_camera_and_occlusion(1.0 / 60.0)
	player._process_aim()
	await shot("native_tps")
	player.set_physics_process(true)
	Input.action_press("aim")
	for i in range(30):
		await physics_frame
	var start := player.global_position
	Input.action_press("move_up")
	for i in range(25):
		await physics_frame
	Input.action_release("move_up")
	for i in range(15):
		await physics_frame
	var arrived := player.global_position
	Input.action_release("aim")
	for i in range(30):
		await physics_frame
	player.set_physics_process(false)
	assert(start.distance_to(arrived) > 2.0, "The operative physically walks the themed junction")
	assert(absf(arrived.y - junction.global_position.y) < 0.15, "The original floor still supports the operative")
	await shot("native_tps_after_walk")
	var data := {"start": [start.x, start.y, start.z], "arrived": [arrived.x, arrived.y, arrived.z], "distance_m": start.distance_to(arrived), "viewport": [1440, 1000], "room": "inner", "geometry_hidden": false, "camera": "production TPS before/after; held ADS while walking", "hostiles": "stood down and parked in barracks for controlled visual review"}
	var file := FileAccess.open(output.path_join("native_walk.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	net.disconnect_game()
	for i in range(5):
		await process_frame
	print("PASS native corridor production camera and physical operative walk")
	await preload("res://tests/support/finish.gd").success(self)
