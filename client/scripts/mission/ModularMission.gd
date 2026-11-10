class_name ModularMission
extends GateRoom
## Hosts a modular level as a selectable mission. Player spawning, late joins, squad-down
## failure, the shared mission result and retry all come from GateRoom; this adds the
## level, data-driven objectives and room-marker patrols. SGC-only nodes are simply absent.
signal started
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
@export var definition: MissionDefinition
var is_started := false
var setup_errors := PackedStringArray()
@onready var level: LevelAssembly = $Level
@onready var objectives: MissionObjectives = $Objectives
@onready var enemies: Node3D = $Enemies


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
	objectives.setup(definition, level, players_container)
	objectives.objective_changed.connect(_show_objective)
	objectives.completed.connect(_on_objectives_completed)
	_show_objective(objectives.index)
	super._ready()
	if DisplayServer.get_name() != "headless":
		_add_presentation()
	if not level.ready_for_navigation:
		await level.navigation_ready
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


func _process(delta: float) -> void:
	super._process(delta)
	if hud == null or hud.is_mission_ended:
		return
	var alive := 0
	for enemy in enemies.get_children():
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and not health.is_dead:
			alive += 1
	hud.wave_label.text = "MODULAR EXTRACTION — DEVELOPMENT UAT"
	hud.enemies_label.text = "HOSTILE PATROLS ACTIVE: %d JAFFA" % alive


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
	if multiplayer.is_server():
		_finish_mission(true)


## One result per mission: a later squad wipe cannot overwrite a success, or the reverse.
func _finish_mission(victory: bool) -> void:
	if mission_result < 0:
		super._finish_mission(victory)


@rpc("authority", "call_local", "reliable")
func sync_mission_result(victory: bool) -> void:
	super.sync_mission_result(victory)
	objectives.set_physics_process(false)
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
	if hud != null and hud.debrief_subtitle != null:
		hud.debrief_subtitle.text = (
			"OBJECTIVE COMPLETE — STANDING OPERATIVES EXTRACTED"
			if victory
			else "ALL OPERATIVES DOWN — MISSION ABORTED"
		)
		if not victory and hud.debrief_title != null:
			hud.debrief_title.text = "MISSION FAILED"
		hud.stat_waves.text = "OBJECTIVES COMPLETE: %d / %d" % [
			objectives.index, definition.objectives.size()
		]
		hud.stat_chevrons.text = "OPERATIVES STANDING: %d" % objectives.standing().size()
		hud.stat_status.text = "STATUS: %s" % (
			"STANDING OPERATIVES EXTRACTED" if victory else "SQUAD COMPROMISED"
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
