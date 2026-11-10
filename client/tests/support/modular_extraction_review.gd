extends SceneTree
## Graphical walk-through of the modular extraction mission using the real lobby start,
## operative camera and HUD. Operatives are placed between stills; hostiles are live.
## DISPLAY=:0 godot --path client --script res://tests/support/modular_extraction_review.gd
var output: String


func _init() -> void:
	call_deferred("run")


func shot(label: String, settle: int = 45) -> void:
	for i in range(settle):
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/extraction-review")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await shot("0-lobby-default", 10)
	var lobby := main.current_lobby as LobbyUI
	lobby._on_mission_selected(2)
	await shot("1-lobby-selected", 10)
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	for i in range(5):
		await physics_frame
	var room := main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	var player := room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 1000000.0
	await shot("2-insertion")
	var lead := room.enemies.get_node("Jaffa_P1_0") as JaffaAI
	player.global_position = room.level.marker(&"ramp", &"entry") + Vector3(0, 2.2, 0)
	var toward := lead.global_position - player.global_position
	player.rotation.y = atan2(-toward.x, -toward.z)
	await shot("3-upper-deck-contact", 240)
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(false)
	var console := room.level.get_node("command").find_child("MissionInteract", true, false) as Node3D
	player.global_position = room.level.marker(&"command", &"entry") + Vector3(0, 0.05, 0)
	await shot("4-command-room")
	player.global_position = console.global_position + Vector3(0, 0.05, 2.0)
	toward = console.global_position - player.global_position
	player.rotation.y = atan2(-toward.x, -toward.z)
	await shot("4b-console")
	console.interact(player)
	await shot("5-console-done", 20)
	player.global_position = room.level.marker(&"hub", &"entry") + Vector3(0, 0.05, 0)
	await shot("6-extraction-ahead")
	player.global_position = room.level.marker(&"entry", &"entry") + Vector3(0, 0.05, 0)
	await shot("7-result", 30)
	print("Jaffa lead state at contact still: ", lead.current_state)
	quit(0)
