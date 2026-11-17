extends "res://tests/test_mission_countdown.gd"
## Positive starts come from sentry perception and a runner actually working a console.
const ALARM_DEFINITION := "res://resources/missions/goauld_alarm_escape.tres"


func validate_data() -> void:
	var source := load(ALARM_DEFINITION) as MissionDefinition
	assert(source.validate().is_empty(), str(source.validate()))
	assert(source.layout == (load(Fixture.DEFINITION) as MissionDefinition).layout)
	assert(source.triggers[1].condition == "alarm_raised" and source.triggers[1].duration_seconds == 180.0)
	var copy := Fixture.copy_definition(source)
	copy.triggers[1].condition = "invented"
	assert(str(copy.validate()).contains("Unknown mission condition"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].objective_id = &"download_records"
	assert(str(copy.validate()).contains("Alarm trigger cannot also name an objective"))
	copy = Fixture.copy_definition(source)
	copy.alarms = []
	assert(str(copy.validate()).contains("Alarm trigger needs an alarm console"))
	copy = Fixture.copy_definition(source)
	copy.triggers[1].action = "release_door"
	copy.triggers[1].security_id = &"cmd_command"
	assert(str(copy.validate()).contains("Alarm trigger supports start_timer only"))
	assert((load(Fixture.DEFINITION) as MissionDefinition).triggers[1].condition == "objective_completed")
	assert((load("res://resources/missions/goauld_infiltration.tres") as MissionDefinition).triggers[0].condition == "objective_completed")


func resume_patrols(room: ModularMission) -> void:
	room.alert.set_physics_process(true)
	for enemy: JaffaAI in room.enemies.get_children():
		enemy.start_patrol(enemy.patrol_points)
		enemy.set_physics_process(true)


func seen(room: ModularMission) -> void:
	resume_patrols(room)
	Fixture.place(room.players_container.get_node("1") as PlayerController3D, room.level.marker(&"checkpoint", &"patrol"))
	for i in range(1200):
		if room.alert.alert_level == MissionAlert.Level.SEARCHING:
			break
		await frames(1)
	assert(room.alert.alert_level == MissionAlert.Level.SEARCHING, "Real checkpoint sighting begins a search")
	assert(room.events.timer_state == MissionEvents.TimerState.IDLE and not room.hud.mission_countdown_panel.visible,
		"Searching alone starts no deadline")


func alarm(room: ModularMission, seconds: float, expected_progress: int = 0) -> void:
	Fixture.duration(room, seconds)
	await seen(room)
	for i in range(1800):
		if room.alert.is_raised():
			break
		await frames(1)
	assert(room.alert.is_raised(), "A real runner raises the alarm")
	assert(room.events.timer_state == MissionEvents.TimerState.RUNNING and room.objectives.index == expected_progress)
	assert(room.events.fired.has("alarm_starts_extraction_window"))
	assert(room.hud.squad_toast_label.text == room.definition.triggers[1].notice)
	assert(Fixture.door(room).locked == (expected_progress == 0), "Alarm never alters generator security")
	Fixture.stand_down(room)


func records(room: ModularMission) -> void:
	var player := room.players_container.get_node("1") as PlayerController3D
	for index in range(2):
		Fixture.place(player, Fixture.spot(room, index))
		Fixture.station(room, index).interact(player)
		assert(room.objectives.index == index + 1)


func run() -> void:
	validate_data()
	root.size = Vector2i(1280, 720)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	var menu := main.current_lobby as LobbyUI
	menu._on_mission_selected(6)
	assert(net.selected_mission_id == SGCNetworkManager.MISSION_ALARM_ESCAPE)
	assert(menu.start_game_button.text == "LAUNCH ALARM ESCAPE" and not menu.difficulty_option_button.get_parent().visible)
	menu._on_start_game_pressed()
	var room := await mission()
	await alarm(room, 30.0)
	var remaining := room.events.remaining_seconds()
	room.alert.level_changed.emit(MissionAlert.Level.ALARM)
	room.events.start()
	assert(room.events.remaining_seconds() <= remaining and room.events.fired.size() == 1)
	# Host initialization also consumes an alarm that was already raised. Use a private,
	# timer-only director probe against this genuine alarm; it cannot alter the real result.
	var copy := Fixture.copy_definition(room.definition)
	copy.triggers = [copy.triggers[1]]
	var probe := MissionEvents.new()
	room.add_child(probe)
	probe.setup(copy, room.level, room.objectives, room.alert)
	assert(probe.start().is_empty() and probe.timer_state == MissionEvents.TimerState.RUNNING)
	assert(probe.fired.size() == 1)
	probe.stop()
	probe.queue_free()
	remaining = room.events.remaining_seconds()
	records(room)
	assert(room.events.remaining_seconds() <= remaining and room.events.fired.size() == 2)
	Fixture.place(room.players_container.get_node("1") as PlayerController3D, room.objectives.position_of(room.objectives.current()))
	await frames(2)
	assert(room.mission_result == 1 and room.events.timer_state == MissionEvents.TimerState.STOPPED)
	room = await retry(room)
	# Disabling both real consoles prevents a detected squad from starting a deadline.
	var player := room.players_container.get_node("1") as PlayerController3D
	for station: MissionAlarmConsole in room.alert.consoles:
		Fixture.place(player, room.alert.console_spot(station.index))
		station.interact(player)
	assert(not room.alert.disabled.has(false))
	await seen(room)
	await frames(600)
	assert(not room.alert.is_raised() and room.events.timer_state == MissionEvents.TimerState.IDLE)
	Fixture.stand_down(room)
	records(room)
	assert(room.events.timer_state == MissionEvents.TimerState.IDLE, "Records alone do not start this variant's clock")
	Fixture.place(player, room.objectives.position_of(room.objectives.current()))
	await frames(2)
	assert(room.mission_result == 1 and room.events.timer_state == MissionEvents.TimerState.IDLE)
	# Negative control: even a later raised-state signal cannot start events after the result.
	room.alert.sync_state(MissionAlert.Level.ALARM, 3, "", true)
	assert(room.events.timer_state == MissionEvents.TimerState.IDLE and room.events.fired.size() == 1)
	room = await retry(room)
	records(room)
	assert(room.events.timer_state == MissionEvents.TimerState.IDLE)
	await alarm(room, 30.0, 2)
	Fixture.place(room.players_container.get_node("1") as PlayerController3D, room.objectives.position_of(room.objectives.current()))
	await frames(2)
	assert(room.mission_result == 1, "An alarm after records still starts an escapable deadline")
	room = await retry(room)
	await alarm(room, 0.1)
	paused = true
	OS.delay_msec(150)
	await process_frame
	await process_frame
	assert(room.mission_result == 0 and not paused and room.objectives.index == 0)
	assert(room.hud.debrief_subtitle.text == "EXTRACTION WINDOW EXPIRED")
	room = await retry(room)
	assert(room.alert.alert_level == MissionAlert.Level.CALM and not room.alert.disabled.has(true))
	net.disconnect_game()
	await frames(3)
	assert((load(ALARM_DEFINITION) as MissionDefinition).triggers[1].duration_seconds == 180.0)
	print("PASS alarm escape: validation, actual runner before objectives, one-shot, startup alarm, quiet console prevention, victory, pause expiry and fresh retries")
	await preload("res://tests/support/finish.gd").success(self)
