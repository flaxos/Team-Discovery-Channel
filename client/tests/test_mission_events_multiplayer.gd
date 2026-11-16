extends SceneTree
## Real ENet peer: late join after a release, retry while connected, forged/out-of-reach
## interaction rejection, earned client console release and a second fresh retry.
const Fixture = preload("res://tests/support/mission_events_fixture.gd")
const PORT := 19931
var dedicated_host := false
var child_pid := -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func dedicated() -> bool:
	return false


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func frames(count: int) -> void:
	for i in range(count):
		OS.delay_msec(1)
		await process_frame


func child() -> bool:
	return OS.get_cmdline_user_args().has("--events-child")


func mark(name: String) -> void:
	FileAccess.open(output_dir.path_join(name), FileAccess.WRITE).store_string("ok")


func marked(name: String) -> bool:
	for i in range(3600):
		if FileAccess.file_exists(output_dir.path_join(name)):
			return true
		await frames(1)
	if not child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func mission(previous: int = 0) -> ModularMission:
	for i in range(3600):
		var room := main.current_gate_room as ModularMission
		var has_actor := dedicated_host or room != null and room.players_container.has_node(str(net.local_peer_id))
		if room != null and room.get_instance_id() != previous and room.is_started and has_actor:
			assert(room.setup_errors.is_empty(), str(room.setup_errors))
			assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
			if not child():
				Fixture.stand_down(room)
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func use_generator(room: ModularMission, actor: PlayerController3D) -> void:
	Fixture.place(actor, Fixture.console_spot(room))
	for i in range(120):
		Fixture.console(room).interact(actor)
		await frames(5)
		if room.objectives.index == 1 and room.events.fired.has(Fixture.ID) and not Fixture.door(room).locked:
			return
	assert(false, "Generator interaction did not release security")


func fresh_snapshot(room: ModularMission) -> void:
	# Each peer finishes navigation independently. A client can be ready before the
	# host applies mission locks; wait for the authoritative initialized snapshot.
	for i in range(1800):
		if room.events.fired.is_empty() and room.objectives.index == 0 and Fixture.door(room).locked:
			return
		await frames(1)
	assert(false, "Retry snapshot fired=%s index=%d locked=%s" %
		[room.events.fired, room.objectives.index, Fixture.door(room).locked])


func run() -> void:
	dedicated_host = dedicated()
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_index := engine_args.find("--log-file")
	var log_dir := engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	output_dir = args[args.find("--result-dir") + 1] if child() else log_dir.path_join("events-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	if child():
		await run_client()
	else:
		await run_host()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS mission events client" if child() else "PASS mission events multiplayer: late join, authority, real client console and two retries (dedicated=%s)" % dedicated_host)
	await preload("res://tests/support/finish.gd").success(self)


func run_host() -> void:
	net.is_dedicated_server = dedicated_host
	assert(net.host_game(PORT) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	assert(Fixture.door(room).locked and room.events.fired.is_empty())
	if dedicated_host:
		assert(room.players_container.get_child_count() == 0, "Dedicated host has no operative")
		# Establish the completed-objective late-join fixture on the host controller.
		# After retry, the remote operative earns the release through the real console.
		assert(room.objectives.complete_interaction(room.definition.objectives[0]))
	else:
		await use_generator(room, room.players_container.get_node("1") as PlayerController3D)
	assert(room.events.fired.size() == 1 and not Fixture.door(room).locked)
	child_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output_dir.path_join("client.log"), "--script", "res://tests/test_mission_events_multiplayer.gd",
		"--", "--events-child", "--result-dir", output_dir
	])
	assert(child_pid > 0)
	assert(await marked("late"), "Late peer receives the released door and trigger snapshot")
	var previous := room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(previous)
	assert(Fixture.door(room).locked and room.events.fired.is_empty())
	assert(await marked("rejected"))
	assert(room.objectives.index == 0 and room.events.fired.is_empty() and Fixture.door(room).locked,
		"Client cannot impersonate another operative or bypass reach/host authority")
	mark("use_console")
	assert(await marked("released"))
	assert(room.objectives.index == 1 and room.events.fired.size() == 1 and not Fixture.door(room).locked)
	previous = room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(previous)
	assert(room.objectives.index == 0 and room.events.fired.is_empty() and Fixture.door(room).locked)
	assert(await marked("reset"))
	await frames(20)
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	assert(await marked("disconnected"))
	await frames(30)
	var log := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not log.contains("ERROR:") and not log.contains("ObjectDB"), log)


func run_client() -> void:
	net.player_name = "Event Carter"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK)
	var room := await mission()
	for i in range(1800):
		await frames(1)
		if room.events.fired.has(Fixture.ID) and not Fixture.door(room).locked and room.objectives.index == 1:
			break
	assert(room.events.fired.has(Fixture.ID) and not Fixture.door(room).locked)
	assert(room.hud.squad_toast_label.text != room.definition.triggers[0].notice,
		"Snapshot does not replay a stale event notice")
	room.events.sync_fired(PackedStringArray())
	assert(room.events.fired.has(Fixture.ID), "An older snapshot cannot undo a live release")
	mark("late")
	var previous := room.get_instance_id()
	room = await mission(previous)
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	var station := Fixture.console(room)
	await fresh_snapshot(room)
	room.events._on_objective_changed(1)
	assert(not room.objectives.complete_interaction(room.definition.objectives[0]))
	assert(not Fixture.door(room).set_locked(false))
	station.interact(me)  # Own operative, out of reach.
	var other := room.players_container.get_node_or_null("1")
	station.request_interact.rpc_id(1, station.get_path_to(other if other != null else room.players_container))
	await frames(60)
	assert(room.events.fired.is_empty() and room.objectives.index == 0 and Fixture.door(room).locked,
		"Retry snapshot fired=%s index=%d locked=%s" % [room.events.fired, room.objectives.index, Fixture.door(room).locked])
	mark("rejected")
	assert(await marked("use_console"))
	await use_generator(room, me)
	assert(room.hud.squad_toast_label.text == room.definition.triggers[0].notice)
	mark("released")
	previous = room.get_instance_id()
	room = await mission(previous)
	await fresh_snapshot(room)
	mark("reset")
	for i in range(1800):
		if not net.is_in_active_session():
			break
		await frames(1)
	mark("disconnected")
