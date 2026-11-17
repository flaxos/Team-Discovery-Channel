class_name ModularMission
extends GateRoom
## Hosts a modular level as a selectable mission. Player spawning, late joins, squad-down
## failure, the shared mission result and retry all come from GateRoom; this adds the
## level, data-driven objectives, room-marker patrols and the compound's alert state
## (MissionAlert: alarm consoles and reinforcements). SGC-only nodes are simply absent.
signal started
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
@export var definition: MissionDefinition
var is_started := false
var setup_errors := PackedStringArray()
@onready var level: LevelAssembly = $Level
@onready var objectives: MissionObjectives = $Objectives
@onready var enemies: Node3D = $Enemies
@onready var alert: MissionAlert = $Alert
@onready var events: MissionEvents = $Events


func _enter_tree() -> void:
	# The level builds in its own _ready, before this node's.
	($Level as LevelAssembly).layout = definition.layout


func _ready() -> void:
	setup_errors = definition.validate()
	var layout := level.layout
	var entry := (
		level.get_node("%s/Markers/%s" % [layout.entry_instance, layout.entry_marker]) as Node3D
	)
	for i in range(SGCNetworkManager.MAX_PLAYERS):
		var point := Marker3D.new()
		point.name = "Spawn%d" % (i + 1)
		spawns_container.add_child(point)
		point.global_position = (
			entry.global_transform * Vector3((i % 2 - 0.5) * 1.2, 0.05, (i / 2 - 0.5) * 1.6)
		)
	enemies.child_entered_tree.connect(_on_hostile_entered)
	players_container.child_entered_tree.connect(_on_operative_entered)
	enemies.child_exiting_tree.connect(func(_node: Node) -> void: _show_hostiles.call_deferred())
	objectives.setup(definition, level, players_container)
	objectives.objective_changed.connect(_show_objective)
	objectives.completed.connect(_on_objectives_completed)
	_show_objective(objectives.index)
	alert.setup(definition, level, enemies)
	alert.level_changed.connect(_on_alert_changed)
	alert.runner_changed.connect(_on_alarm_runner)
	alert.console_disabled.connect(_on_alarm_disabled)
	if setup_errors.is_empty():
		events.setup(definition, level, objectives, alert)
		events.notice_shown.connect(_on_event_notice)
		events.countdown_changed.connect(_on_countdown_changed)
		events.timer_expired.connect(_on_timer_expired)
		objectives.advancement_allowed = events.allow_progress
	super._ready()
	if DisplayServer.get_name() != "headless":
		_add_presentation()
	if not level.ready_for_navigation:
		await level.navigation_ready
	if setup_errors.is_empty() and mission_result < 0:
		setup_errors.append_array(events.start())
	if multiplayer.is_server():
		for point: Node3D in spawns_container.get_children():
			var floor_point := NavigationServer3D.map_get_closest_point(
				level.navigation_map, point.global_position
			)
			if floor_point.distance_to(point.global_position) > 0.5:
				setup_errors.append("Spawn point off the walkable floor: " + str(point.name))
		for error in setup_errors:
			push_error("ModularMission: " + error)
		if setup_errors.is_empty():
			_spawn_patrols()
	is_started = true
	started.emit()


func _on_event_notice(text: String) -> void:
	if hud != null and not hud.is_mission_ended and not text.is_empty():
		hud.show_squad_order_toast(text, 5.0)


func _on_timer_expired(_id: StringName) -> void:
	if multiplayer.is_server() and mission_result < 0:
		conclude(false)


func _on_countdown_changed(label: String, seconds: float, running: bool) -> void:
	if hud != null:
		hud.update_mission_countdown(label, seconds, running)
		if mission_result >= 0:
			_show_debrief(mission_result == 1)


func _on_hostile_entered(node: Node) -> void:
	var health := node.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.died.connect(_show_hostiles)
	_show_hostiles.call_deferred()


