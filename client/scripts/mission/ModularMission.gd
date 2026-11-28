class_name ModularMission
extends GateRoom
## Hosts a modular level as a selectable mission. Player spawning, late joins, squad-down
## failure, the shared mission result and retry all come from GateRoom; this adds the
## level, data-driven objectives, room-marker patrols and the compound's alert state
## (MissionAlert: alarm consoles and reinforcements). SGC-only nodes are simply absent.
signal started
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
const SHOCK_JAFFA := "res://scenes/entities/JaffaShockGuard.tscn"
const NEAR_MISS_RADIUS := 1.15
const AIRMAN := "res://scenes/entities/SGCAirman.tscn"
const SquadOrders := preload("res://scripts/mission/ModularSquadOrders.gd")
@export var definition: MissionDefinition
var base_definition: MissionDefinition
var is_started := false
var setup_errors := PackedStringArray()
var active_difficulty: int = SGCNetworkManager.DIFFICULTY_EASY
var active_run_seed: int = 0
var active_modifiers: Array[String] = []
var active_variant: Dictionary = {}
var active_patrol_plans: Array[Dictionary] = []
var _patrols_spawned: int = 0
@onready var level: LevelAssembly = $Level
@onready var objectives: MissionObjectives = $Objectives
@onready var enemies: Node3D = $Enemies
@onready var alert: MissionAlert = $Alert
@onready var events: MissionEvents = $Events


func _enter_tree() -> void:
	# The level builds in its own _ready, before this node's.
	($Level as LevelAssembly).layout = definition.layout


func _resolve_variation_context() -> void:
	if definition == null:
		return
	if base_definition == null:
		base_definition = definition
	active_difficulty = SGCNetworkManager.DIFFICULTY_EASY
	active_run_seed = 0
	active_modifiers.clear()
	active_variant.clear()

	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if campaign_mgr != null and campaign_mgr.get("is_campaign_active"):
		active_difficulty = MissionDifficulty.clamp_tier(int(campaign_mgr.get("campaign_difficulty")))
		active_run_seed = int(campaign_mgr.get("run_seed"))
		active_modifiers = MissionDifficulty.sanitize_modifiers(campaign_mgr.get("active_modifiers"))
		var stage_var: Variant = campaign_mgr.call(&"get_stage_variant")
		if stage_var is Dictionary and not (stage_var as Dictionary).is_empty():
			active_variant = (stage_var as Dictionary).duplicate(true)
		elif active_run_seed > 0:
			var stage_idx: int = int(campaign_mgr.get("current_stage_index"))
			active_variant = MissionDifficulty.build_stage_variant(
				active_run_seed, stage_idx, active_difficulty, base_definition.objective_variant_entries()
			)
	elif net != null and MissionDifficulty.supports_difficulty_selection(net.selected_mission_id):
		active_difficulty = MissionDifficulty.clamp_tier(net.mission_difficulty)
		active_run_seed = net.run_seed
		active_modifiers = MissionDifficulty.sanitize_modifiers(net.selected_modifiers)
		if active_run_seed > 0:
			active_variant = MissionDifficulty.build_stage_variant(
				active_run_seed, 0, active_difficulty, base_definition.objective_variant_entries()
			)

	var variant_id: String = str(active_variant.get("objective_variant_id", ""))
	if not variant_id.is_empty():
		definition = base_definition.with_variant(StringName(variant_id)) as MissionDefinition
	else:
		definition = base_definition


