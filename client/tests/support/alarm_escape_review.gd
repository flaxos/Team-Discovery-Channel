extends "res://tests/test_alarm_escape.gd"
## The real lobby and alarm runner, with AI parked only after the alarm for HUD captures.
var output: String


func normal_health(room: ModularMission) -> void:
	var health := (room.players_container.get_node("1") as PlayerController3D).health_component
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)


func shot(label: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/alarm-escape-review")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_mission_selected(6)
	await shot("1-selected")
	net.request_start_game()
	var room := await mission()
	await alarm(room, 180.0)
	normal_health(room)
	var actor := room.players_container.get_node("1") as PlayerController3D
	actor.camera_rig.global_position = actor.global_position
	actor._update_camera_and_occlusion(1.0 / 60.0)
	await shot("2-alarm-before-objectives")
	room = await retry(room)
	await alarm(room, 2.0)
	normal_health(room)
	actor = room.players_container.get_node("1") as PlayerController3D
	actor.camera_rig.global_position = actor.global_position
	actor._update_camera_and_occlusion(1.0 / 60.0)
	await create_timer(2.1).timeout
	assert(room.mission_result == 0)
	await shot("3-expired-fixture")
	net.disconnect_game()
	await frames(3)
	print("PASS alarm escape rendered review: ", output)
	await preload("res://tests/support/finish.gd").success(self)
