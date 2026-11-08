extends SceneTree
## Host selects the mission mode; late joins and mission-start transitions receive it.
const TEST_PORT: int = 19781
var host: SGCNetworkManager
var client: SGCNetworkManager
var host_root: Node
var client_root: Node
var host_observed_start: int = -1
var client_observed_start: int = -1

func _init() -> void:
	call_deferred("run_test")

func wait_frames(count: int) -> void:
	for i: int in range(count):
		await process_frame

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run_test() -> void:
	var net: SGCNetworkManager = root.get_node("NetworkManager") as SGCNetworkManager
	if not check(net.mission_difficulty == SGCNetworkManager.DIFFICULTY_EASY, "Default mission must be Easy"):
		return
	var original_connections: int = net.mission_settings_changed.get_connections().size()
	var lobby := load("res://scenes/main/Lobby.tscn").instantiate() as LobbyUI
	root.add_child(lobby)
	await process_frame
	if not check(lobby.difficulty_option_button.item_count == 3, "Lobby needs Easy, Medium, Hard choices"):
		return
	if not check(lobby.difficulty_option_button.get_item_text(0) == "Easy" and lobby.difficulty_option_button.get_item_text(1) == "Medium" and lobby.difficulty_option_button.get_item_text(2) == "Hard", "Modes must have clear menu names"):
		return
	lobby._on_difficulty_selected(1)
	if not check(net.mission_difficulty == 1 and "Lab ROM" in lobby.difficulty_description_label.text, "Medium selection must describe the computer upgrade"):
		return
	lobby._on_difficulty_selected(2)
	if not check(net.mission_difficulty == 2 and "Iris under fire" in lobby.difficulty_description_label.text, "Hard selection must describe the Iris objective"):
		return
	lobby._on_difficulty_selected(0)
	if not check("3 incoming waves" in lobby.difficulty_description_label.text, "Easy cannot promise premature extraction"):
		return
	var parsed: Dictionary = net.parse_cli_arguments(PackedStringArray(["--difficulty", "hard"]))
	if not check(parsed.get("difficulty") == 2 and net.mission_difficulty == 2, "Dedicated/server CLI must accept a difficulty"):
		return
	net.parse_cli_arguments(PackedStringArray(["--difficulty", "invalid"]))
	if not check(net.mission_difficulty == 2, "Invalid CLI mode must leave the selection usable"):
		return
	net.set_mission_difficulty(2)
	await process_frame
	await process_frame
	var viewport: Rect2 = root.get_visible_rect()
	for control: Control in [lobby.difficulty_option_button, lobby.difficulty_description_label, lobby.start_game_button, lobby.class_option_button, lobby.keybindings_button, lobby.host_button, lobby.roster_list]:
		if not check(viewport.encloses(control.get_global_rect()), "Lobby control clips outside 1280x720 viewport: " + str(control.name)):
			return
	if not check(lobby.difficulty_description_label.get_global_rect().end.y <= lobby.roster_list.get_global_rect().position.y, "Difficulty description must not overlap the roster"):
		return
	if not check(net.join_game("127.0.0.1", TEST_PORT + 1) == OK, "Menu client state must initialize"):
		return
	lobby._update_ui_state()
	if not check(lobby.difficulty_option_button.disabled, "Connected client mode selector must be disabled"):
		return
	lobby._on_difficulty_selected(2)
	if not check(net.mission_difficulty == 0, "Client menu callback cannot override host settings"):
		return
	net.disconnect_game()
	if not check(not net.mission_started and net.mission_difficulty == 0 and not lobby.difficulty_option_button.disabled, "Disconnect restores fresh lobby settings"):
		return
	lobby.queue_free()
	await process_frame
	if not check(net.mission_settings_changed.get_connections().size() == original_connections, "Freed Lobby must disconnect its network settings callback"):
		return
	net.mission_settings_changed.emit(0)
	print("PASS lobby modes, objective descriptions and difficulty CLI")

	host_root = Node.new()
	host_root.name = "ModeHost"
	client_root = Node.new()
	client_root.name = "ModeClient"
	root.add_child(host_root)
	root.add_child(client_root)
	var host_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())
	host = SGCNetworkManager.new()
	client = SGCNetworkManager.new()
	host.name = "NetworkManager"
	client.name = "NetworkManager"
	host_root.add_child(host)
	client_root.add_child(client)
	host.game_started.connect(func() -> void: host_observed_start = host.mission_difficulty)
	client.game_started.connect(func() -> void: client_observed_start = client.mission_difficulty)
	if not check(host.set_mission_difficulty(2), "Host must select mode before opening lobby"):
		return
	check(host.set_mission(SGCNetworkManager.MISSION_SGC_UAT), "Host can choose UAT before hosting")
	if not check(host.host_game(TEST_PORT) == OK, "Host must bind mode test port"):
		return
	if not check(client.join_game("127.0.0.1", TEST_PORT) == OK, "Client must join"):
		return
	for i: int in range(600):
		await process_frame
		if client.mission_difficulty == 2 and host.peers.size() >= 2:
			break
	if not check(client.mission_difficulty == 2 and host.peers.size() >= 2, "Joining client must receive selected Hard mode"):
		return
	if not check(not client.set_mission_difficulty(0) and client.mission_difficulty == 2, "Connected client cannot override host mode"):
		return
	if not check(host.set_mission_difficulty(1), "Host must be able to adjust lobby mode"):
		return
	for i: int in range(120):
		await process_frame
		if client.mission_difficulty == 1:
			break
	if not check(client.mission_difficulty == 1, "Host mode changes must replicate to clients"):
		return
	await wait_frames(10)
	check(client.selected_mission_id == SGCNetworkManager.MISSION_SGC_UAT, "Join receives host mission")
	check(not client.set_mission(SGCNetworkManager.MISSION_SGC_DEFENSE), "Clients cannot change mission")
	client.selected_mission_id = SGCNetworkManager.MISSION_SGC_DEFENSE
	# The start RPC carries the mode even if a client's local cached selection is stale.
	client.mission_difficulty = 0
	host.request_start_game()
	for i: int in range(120):
		await process_frame
		if client_observed_start != -1:
			break
	if not check(host_observed_start == 1 and client_observed_start == 1, "Both gameplay scenes must observe the host mode before game_started"):
		return
	check(client.selected_mission_id == SGCNetworkManager.MISSION_SGC_UAT, "Start RPC repairs stale mission selection")
	if not check(not host.set_mission_difficulty(2), "In-progress mode cannot be changed"):
		return
	var restarts: Array[int] = [0, 0]
	host.game_started.connect(func() -> void: restarts[0] += 1)
	client.game_started.connect(func() -> void: restarts[1] += 1)
	if not check(not client.request_restart_game(), "Clients must wait for a host retry"):
		return
	client.mission_difficulty = 0
	client.selected_mission_id = SGCNetworkManager.MISSION_SGC_DEFENSE
	if not check(host.request_restart_game(), "Host must be able to retry the active mission"):
		return
	for i: int in range(120):
		await process_frame
		if restarts[1] == 1:
			break
	if not check(restarts == [1, 1] and client.mission_difficulty == 1, "Host retry reaches both peers once and preserves selected mode"):
		return
	check(client.selected_mission_id == SGCNetworkManager.MISSION_SGC_UAT, "Retry preserves UAT mission")
	client.disconnect_game()
	host.disconnect_game()
	host_root.queue_free()
	client_root.queue_free()
	await process_frame
	print("PASS host authority, join synchronization and mission-start settings")
	quit(0)
