class_name MissionAlert
extends Node
## Host-owned alert state for a modular mission (roadmap EV-1). One level for the compound:
##
## - CALM: no sentry is alerted or searching.
## - SEARCHING: a sentry is alerted. The alerted sentry nearest a working alarm console runs to
##   it. Returns to CALM once nobody has been alerted or searching for CALM_DELAY seconds and
##   nobody is running for a console. A sentry only checking something it noticed does not
##   start an escalation, but keeps one going.
## - ALARM: a runner worked a console for its `raise_time`. Final for the mission: the klaxon
##   sounds, every sentry converges on the last known position and the reinforcement groups
##   arrive once each, after their delays.
##
## Operatives can disable consoles before the alarm; with every console disabled the alarm
## cannot be raised. Clients receive the state and a snapshot on joining.
signal level_changed(level: int)
signal runner_changed(runner_name: String)
signal console_disabled(index: int)
enum Level { CALM, SEARCHING, ALARM }
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
const SHOCK_JAFFA := "res://scenes/entities/JaffaShockGuard.tscn"
## Seconds between server evaluations.
const INTERVAL := 0.2
const CALM_DELAY := 8.0
## A runner this close (horizontally) to its console's standing spot is working the console.
const CONSOLE_REACH := 1.2
const KLAXON_PERIOD := 4.0

var definition: MissionDefinition
var level: LevelAssembly
var enemies: Node3D
var alert_level: Level = Level.CALM
## True once the level has left CALM at least once this mission.
var spotted := false
## One flag per `definition.alarms` entry.
var disabled: Array[bool] = []
var consoles: Array[MissionAlarmConsole] = []
## Server: the Jaffa running for a console, the console's index and seconds worked so far.
var runner: JaffaAI
var runner_console := -1
var raise_progress := 0.0
## Replicated name of the runner, for the overhead tell on every peer.
var runner_name := ""
var last_known := Vector3.INF
## Reinforcements that have arrived, counted on every peer.
var reinforcements_spawned := 0
## Seconds until each reinforcement group arrives; negative when not scheduled or arrived.
var _arrivals: Array[float] = []
var _clock := 0.0
var _quiet := 0.0
var _klaxon := 0.0


func setup(mission: MissionDefinition, assembly: LevelAssembly, hostiles: Node3D) -> void:
	definition = mission
	level = assembly
	enemies = hostiles
	for i in range(definition.alarms.size()):
		disabled.append(false)
		var node := _attachment_node(definition.alarms[i].room, definition.alarms[i].attachment)
		if node == null:
			continue  # Reported by MissionDefinition.validate().
		var station := MissionAlarmConsole.new()
		station.name = "AlarmInteract"
		station.alert = self
		station.index = i
		node.add_child(station)
		consoles.append(station)
	for _group in definition.reinforcements:
		_arrivals.append(-1.0)
	enemies.child_entered_tree.connect(_on_hostile_entered)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func is_raised() -> bool:
	return alert_level == Level.ALARM


func is_disabled(index: int) -> bool:
	return index >= 0 and index < disabled.size() and disabled[index]


func reinforcement_budget() -> int:
	var total := 0
	for group in definition.reinforcements:
		total += group.count
	return total


## Where a Jaffa stands to work console `index`: the attachment's approach point on the floor.
func console_spot(index: int) -> Vector3:
	var alarm := definition.alarms[index]
	var node := _attachment_node(alarm.room, alarm.attachment)
	var attachment := definition.room_attachment(alarm.room, alarm.attachment)
	var spot := node.global_transform * attachment.approach
	return NavigationServer3D.map_get_closest_point(level.navigation_map, spot)


func console_position(index: int) -> Vector3:
	var alarm := definition.alarms[index]
	return _attachment_node(alarm.room, alarm.attachment).global_position


