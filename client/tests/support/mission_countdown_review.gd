extends "res://tests/test_mission_countdown.gd"
## Render the actual mission HUD; only AI is parked and the expiry fixture is shortened.
var output: String


func shot(label: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func face_console(room: ModularMission) -> void:
	var actor := room.players_container.get_node("1") as PlayerController3D
	actor.camera.global_position = actor.global_position + Vector3(0, 1.6, 0)
	actor.camera.look_at(room.level.marker(&"cmd_command", &"entry") + Vector3(0, 1.6, 0))


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/countdown-review")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_mission_selected(5)
	await shot("1-selected")
	net.request_start_game()
	var room := await mission()
	start_timer(room, 180.0)
	face_console(room)
	await shot("2-countdown")
	room = await retry(room)
	start_timer(room, 2.0)
	face_console(room)
	await shot("3-urgent-fixture")
	await create_timer(2.1).timeout
	assert(room.mission_result == 0)
	await shot("4-expired-fixture")
	net.disconnect_game()
	await frames(3)
	print("PASS countdown rendered review: ", output)
	await preload("res://tests/support/finish.gd").success(self)