func _on_operative_entered(node: Node) -> void:
	if mission_result >= 0 and node is PlayerController3D:
		(node.get_node("HealthComponent") as HealthComponent).frozen = true


func hostiles_alive() -> int:
	var alive := 0
	for enemy in enemies.get_children():
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and not health.is_dead:
			alive += 1
	return alive


## The banner changes only when a hostile arrives, dies or leaves, or the alert level
## changes, not every frame.
func _show_hostiles() -> void:
	if hud != null and not hud.is_mission_ended:
		var state := "HOSTILE PATROLS ACTIVE"
		if alert.alert_level == MissionAlert.Level.SEARCHING:
			state = "COMPOUND ALERTED"
		elif alert.alert_level == MissionAlert.Level.ALARM:
			state = "ALARM RAISED"
		hud.set_mission_banner(definition.title, "%s: %d JAFFA" % [state, hostiles_alive()])


func _on_alert_changed(value: int) -> void:
	_show_hostiles()
	if hud == null or hud.is_mission_ended:
		return
	match value:
		MissionAlert.Level.SEARCHING:
			hud.show_squad_order_toast("YOU HAVE BEEN SPOTTED — HOSTILES ALERTED", 4.0)
		MissionAlert.Level.ALARM:
			hud.show_squad_order_toast(
				"ALARM RAISED — REINFORCEMENTS INBOUND"
				if not definition.reinforcements.is_empty()
				else "ALARM RAISED",
				5.0
			)
		MissionAlert.Level.CALM:
			hud.show_squad_order_toast("ALERT OVER — PATROLS RESUMING", 3.5)


func _on_alarm_runner(runner_name: String) -> void:
	if hud != null and not hud.is_mission_ended and runner_name != "" and not alert.is_raised():
		hud.show_squad_order_toast("A JAFFA IS RUNNING FOR THE ALARM — STOP HIM", 4.0)


func _on_alarm_disabled(_index: int) -> void:
	if hud == null or hud.is_mission_ended:
		return
	var remaining := alert.disabled.count(false)
	hud.show_squad_order_toast(
		"ALARM CONSOLE DISABLED — %s" % (
			"NO ALARM CAN BE RAISED" if remaining == 0 else "%d STILL ACTIVE" % remaining
		),
		3.5
	)


func _spawn_patrols() -> void:
	for p in range(definition.patrols.size()):
		var patrol := definition.patrols[p]
		var route: Array[Vector3] = []
		for room in patrol.rooms:
			route.append(level.marker(StringName(room), patrol.marker))
		var home := level.get_node(patrol.rooms[0]) as Node3D
		for n in range(patrol.size):
			var jaffa := load(JAFFA).instantiate() as JaffaAI
			jaffa.name = "Jaffa_P%d_%d" % [p, n]
			# Rank 0 leads and suppresses; later ranks take marker cover when engaged.
			jaffa.formation_rank = n
			jaffa.position = enemies.to_local(route[0] + home.global_basis.z * -1.2 * n)
			jaffa.position.y += 0.05
			enemies.add_child(jaffa, true)
			jaffa.start_patrol(route)


func _show_objective(index: int) -> void:
	if hud == null:
		return
	var objective := objectives.current()
	if objective == null:
		hud.update_objective("ALL OBJECTIVES COMPLETE", Color(0.3, 1.0, 0.5))
	else:
		hud.update_objective(
			"OBJECTIVE %d/%d: %s" % [index + 1, definition.objectives.size(), objective.text],
			Color(0.3, 1.0, 0.5) if objective.kind == "extract" else Color(0.4, 0.9, 1.0)
		)


func _on_objectives_completed() -> void:
	if mission_result >= 0:
		return
	if session != null:
		if hud != null:
			hud.update_objective(
				"STARGATE OPEN FOR HOME — STEP THROUGH EVENT HORIZON",
				Color(0.3, 1.0, 0.5)
			)
		if multiplayer.is_server():
			_open_return_gate()
		return
	if multiplayer.is_server():
		conclude(true)


