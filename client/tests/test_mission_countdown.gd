extends SceneTree
const Fixture = preload("res://tests/support/mission_countdown_fixture.gd")
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func validate_data() -> void:
	var source := load(Fixture.DEFINITION) as MissionDefinition
	assert(source.validate().is_empty(), str(source.validate()))
	assert(source.triggers[1].duration_seconds == 180.0)
	var ordinary := load("res://resources/missions/goauld_infiltration.tres") as MissionDefinition
	assert(source.layout == ordinary.layout, "Reuse the exact existing native layout")
	assert(ordinary.triggers.size() == 1 and ordinary.triggers[0].action == "release_door")
	for seconds: float in [0.0, -1.0, NAN, INF, 86401.0]:
		var copy := Fixture.copy_definition(source)
		copy.triggers[1].duration_seconds = seconds
		assert(str(copy.validate()).contains("Timer duration"))
	var copy := Fixture.copy_definition(source)
	copy.triggers[1].timer_label = " "
	assert(str(copy.validate()).contains("Timer needs a label"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].security_id = &"cmd_command"
	assert(str(copy.validate()).contains("Timer cannot also target"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].action = "invented"
	assert(str(copy.validate()).contains("Unknown mission action"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].objective_id = &"extract"
	assert(str(copy.validate()).contains("precede extraction"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].objective_id = &"missing"
	assert(str(copy.validate()).contains("Unknown trigger objective"))
	copy = Fixture.copy_definition(source)
	var extra := copy.triggers[1].duplicate() as MissionTrigger
	extra.id = &"second_timer"
	copy.triggers.append(extra)
	assert(str(copy.validate()).contains("one extraction timer"))
	assert(source.validate().is_empty() and source.triggers[1].duration_seconds == 180.0)


func mission(previous: int = 0) -> ModularMission:
	for i in range(600):
		var room := main.current_gate_room as ModularMission
		if room != null and room.get_instance_id() != previous and room.is_started:
			assert(room.setup_errors.is_empty(), str(room.setup_errors))
			Fixture.stand_down(room)
			var actor := room.players_container.get_node("1") as PlayerController3D
			actor.set_physics_process(false)
			assert(room.events.timer_state == MissionEvents.TimerState.IDLE)
			assert(not room.hud.mission_countdown_panel.visible)
			assert(room.events.fired.is_empty() and Fixture.door(room).locked)
			return room
		await frames(1)
	assert(false, "Timed mission failed to start")
	return null


func start_timer(room: ModularMission, seconds: float) -> void:
	Fixture.duration(room, seconds)
	var actor := room.players_container.get_node("1") as PlayerController3D
	for index in range(2):
		Fixture.place(actor, Fixture.spot(room, index))
		Fixture.station(room, index).interact(actor)
		assert(room.objectives.index == index + 1)
		if index == 0:
			assert(room.events.timer_state == MissionEvents.TimerState.IDLE and not Fixture.door(room).locked)
	assert(room.events.timer_state == MissionEvents.TimerState.RUNNING)
	assert(room.events.fired.size() == 2 and room.hud.mission_countdown_panel.visible)
	assert(room.hud.mission_countdown_label.text.begins_with("EXTRACTION\n"))
	var remaining := room.events.remaining_seconds()
	Fixture.station(room, 1).interact(actor)
	room.events._on_objective_changed(room.objectives.index)
	assert(room.events.remaining_seconds() <= remaining, "Repeated interactions cannot extend the window")


func retry(room: ModularMission) -> ModularMission:
	var previous := room.get_instance_id()
	assert(net.request_restart_game())
	return await mission(previous)


func run() -> void:
	validate_data()
	root.size = Vector2i(1280, 720)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_TIMED_EXTRACTION))
	net.request_start_game()
	var room := await mission()
	start_timer(room, 1.0)
	await frames(2)
	assert(not room.hud.mission_countdown_panel.get_global_rect().intersects(room.hud.get_node("TopBanner").get_global_rect()))
	assert(not room.hud.squad_toast_panel.get_global_rect().intersects(room.hud.get_node("TopBanner").get_global_rect()),
		"Toast %s, banner %s, viewport %s" % [room.hud.squad_toast_panel.get_global_rect(), room.hud.get_node("TopBanner").get_global_rect(), root.size])
	# The pause menu cannot extend a real-time deadline. MissionEvents always processes.
	paused = true
	OS.delay_msec(1050)
	await process_frame
	await process_frame
	assert(room.mission_result == 0 and not paused)
	assert(room.events.timer_state == MissionEvents.TimerState.EXPIRED)
	assert(not room.hud.mission_countdown_panel.visible and room.hud.is_mission_ended)
	assert(room.hud.debrief_subtitle.text == "EXTRACTION WINDOW EXPIRED")
	assert((room.players_container.get_node("1") as PlayerController3D).health_component.frozen)
	room.conclude(true)
	assert(room.mission_result == 0, "Timeout is final")
	room = await retry(room)
	# The objective admission guard wins even when the timer's own process has not run.
	start_timer(room, 0.1)
	room.events.set_process(false)
	OS.delay_msec(150)
	Fixture.place(room.players_container.get_node("1") as PlayerController3D, room.objectives.position_of(room.objectives.current()))
	room.objectives._physics_process(0.0)
	assert(room.mission_result == 0 and room.objectives.index == 2, "No extraction at/after the deadline")
	room = await retry(room)
	start_timer(room, 1.0)
	Fixture.place(room.players_container.get_node("1") as PlayerController3D, room.objectives.position_of(room.objectives.current()))
	await frames(2)
	assert(room.mission_result == 1 and room.events.timer_state == MissionEvents.TimerState.STOPPED)
	OS.delay_msec(1050)
	await frames(2)
	assert(room.mission_result == 1 and not room.hud.mission_countdown_panel.visible)
	room = await retry(room)
	start_timer(room, 0.1)
	room.hud._on_return_pressed()
	OS.delay_msec(150)
	await frames(3)
	assert(main.current_lobby != null and main.worlds().is_empty() and not net.is_in_active_session())
	assert((load(Fixture.DEFINITION) as MissionDefinition).triggers[1].duration_seconds == 180.0)
	print("PASS countdown: authored validation, real consoles, one-shot, pause expiry, deadline admission, success, retries and live return")
	await preload("res://tests/support/finish.gd").success(self)