## Server: an operative disabled console `index`. Not possible once the alarm is raised.
func disable(index: int) -> bool:
	if not multiplayer.is_server() or is_raised() or index < 0 or index >= disabled.size():
		return false
	if disabled[index]:
		return false
	if runner_console == index:
		_release_runner()
	_publish(alert_level, 1 << index)
	return true


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	if is_raised():
		_klaxon -= delta
		if _klaxon <= 0.0:
			_klaxon = KLAXON_PERIOD
			_play_klaxon()
	if not multiplayer.is_server():
		return
	_clock += delta
	if _clock < INTERVAL:
		return
	var dt := _clock
	_clock = 0.0
	_evaluate(dt)
	_reinforce(dt)


func _evaluate(dt: float) -> void:
	var hot: Array[JaffaAI] = []
	var busy := false
	for jaffa in _sentries():
		if jaffa.perception.level == JaffaPerception.Level.ALERTED:
			hot.append(jaffa)
			busy = true
			if is_instance_valid(jaffa.perception.target):
				last_known = jaffa.perception.target.global_position
			elif last_known == Vector3.INF and jaffa.perception.stimulus != Vector3.INF:
				last_known = jaffa.perception.stimulus
		elif jaffa.investigating:
			busy = true
	if alert_level == Level.CALM and not hot.is_empty():
		_quiet = 0.0
		_publish(Level.SEARCHING)
	elif alert_level == Level.SEARCHING:
		if busy or runner != null:
			_quiet = 0.0
		else:
			_quiet += dt
			if _quiet >= CALM_DELAY:
				last_known = Vector3.INF
				_publish(Level.CALM)
				return
		_update_runner(hot, dt)


func _update_runner(hot: Array[JaffaAI], dt: float) -> void:
	if runner != null and (not _can_run(runner) or is_disabled(runner_console)):
		_release_runner()
	if runner == null:
		_pick_runner(hot)
		return
	var offset := runner.global_position - console_spot(runner_console)
	if Vector2(offset.x, offset.z).length() > CONSOLE_REACH or absf(offset.y) > 1.5:
		raise_progress = 0.0
		return
	raise_progress += dt
	if raise_progress >= definition.alarms[runner_console].raise_time:
		_raise_alarm()


## The alerted sentry with the shortest walk to a working console it can reach.
func _pick_runner(hot: Array[JaffaAI]) -> void:
	var best_length := INF
	for jaffa in hot:
		if not _can_run(jaffa):
			continue
		for i in range(definition.alarms.size()):
			if disabled[i] or _attachment_node(definition.alarms[i].room, definition.alarms[i].attachment) == null:
				continue
			var spot := console_spot(i)
			var path := level.local_path(jaffa.global_position, spot)
			if path.is_empty() or path[-1].distance_to(spot) > 1.0:
				continue
			var length := 0.0
			for p in range(1, path.size()):
				length += path[p - 1].distance_to(path[p])
			if length < best_length:
				best_length = length
				runner = jaffa
				runner_console = i
	if runner != null:
		raise_progress = 0.0
		runner.run_to(console_spot(runner_console), console_position(runner_console))
		_publish()


func _release_runner() -> void:
	if is_instance_valid(runner):
		runner.end_run()
	runner = null
	runner_console = -1
	raise_progress = 0.0
	_publish()


func _can_run(jaffa: JaffaAI) -> bool:
	return (
		is_instance_valid(jaffa)
		and jaffa.is_inside_tree()
		and jaffa.is_physics_processing()
		and jaffa.current_state not in [JaffaAI.State.DEAD, JaffaAI.State.STUNNED, JaffaAI.State.DOWNED]
		and not jaffa.health_component.is_dead
	)


func _raise_alarm() -> void:
	var at := last_known if last_known != Vector3.INF else runner.global_position
	_release_runner()
	for i in range(_arrivals.size()):
		_arrivals[i] = definition.reinforcements[i].delay
	for jaffa in _sentries():
		jaffa.investigate_at(at)
	_publish(Level.ALARM)


func _reinforce(dt: float) -> void:
	for i in range(_arrivals.size()):
		if _arrivals[i] < 0.0:
			continue
		_arrivals[i] -= dt
		if _arrivals[i] <= 0.0:
			_arrivals[i] = -1.0
			_spawn_group(i)