func _ready() -> void:
	_resolve_variation_context()
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
	enemies.child_exiting_tree.connect(func(_node: Node) -> void: _show_hostiles.call_deferred())
	objectives.setup(definition, level, players_container)
	objectives.objective_changed.connect(_show_objective)
	objectives.completed.connect(_on_objectives_completed)
	_show_objective(objectives.index)
	alert.setup(definition, level, enemies)
	alert.configure_difficulty(active_difficulty, active_modifiers)
	alert.level_changed.connect(_on_alert_changed)
	alert.runner_changed.connect(_on_alarm_runner)
	alert.console_disabled.connect(_on_alarm_disabled)
	if setup_errors.is_empty():
		events.setup(definition, level, objectives, alert)
		events.configure_difficulty(active_difficulty, active_modifiers)
		events.notice_shown.connect(_on_event_notice)
		events.countdown_changed.connect(_on_countdown_changed)
		events.timer_expired.connect(_on_timer_expired)
		objectives.advancement_allowed = events.allow_progress
	super._ready()
	if definition.airman_support:
		_setup_airman_spawner()
	for rings: TransportRings in level.find_children("*", "TransportRings", true, false):
		rings.enable_player_transport()
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
		if setup_errors.is_empty() and definition.airman_support and mission_result < 0:
			_spawn_airman_support(entry)
		for error in setup_errors:
			push_error("ModularMission: " + error)
		if setup_errors.is_empty():
			_spawn_patrols()
	is_started = true
	started.emit()


func _setup_airman_spawner() -> void:
	allies_container = Node3D.new()
	allies_container.name = "Allies"
	add_child(allies_container)
	allies_container.child_entered_tree.connect(_on_combatant_entered)
	var spawner := MultiplayerSpawner.new()
	spawner.name = "AllySpawner"
	spawner.spawn_path = NodePath("../Allies")
	spawner.add_spawnable_scene(AIRMAN)
	add_child(spawner)


func _spawn_airman_support(entry: Node3D) -> void:
	var positions: Array[Vector3] = []
	for offset: float in [-2.0, 2.0]:
		var point := entry.to_global(Vector3(offset, 0.0, 0.0))
		var floor_point := NavigationServer3D.map_get_closest_point(level.navigation_map, point)
		if floor_point.distance_to(point) > 0.45:
			setup_errors.append("Airman rally position off the walkable floor")
			return
		positions.append(floor_point + Vector3.UP * 0.05)
	var scene := load(AIRMAN) as PackedScene
	for i in range(positions.size()):
		var airman := scene.instantiate() as SGCAirmanAI
		airman.name = "Support%d" % (i + 1)
		airman.airman_callsign = ["AIRMAN REYES", "AIRMAN CHEN"][i]
		airman.position = allies_container.to_local(positions[i])
		airman.rotation.y = entry.global_rotation.y - global_rotation.y
		allies_container.add_child(airman, true)


func apply_airman_order(issuer: PlayerController3D, command: int, point: Vector3, target: Node) -> Dictionary:
	if not multiplayer.is_server() or not is_started or mission_result >= 0 or issuer.get_parent() != players_container:
		return {}
	var health := issuer.health_component
	if command < 0 or command > RadialCommandWheel.CMD_CONTEXT_ORDER or health == null:
		return {}
	if health.is_dead or health.is_downed or health.is_stunned or health.frozen:
		return {}
	var aim := issuer.global_position if command == RadialCommandWheel.CMD_REGROUP_ON_ME else point
	return SquadOrders.apply(self, level, issuer, command, aim, target)


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
	if str(node.name).begins_with("Jaffa_P"):
		_patrols_spawned += 1
	var health := node.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.died.connect(_show_hostiles)
	_show_hostiles.call_deferred()


func hostiles_alive() -> int:
	var alive := 0
	for enemy in enemies.get_children():
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and not health.is_dead:
			alive += 1
	return alive


