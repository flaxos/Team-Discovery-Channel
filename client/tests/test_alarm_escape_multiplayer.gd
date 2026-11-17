extends "res://tests/test_mission_countdown_multiplayer.gd"
## Reuse the full-team countdown contract, starting each window through a real alarm runner.
var alarm_attempt := 0
var host_room := 0
var host_attempt := 0
var patrols_resumed := false


func port() -> int:
	return 19940 if is_dedicated else 19939


func client_script() -> String:
	return "res://tests/test_alarm_escape_multiplayer.gd"


func mission_id() -> String:
	return SGCNetworkManager.MISSION_ALARM_ESCAPE


func park_hostiles(room: ModularMission) -> void:
	if host_room != room.get_instance_id():
		host_room = room.get_instance_id()
		host_attempt += 1
		patrols_resumed = false
	if exists("raise_%d" % host_attempt) and not room.alert.is_raised() and room.mission_result < 0:
		if not patrols_resumed:
			room.alert.set_physics_process(true)
			for enemy: JaffaAI in room.enemies.get_children():
				enemy.start_patrol(enemy.patrol_points)
				enemy.set_physics_process(true)
			patrols_resumed = true
		for actor: PlayerController3D in room.players_container.get_children():
			actor.health_component.current_health = 1000000.0
	else:
		super.park_hostiles(room)


func use_consoles(room: ModularMission) -> void:
	alarm_attempt += 1
	var actor := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	Fixture.place(actor, room.level.marker(&"checkpoint", &"patrol"))
	mark("raise_%d" % alarm_attempt)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if room.alert.is_raised() and room.events.timer_state == MissionEvents.TimerState.RUNNING:
			break
		await frames(1)
	require(room.alert.is_raised() and room.events.timer_state == MissionEvents.TimerState.RUNNING,
		"The server's runner raises the alarm from a remote operative's sighting")
	require(room.objectives.index == 0, "Alarm starts the clock before either console objective")
	var remaining := room.events.remaining_seconds()
	room.events._on_alert_changed(MissionAlert.Level.ALARM)
	require(room.events.remaining_seconds() <= remaining, "Clients cannot execute the alarm action")
	await super.use_consoles(room)