func _open_return_gate() -> void:
	if stargate_mesh == null or not multiplayer.is_server():
		return
	if stargate_mesh.current_state == StargateRing.GateState.INACTIVE:
		stargate_mesh.reserve_connection(false)
	if stargate_mesh.current_state == StargateRing.GateState.DIALING:
		for i in range(stargate_mesh.locked_chevrons_count + 1, stargate_mesh.max_chevrons + 1):
			stargate_mesh.lock_chevron(i)
	stargate_mesh.authorize_extraction()


func hostiles_eliminated_count() -> int:
	var hostiles := alert.reinforcements_spawned if alert != null else 0
	if definition != null:
		for patrol in definition.patrols:
			hostiles += patrol.size
	return maxi(0, hostiles - hostiles_alive())


func alert_summary() -> String:
	if alert == null:
		return "UNDETECTED"
	if alert.is_raised():
		return "ALARM RAISED"
	if alert.spotted:
		return "SPOTTED, NO ALARM"
	return "UNDETECTED"


## One result per mission: a later squad wipe cannot overwrite a success, or the reverse.
func _finish_mission(victory: bool) -> void:
	if mission_result < 0:
		super._finish_mission(victory)


@rpc("authority", "call_local", "reliable")
func sync_mission_result(victory: bool) -> void:
	if hud != null:
		hud.total_kills = hostiles_eliminated_count()
	super.sync_mission_result(victory)
	# The result is final: hostiles stand down and nothing further happens to the squad.
	objectives.set_physics_process(false)
	alert.set_physics_process(false)
	events.stop()
	for enemy in enemies.get_children():
		if enemy is JaffaAI:
			(enemy as JaffaAI).stand_down()
	for player in players_container.get_children():
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.frozen = true
	_show_debrief(victory)


func _show_debrief(victory: bool) -> void:
	var expired := events.timer_state == MissionEvents.TimerState.EXPIRED
	if expired:
		get_tree().paused = false
	if hud != null:
		hud.set_debrief(
			{
				"title": "EXTRACTION SUCCESSFUL" if victory else "MISSION FAILED",
				"subtitle": (
					"OBJECTIVE COMPLETE — STANDING OPERATIVES EXTRACTED"
					if victory
					else ("EXTRACTION WINDOW EXPIRED" if expired else "ALL OPERATIVES DOWN — MISSION ABORTED")
				),
				"objectives": "OBJECTIVES COMPLETE: %d / %d" % [
					objectives.index, definition.objectives.size()
				],
				"squad": "OPERATIVES STANDING: %d" % objectives.standing().size(),
				"status": "STATUS: %s — %s" % [
					"STANDING OPERATIVES EXTRACTED" if victory else ("EXTRACTION WINDOW EXPIRED" if expired else "SQUAD COMPROMISED"),
					alert_summary()
				],
				"leave": "LEAVE MISSION"
			}
		)


## Late joiners only need the result here; doors and objectives send their own snapshots.
@rpc("authority", "call_remote", "reliable")
func sync_room_snapshot(
	_doors: bool, _shutters: bool, _alarm: bool, result: int, _control_closed: bool = false
) -> void:
	if result >= 0:
		sync_mission_result(result == 1)


func _setup_sector_shrouds() -> void:
	pass


func get_current_sector(pos: Vector3) -> String:
	for item in level.layout.instances:
		var module := level.get_node_or_null(str(item.id)) as Node3D
		if module != null and item.module.occupied.has_point(module.to_local(pos)):
			return str(item.id).to_upper()
	return SECTOR_UNKNOWN


func get_sector_display_name(sector_id: String) -> String:
	return sector_id.replace("_", " ")


## View-only: the level preview's ambient light. Roofs stay on for the operative camera.
func _add_presentation() -> void:
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.05, 0.06, 0.08)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	var palette := LevelThemeResolver.lighting(level.layout)
	if palette != null:
		settings.ambient_light_color = palette.ambient_color
		settings.ambient_light_energy = palette.ambient_energy
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)