func _spawn_group(index: int) -> void:
	var group := definition.reinforcements[index]
	var node := _attachment_node(group.room, group.attachment)
	if node == null:
		return
	var map := level.navigation_map
	var target := last_known if last_known != Vector3.INF else node.global_position
	target = NavigationServer3D.map_get_closest_point(map, target)
	for n in range(group.count):
		var jaffa := load(SHOCK_JAFFA if group.shock_guard else JAFFA).instantiate() as JaffaAI
		jaffa.name = "Jaffa_R%d_%d" % [index, n]
		jaffa.formation_rank = n
		var spot := NavigationServer3D.map_get_closest_point(
			map, node.global_position + node.global_basis.x * (1.2 * n - 0.6 * (group.count - 1))
		)
		jaffa.position = enemies.to_local(spot)
		jaffa.position.y += 0.05
		enemies.add_child(jaffa, true)
		# They sweep between where they came in and where the squad was last seen.
		var route: Array[Vector3] = [target, spot]
		jaffa.start_patrol(route)
		jaffa.investigate_at(target)


## Every peer: count arriving reinforcements, and mark a runner whose replica arrives late.
func _on_hostile_entered(node: Node) -> void:
	var jaffa := node as JaffaAI
	if jaffa == null:
		return
	if str(jaffa.name).begins_with("Jaffa_R"):
		reinforcements_spawned += 1
	jaffa.raising_alarm = runner_name != "" and str(jaffa.name) == runner_name


func _sentries() -> Array[JaffaAI]:
	var result: Array[JaffaAI] = []
	for child in enemies.get_children():
		var jaffa := child as JaffaAI
		if (
			jaffa != null
			and jaffa.profile == JaffaAI.Profile.SENTRY
			and jaffa.perception != null
			and jaffa.current_state != JaffaAI.State.DEAD
		):
			result.append(jaffa)
	return result


func _attachment_node(room: StringName, id: StringName) -> Node3D:
	var attachment := definition.room_attachment(room, id)
	var module := level.get_node_or_null(str(room))
	if attachment == null or module == null:
		return null
	return module.get_node_or_null(LevelRoomComposer.node_path(attachment)) as Node3D


func _mask() -> int:
	var mask := 0
	for i in range(disabled.size()):
		if disabled[i]:
			mask |= 1 << i
	return mask


## Server: send the new state to every peer, itself included. State changes only through
## sync_state, so the server and its clients run the same change handling.
func _publish(value: int = -1, disable_mask: int = 0) -> void:
	var next: int = alert_level if value < 0 else value
	var args := [
		next,
		_mask() | disable_mask,
		str(runner.name) if is_instance_valid(runner) else "",
		spotted or next != Level.CALM
	]
	SGCNetworkManager.mission_rpc(self, &"sync_state", args)
	sync_state(args[0], args[1], args[2], args[3])


## Every peer. ALARM is final and disabled consoles stay disabled, so a stale message cannot
## undo either.
@rpc("authority", "call_remote", "reliable")
func sync_state(value: int, mask: int, running: String, was_spotted: bool) -> void:
	var before := alert_level
	alert_level = Level.ALARM if before == Level.ALARM else (value as Level)
	spotted = spotted or was_spotted or alert_level != Level.CALM
	for i in range(disabled.size()):
		if mask & (1 << i) and not disabled[i]:
			disabled[i] = true
			console_disabled.emit(i)
	if running != runner_name:
		runner_name = running
		for child in enemies.get_children():
			var jaffa := child as JaffaAI
			if jaffa != null:
				jaffa.raising_alarm = runner_name != "" and str(jaffa.name) == runner_name
		runner_changed.emit(runner_name)
	for console in consoles:
		console.refresh()
	if alert_level != before:
		if alert_level == Level.ALARM:
			_klaxon = 0.0
		level_changed.emit(alert_level)


@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.is_server():
		sync_state.rpc_id(
			multiplayer.get_remote_sender_id(),
			int(alert_level),
			_mask(),
			runner_name,
			spotted
		)


func _play_klaxon() -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists("res://audio/sfx_klaxon.wav"):
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = load("res://audio/sfx_klaxon.wav")
	for bus: StringName in [&"Klaxons / Ambience", &"Ambience"]:
		if AudioServer.get_bus_index(bus) != -1:
			audio.bus = bus
			break
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
