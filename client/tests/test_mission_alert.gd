extends SceneTree
## Compound alert, alarm consoles and reinforcements (roadmap EV-1) on the Goa'uld infiltration
## mission, through the production lobby, mission host, director and sentries. The test places
## the operative and reads state; sentries, runners and reinforcements act on their own.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const Level := MissionAlert.Level
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var alert: MissionAlert
var level: LevelAssembly
var player: PlayerController3D


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func seconds(value: float) -> void:
	await frames(int(value * 60.0))


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func launch(previous: int = 0) -> void:
	for i in range(600):
		var current := main.current_gate_room as ModularMission
		if current != null and current.get_instance_id() != previous:
			room = current
			break
		await frames(1)
	assert(room != null and room.get_instance_id() != previous)
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	alert = room.alert
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 1000000.0


func retry() -> void:
	var old := room.get_instance_id()
	assert(net.request_restart_game())
	await launch(old)


## Waits up to `limit` seconds for `check` to hold.
func until(check: Callable, limit: float) -> bool:
	for i in range(int(limit * 60.0)):
		if check.call():
			return true
		await physics_frame
	return bool(check.call())


func hostiles() -> Array[JaffaAI]:
	var result: Array[JaffaAI] = []
	for enemy in room.enemies.get_children():
		var jaffa := enemy as JaffaAI
		if jaffa != null and jaffa.current_state != JaffaAI.State.DEAD:
			result.append(jaffa)
	return result


func reinforcements() -> int:
	var count := 0
	for enemy in room.enemies.get_children():
		if str(enemy.name).begins_with("Jaffa_R"):
			count += 1
	return count


## Being seen at the guarded checkpoint starts an escalation.
func get_spotted() -> void:
	place(player, level.marker(&"checkpoint", &"patrol"))
	assert(await until(func() -> bool: return alert.alert_level != Level.CALM, 20.0), "Spotted at the checkpoint")


## Out of every sentry's sight: the gate room, where the patrols never look.
func hide() -> void:
	place(player, level.marker(level.layout.entry_instance, level.layout.entry_marker))


