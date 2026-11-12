extends SceneTree
## Two Godot processes run the production autoload, lobby start and mission host for the
## compound alert (roadmap EV-1): a listen host raises the alarm, a client joins after the first
## reinforcements arrived, the host retries, the client disables a console through the server,
## and the client sees the next runner's tell.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const PORT := 19876
const Level := MissionAlert.Level
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(1)
		await process_frame


func mark(label: String, text: String = "ok") -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string(text)


func marked(label: String, limit: int = 3600) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--alert-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


## The mission world once started with this peer's operative in it; not `previous`.
func mission(previous: int = 0) -> ModularMission:
	for _i: int in range(3600):
		var room := main.current_gate_room as ModularMission
		if (
			room != null
			and room.get_instance_id() != previous
			and room.is_started
			and room.players_container.has_node(str(net.local_peer_id))
		):
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func entry_of(room: ModularMission) -> Vector3:
	return room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker)


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_index: int = engine_args.find("--log-file")
	var log_dir: String = (
		engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	)
	output_dir = (
		args[args.find("--result-dir") + 1]
		if is_child()
		else log_dir.path_join("alert-" + str(OS.get_process_id()))
	)
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if is_child():
		await run_client()
	else:
		await run_host()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	print("PASS alert client" if is_child() else "PASS two-peer mission alert: late join during an alarm, client console disable, runner tell and retry")
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(MISSION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	var me := room.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0
	# Seen at the checkpoint: the guards run for its console and raise the alarm.
	place(me, room.level.marker(&"checkpoint", &"patrol"))
	for _i: int in range(60 * 40):
		await frames(1)
		if room.alert.is_raised():
			break
	assert(room.alert.is_raised(), "The host raises the alarm")
	place(me, entry_of(room))
	for _i: int in range(60 * 12):
		await frames(1)
		if room.alert.reinforcements_spawned == 2:
			break
	assert(room.alert.reinforcements_spawned == 2, "First reinforcements arrived")

	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_mission_alert_multiplayer.gd",
			"--", "--alert-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0)
	assert(await marked("late"), "The late client sees the alarm")

	var old_room := room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(old_room)
	me = room.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0
	assert(room.alert.alert_level == Level.CALM and room.alert.reinforcements_spawned == 0)
	assert(await marked("disabled"), "The client disables a console")
	assert(room.alert.is_disabled(0), "The server accepted the console in reach")
	assert(not room.alert.is_disabled(1), "The server refused the console out of reach")

	# The next escalation can only use the upper console; the client watches the runner.
	place(me, room.level.marker(&"checkpoint", &"patrol"))
	for _i: int in range(60 * 30):
		await frames(1)
		if room.alert.runner != null:
			break
	assert(room.alert.runner != null and room.alert.runner_console == 1)
	mark("runner", str(room.alert.runner.name))
	place(me, entry_of(room))
	assert(await marked("client_runner"), "The client sees the runner")
	await frames(30)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Late Teal'c"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission()
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	for _i: int in range(2400):
		await frames(1)
		if room.enemies.has_node("Jaffa_R0_1") and room.alert.is_raised():
			break
	await frames(30)
	# The snapshot: alarm raised, consoles dead, the arrived reinforcements, the banner.
	var alert := room.alert
	assert(alert.is_raised() and alert.spotted, "Late join receives the alarm")
	assert(alert.reinforcements_spawned == 2 and room.enemies.has_node("Jaffa_R0_0"))
	for station in alert.consoles:
		assert(station.prompt.text == "ALARM ACTIVE" and not station.is_in_group("interactable"))
	assert(room.hud.enemies_label.text.begins_with("ALARM RAISED"), room.hud.enemies_label.text)
	for enemy in room.enemies.get_children():
		assert(not (enemy as JaffaAI).raising_alarm, "Nobody is running once the alarm is up")
	mark("late")

	var old_room := room.get_instance_id()
	room = await mission(old_room)
	me = room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	alert = room.alert
	for _i: int in range(600):
		await frames(1)
		if room.enemies.get_child_count() == 6:
			break
	assert(alert.alert_level == Level.CALM and not alert.spotted and not alert.disabled.has(true))
	assert(alert.consoles[0].is_in_group("interactable"))
	# Out of reach (the client spawns at the gate): the server refuses.
	alert.consoles[1].interact(me)
	# In reach: the client sends its identity; the server checks reach and disables.
	place(me, alert.console_spot(0))
	for _i: int in range(60):
		await frames(10)
		if alert.is_disabled(0):
			break
		alert.consoles[0].interact(me)
	place(me, entry_of(room))
	assert(alert.is_disabled(0) and alert.consoles[0].prompt.text == "ALARM DISABLED")
	assert(not alert.consoles[0].is_in_group("interactable"))
	await frames(30)
	assert(not alert.is_disabled(1) and alert.consoles[1].prompt.text.ends_with("DISABLE ALARM"))
	mark("disabled")

	assert(await marked("runner"))
	var runner_name := FileAccess.get_file_as_string(output_dir.path_join("runner"))
	for _i: int in range(600):
		await frames(1)
		if alert.runner_name == runner_name:
			break
	var mirror := room.enemies.get_node(runner_name) as JaffaAI
	assert(alert.alert_level == Level.SEARCHING and mirror.raising_alarm)
	for enemy in room.enemies.get_children():
		assert((enemy as JaffaAI).raising_alarm == (enemy == mirror))
	await frames(2)
	assert(mirror._tell.visible and mirror._tell.text == "!!")
	assert(room.hud.enemies_label.text.begins_with("COMPOUND ALERTED"), room.hud.enemies_label.text)
	mark("client_runner")
	await frames(30)