## The authoritative ballistic trace already stops at its first blocking hit.
func register_operative_shot(origin: Vector3, hit: Vector3, impact: Node) -> void:
	if not multiplayer.is_server() or not is_started or mission_result >= 0:
		return
	var travel := hit - origin
	if travel.length_squared() < 0.04:
		return
	# Start the occlusion check just before the impact surface so that its far side
	# cannot pick up pressure through the wall.
	var end := hit - travel.normalized() * 0.035
	var space := get_world_3d().direct_space_state
	for child: Node in enemies.get_children():
		var guard := child as JaffaAI
		if guard == null or not guard.can_be_suppressed():
			continue
		if impact != guard:
			var centre := guard.global_position + Vector3.UP * (0.72 if guard.is_crouching else 1.05)
			var closest := Geometry3D.get_closest_point_to_segment(centre, origin, end)
			if centre.distance_squared_to(closest) > NEAR_MISS_RADIUS * NEAR_MISS_RADIUS:
				continue
			var query := PhysicsRayQueryParameters3D.create(closest, centre, 1 | 128)
			if not space.intersect_ray(query).is_empty():
				continue
		guard.register_incoming_fire(origin)


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
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	var stage_idx: int = int(campaign_mgr.get("current_stage_index")) if (campaign_mgr != null and campaign_mgr.get("is_campaign_active")) else 0
	active_patrol_plans = MissionDifficulty.resolve_patrol_plans(
		definition, active_difficulty, active_run_seed, stage_idx, active_modifiers
	)
	var notice_scale: float = MissionDifficulty.sight_notice_scale(active_difficulty, active_modifiers)
	for p: int in range(active_patrol_plans.size()):
		var plan: Dictionary = active_patrol_plans[p]
		var rooms: PackedStringArray = plan["rooms"] as PackedStringArray
		var marker_name: StringName = plan["marker"] as StringName
		var route: Array[Vector3] = []
		for room: String in rooms:
			route.append(level.marker(StringName(room), marker_name))
		var home := level.get_node(rooms[0]) as Node3D
		var p_size: int = int(plan["size"])
		var base_size: int = int(plan["base_size"])
		var use_shock_all: bool = bool(plan["shock_guard"])
		var base_shield: bool = bool(plan["personal_shield"])
		var promoted_shield: bool = bool(plan["promoted_lead_shield"])
		for n: int in range(p_size):
			var use_shock: bool = use_shock_all or (promoted_shield and n == 0)
			var scene_path := SHOCK_JAFFA if use_shock else JAFFA
			var jaffa := load(scene_path).instantiate() as JaffaAI
			jaffa.name = "Jaffa_P%d_%d" % [p, n]
			# Rank 0 leads and suppresses; later ranks take marker cover when engaged.
			jaffa.formation_rank = n
			if (base_shield or promoted_shield) and n == 0:
				jaffa.has_personal_shield = true
			if notice_scale != 1.0:
				jaffa.notice_time_near *= notice_scale
				jaffa.notice_time_far *= notice_scale
			var world_spot: Vector3
			if n < base_size:
				world_spot = route[0] + home.global_basis.z * -1.2 * n
			else:
				var candidate := route[0] + home.global_basis.x * (1.15 if n % 2 == 0 else -1.15) + home.global_basis.z * -0.9
				world_spot = NavigationServer3D.map_get_closest_point(level.navigation_map, candidate)
			jaffa.position = enemies.to_local(world_spot)
			jaffa.position.y += 0.05
			enemies.add_child(jaffa, true)
			jaffa.start_patrol(route)


func _show_objective(_index: int) -> void:
	if hud == null:
		return
	var objective := objectives.current()
	if objective == null:
		hud.update_objective("ALL OBJECTIVES COMPLETE", Color(0.3, 1.0, 0.5))
	else:
		var total := maxi(1, objectives.enabled_count())
		var current_num := mini(total, objectives.completed_count() + 1)
		hud.update_objective(
			"OBJECTIVE %d/%d: %s" % [current_num, total, objective.text],
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
	if _patrols_spawned > 0:
		hostiles += _patrols_spawned
	elif definition != null:
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


@rpc("authority", "call_local", "reliable")
func sync_mission_result(victory: bool) -> void:
	if mission_result >= 0:
		return
	if hud != null:
		hud.total_kills = hostiles_eliminated_count()
	super.sync_mission_result(victory)
	objectives.set_physics_process(false)
	alert.set_physics_process(false)
	events.stop()
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
					objectives.completed_count(), objectives.enabled_count()
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
	if level.find_child("Rings", true, false) is TransportRings:
		settings.glow_enabled = true
		settings.glow_hdr_threshold = 2.2
		settings.glow_intensity = 0.38
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)