func use(station: MissionAlarmConsole) -> void:
	place(player, alert.console_spot(station.index))
	station.interact(player)
	hide()
	await frames(2)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await launch()
	check_definition_rules(room.definition)

	# --- Calm start: two working consoles, nothing raised, the usual banner.
	assert(alert.alert_level == Level.CALM and not alert.spotted and alert.runner == null)
	assert(alert.consoles.size() == 2 and alert.reinforcement_budget() == 4)
	for station in alert.consoles:
		assert(station.is_in_group("interactable") and station.prompt.text.ends_with("DISABLE ALARM"))
		var spot := alert.console_spot(station.index)
		assert(spot.distance_to(alert.console_position(station.index)) < MissionAlarmConsole.REACH)
	await frames(5)
	assert(room.hud.enemies_label.text == "HOSTILE PATROLS ACTIVE: 6 JAFFA", room.hud.enemies_label.text)

	# --- Spotted: an alerted sentry runs for the nearest console and raises the alarm there.
	var levels: Array[int] = []
	alert.level_changed.connect(func(value: int) -> void: levels.append(value))
	await get_spotted()
	assert(alert.spotted and room.hud.enemies_label.text.begins_with("COMPOUND ALERTED"))
	assert(await until(func() -> bool: return alert.runner != null, 5.0), "A runner is chosen")
	var runner := alert.runner
	assert(alert.runner_console == 0, "The checkpoint console is nearest the checkpoint guards")
	assert(runner.raising_alarm and runner.errand != Vector3.INF)
	assert(runner.perception.level == JaffaPerception.Level.ALERTED)
	await frames(2)
	assert(runner._tell.visible and runner._tell.text == "!!")
	assert(await until(func() -> bool: return alert.is_raised(), 20.0), "The runner raises the alarm")
	assert(levels.size() == 2 and levels[0] == Level.SEARCHING and levels[1] == Level.ALARM, str(levels))
	assert(alert.runner == null and not runner.raising_alarm and runner.errand == Vector3.INF)
	assert(room.hud.enemies_label.text.begins_with("ALARM RAISED"))
	# Every sentry now hunts: alerted, or searching where the squad was last seen.
	for jaffa in hostiles():
		assert(jaffa.perception.level == JaffaPerception.Level.ALERTED or jaffa.investigating, str(jaffa.name))
	for station in alert.consoles:
		assert(not station.is_in_group("interactable") and station.prompt.text == "ALARM ACTIVE")
	assert(not alert.disable(1), "A raised alarm cannot be switched off")

	# --- Reinforcements: each group once, after its delay, and never beyond the budget.
	hide()
	assert(reinforcements() == 0)
	assert(await until(func() -> bool: return reinforcements() == 2, 8.0), "First group after 6 s")
	await seconds(2.0)
	assert(reinforcements() == 2, "The second group waits for its own delay")
	assert(await until(func() -> bool: return reinforcements() == 4, 16.0), "Second group after 20 s")
	var second := room.enemies.get_node("Jaffa_R1_0") as JaffaAI
	assert(second.is_shock_guard and second.profile == JaffaAI.Profile.SENTRY)
	var first := room.enemies.get_node("Jaffa_R0_0") as JaffaAI
	assert(first.patrol_points.size() == 2, "Reinforcements sweep between their entry and the last sighting")
	assert(alert._attachment_node(&"barracks", &"squad_01").global_position.distance_to(first.patrol_points[1]) < 2.0)
	await seconds(15.0)
	assert(reinforcements() == 4 and alert.reinforcements_spawned == 4, "Budget reached and kept")
	assert(alert.is_raised(), "The alarm is final")

	# --- Retry: a calm compound with working consoles and no reinforcements.
	await retry()
	assert(alert.alert_level == Level.CALM and not alert.spotted and reinforcements() == 0)
	assert(not alert.disabled.has(true) and hostiles().size() == 6)

	# --- A runner that is stopped, or whose console goes dead, raises nothing.
	await get_spotted()
	assert(await until(func() -> bool: return alert.runner != null, 5.0))
	var stopped := alert.runner
	stopped.health_component.take_damage(99999.0)
	await seconds(0.5)
	assert(alert.runner != stopped and not stopped.raising_alarm, "A dead runner is replaced or dropped")
	assert(not alert.is_raised())
	assert(await until(func() -> bool: return alert.runner != null, 5.0), "Another alerted sentry runs")
	var heading_for := alert.runner_console
	var second_runner := alert.runner
	await use(alert.consoles[heading_for])
	assert(alert.is_disabled(heading_for) and not second_runner.raising_alarm)
	assert(alert.consoles[heading_for].prompt.text == "ALARM DISABLED")
	await use(alert.consoles[1 - heading_for])
	assert(not alert.disabled.has(false))
	await seconds(1.0)
	assert(alert.runner == null)
	await get_spotted()
	await seconds(12.0)
	assert(alert.runner == null and not alert.is_raised(), "No working console: no alarm")
	assert(reinforcements() == 0, "No alarm: no reinforcements")

	# --- The escalation ends once nobody has been alerted or searching for a while.
	hide()
	assert(await until(func() -> bool: return alert.alert_level == Level.CALM, 90.0), "The compound calms down")
	assert(alert.spotted, "Having been spotted is remembered")
	for jaffa in hostiles():
		assert(jaffa.perception.level != JaffaPerception.Level.ALERTED and not jaffa.investigating)
	assert(room.hud.enemies_label.text.begins_with("HOSTILE PATROLS ACTIVE"))

	# --- The debrief records how the squad did.
	room.objectives.sync_state(room.definition.objectives.size())
	await frames(5)
	assert(room.mission_result == 1)
	assert(room.hud.stat_status.text.ends_with("SPOTTED, NO ALARM"), room.hud.stat_status.text)
	assert(not alert.is_physics_processing(), "The director stops at the result")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS mission alert: calm start, runner raises the alarm, reinforcement budget, retry, stopped runner, disabled consoles, calm-down and debrief")
	await preload("res://tests/support/finish.gd").success(self)


func check_definition_rules(definition: MissionDefinition) -> void:
	assert(definition.validate().is_empty(), str(definition.validate()))
	var probe := MissionDefinition.new()
	probe.layout = definition.layout
	probe.objectives = definition.objectives
	probe.reinforcements = definition.reinforcements
	assert("Reinforcements need at least one alarm console" in probe.validate())
	var unknown := MissionAlarm.new()
	unknown.room = &"nowhere"
	var on_objective := MissionAlarm.new()
	on_objective.room = &"generator"
	var twice := MissionAlarm.new()
	twice.room = &"checkpoint"
	var again := MissionAlarm.new()
	again.room = &"checkpoint"
	probe.alarms = [unknown, on_objective, twice, again]
	var errors := probe.validate()
	assert("Unknown alarm console: nowhere/console" in errors, str(errors))
	assert("Alarm console is also an objective: generator/console" in errors, str(errors))
	assert("Duplicate alarm console: checkpoint/console" in errors, str(errors))
	var nowhere := MissionReinforcement.new()
	nowhere.room = &"barracks"
	nowhere.attachment = &"no_such_spawn"
	probe.reinforcements = [nowhere]
	assert("Unknown reinforcement point: barracks/no_such_spawn" in probe.validate())
