extends SceneTree
## Modular extraction mission through the production lobby, coordinator and mission host.
## Jaffa move, perceive, shoot and take cover through their production controller; the test
## only places operatives (route setup) and reads state.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
var net: SGCNetworkManager
var main: MainGameCoordinator
var fired := 0


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func launch() -> ModularMission:
	var room := main.current_gate_room as ModularMission
	assert(room != null and room.mission_id == MISSION)
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
	return room


## A patrol waypoint the Jaffa can see from 8-18 m: contact starts at range, not in melee.
func sighted_spot(jaffa: JaffaAI) -> Vector3:
	for attempt in range(60):
		var eye := jaffa.global_position + Vector3(0, 1.4, 0)
		for spot in jaffa.patrol_points:
			var distance := spot.distance_to(jaffa.global_position)
			var query := PhysicsRayQueryParameters3D.create(eye, spot + Vector3(0, 1.2, 0), 1)
			if distance > 8.0 and distance < 18.0:
				if jaffa.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					return spot
		await frames(30)
	assert(false, "No patrol waypoint came into view")
	return Vector3.ZERO


func cover_markers(level: LevelAssembly) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for item in level.layout.instances:
		result.append(level.marker(item.id, &"cover"))
	return result


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	var lobby := main.current_lobby as LobbyUI
	assert(lobby.mission_option_button.item_count == 4)
	lobby._on_mission_selected(2)
	assert(net.selected_mission_id == MISSION and lobby.difficulty_option_button.disabled)
	assert("EXTRACTION" in lobby.start_game_button.text)
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	var room := await launch()
	var level := room.level
	var definition := room.definition
	assert(definition.validate().is_empty())

	# --- Startup: one operative on the validated entry, patrols on their room markers.
	assert(room.players_container.get_child_count() == 1)
	var player := room.players_container.get_node("1") as PlayerController3D
	var entry := level.marker(level.layout.entry_instance, level.layout.entry_marker)
	await frames(30)
	assert(player.is_on_floor() and player.global_position.distance_to(entry) < 2.0)
	assert(room.get_current_sector(player.global_position) == "ENTRY")
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/3"))
	assert(room.get_node_or_null("WaveManager") == null and room.get_node_or_null("SGCMap") == null)
	assert(room.enemies.get_child_count() == 5)
	# The banner is this mission's own text, written on change and not every frame.
	assert(room.hud.wave_label.text == definition.title and "MODULAR EXTRACTION" in definition.title)
	assert(room.hud.enemies_label.text == "HOSTILE PATROLS ACTIVE: 5 JAFFA")
	room.hud.wave_label.text = "probe"
	await frames(10)
	assert(room.hud.wave_label.text == "probe", "Nothing rewrites the banner each frame")
	room._show_hostiles()
	assert(room.hud.wave_label.text == definition.title)
	var lead := room.enemies.get_node("Jaffa_P0_0") as JaffaAI
	var wing := room.enemies.get_node("Jaffa_P0_1") as JaffaAI
	assert(lead.current_state == JaffaAI.State.PATROL and lead.patrol_points.size() == 5)
	for i in range(5):
		var room_id := StringName(definition.patrols[0].rooms[i])
		assert(lead.patrol_points[i] == level.marker(room_id, &"patrol"))

	# --- Extraction and the console are locked until earlier objectives are complete.
	var console := level.get_node("command").find_child("MissionInteract", true, false) as MissionInteractable
	var extract := definition.objectives[2]
	assert(room.objectives.inside(player, extract), "Insertion point is the extraction zone")
	place(player, console.global_position + Vector3(0, 0, 1.5))
	console.interact(player)
	assert(not room.objectives.complete_interaction(definition.objectives[1]))
	place(player, entry)
	await frames(30)
	assert(room.objectives.index == 0 and room.mission_result == -1)
	assert(not console.is_in_group("interactable"))

	# --- Patrol detection, weapons, damage and marker cover.
	for jaffa: JaffaAI in [lead, wing]:
		jaffa.staff_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void: fired += 1)
	var patrol_start := lead.global_position
	await frames(120)
	assert(lead.global_position.distance_to(patrol_start) > 2.0, "Patrol walks before contact")
	# Health is raised for this phase only so the cover run can be observed to its end.
	player.health_component.current_health = 5000.0
	place(player, await sighted_spot(lead))
	var took_cover := false
	var reached_cover := false
	var valid := cover_markers(level)
	for i in range(60 * 40):
		await physics_frame
		if wing.current_state == JaffaAI.State.COVER:
			took_cover = true
			assert(
				wing.tactical_destination in valid or wing.cover_prop != null,
				"Cover comes from a cover prop or a room marker"
			)
			assert(wing.tactical_destination.distance_to(player.global_position) >= 4.0)
			var offset := wing.global_position - wing.tactical_destination
			if Vector2(offset.x, offset.z).length() < 1.3:
				reached_cover = true
		if took_cover and reached_cover and fired > 0 and player.health_component.current_health < 5000.0:
			break
	assert(lead.current_target == player, "The patrol saw and engaged the operative")
	assert(took_cover and reached_cover, "Trailing Jaffa ran to its marker cover")
	assert(fired > 0 and player.health_component.current_health < 5000.0, "Staff fire damaged the operative")
	assert(wing.is_on_floor() and lead.is_on_floor())

	# --- Contact lost: the patrol resumes its route.
	var far := Vector3.ZERO
	var clearance := 0.0
	for item in level.layout.instances:
		var spot := level.marker(item.id, &"entry")
		var nearest := INF
		for enemy: Node3D in room.enemies.get_children():
			nearest = minf(nearest, enemy.global_position.distance_to(spot))
		if nearest > clearance:
			clearance = nearest
			far = spot
	assert(clearance > lead.combat_range * 1.5 + 2.0, "Fixture has a room beyond perception")
	place(player, far)
	for i in range(60 * 30):
		await physics_frame
		if lead.current_state == JaffaAI.State.PATROL and wing.current_state == JaffaAI.State.PATROL:
			break
	assert(lead.current_state == JaffaAI.State.PATROL and wing.current_state == JaffaAI.State.PATROL)
	var resumed_from := lead.global_position
	# A sentry may pause briefly (looking round at the end of a search); it must walk on within 8 s.
	for i in range(60 * 8):
		await physics_frame
		if lead.global_position.distance_to(resumed_from) > 3.0:
			break
	assert(
		lead.global_position.distance_to(resumed_from) > 3.0,
		"Patrol moves again after combat: from %s to %s, nav %s, heading %s, cover %s, crouch %s, vel %s" % [
			resumed_from, lead.global_position, lead.navigator.status, lead.patrol_points[lead.patrol_index],
			lead.cover_prop, lead.is_crouching, lead.velocity
		]
	)

	# --- A lone operative downed by real staff fire fails the mission once.
	player.health_component.current_health = player.health_component.max_health
	place(player, lead.patrol_points[lead.patrol_index])
	for i in range(60 * 90):
		await physics_frame
		if room.mission_result >= 0:
			break
	assert(player.health_component.is_downed or player.health_component.is_dead)
	assert(room.mission_result == 0 and room.hud.is_mission_ended)
	assert(room.hud.debrief_title.text == "MISSION FAILED")
	room._finish_mission(true)
	assert(room.mission_result == 0, "A finished mission keeps its first result")

	# --- After the result: hostiles stand down, the squad's state is final, wording is ours.
	assert(room.hud.return_btn.text == "LEAVE MISSION")
	assert(room.hud.stat_kills.text == "HOSTILES ELIMINATED: 0")
	for control in room.hud.victory_modal.find_children("", "Control", true, false):
		assert(not "SGC" in str(control.get("text")), "Debrief wording belongs to this mission")
	var shots_at_result := fired
	var rest := {}
	for enemy in room.enemies.get_children():
		var jaffa := enemy as JaffaAI
		rest[jaffa] = jaffa.global_position
		assert(jaffa.current_target == null and not jaffa.is_physics_processing())
		if jaffa not in [lead, wing]:
			jaffa.staff_fired.connect(func(_o: Vector3, _d: Vector3) -> void: fired += 1)
	var was_downed := player.health_component.is_downed
	var health_at_result := player.health_component.current_health
	player.health_component.take_damage(50.0, lead)
	await frames(60 * 22)
	for jaffa: JaffaAI in rest:
		assert(jaffa.global_position.distance_to(rest[jaffa]) < 0.05, "Hostiles do not move after the result")
	assert(fired == shots_at_result, "No Jaffa fires after the result")
	assert(player.health_component.current_health == health_at_result)
	assert(player.health_component.is_downed == was_downed, "Bleed-out stops with the result")

	# --- Retry: fresh world, no stale actors or objective state.
	var old_room := room.get_instance_id()
	assert(net.request_restart_game())
	await frames(5)
	room = await launch()
	assert(room.get_instance_id() != old_room and not is_instance_id_valid(old_room))
	level = room.level
	definition = room.definition
	assert(room.mission_result == -1 and room.objectives.index == 0)
	assert(room.enemies.get_child_count() == 5 and room.players_container.get_child_count() == 1)
	assert(root.find_children("Jaffa_P*", "JaffaAI", true, false).size() == 5, "No stale Jaffa")
	assert(root.find_children("MissionInteract", "", true, false).size() == 1)
	assert(not room.hud.is_mission_ended and room.hud.objective_label.text.begins_with("OBJECTIVE 1/3"))
	player = room.players_container.get_node("1") as PlayerController3D
	entry = level.marker(level.layout.entry_instance, level.layout.entry_marker)
	console = level.get_node("command").find_child("MissionInteract", true, false) as MissionInteractable

	# --- Objective progression. Hostiles are paused so this run is about the rules.
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(false)
	var events: Array[int] = []
	room.objectives.objective_changed.connect(func(index: int) -> void: events.append(index))
	var buddy_spot := level.marker(&"hub", &"entry")
	room._spawn_player(2, SGCNetworkManager.CLASS_CARTER_TECH, buddy_spot + Vector3(0, 0.05, 0))
	var buddy := room.players_container.get_node("2") as PlayerController3D
	await frames(10)
	place(player, level.marker(&"command", &"entry"))
	await frames(5)
	assert(room.objectives.index == 1 and room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))
	assert(console.is_in_group("interactable"))
	# Out of reach, then downed: both refused by the server-side check.
	console.interact(player)
	assert(room.objectives.index == 1, "Console is out of reach from the room marker")
	place(player, console.global_position + Vector3(0, 0, 1.5))
	player.health_component.take_damage(9999.0)
	assert(player.health_component.is_downed)
	console.interact(player)
	assert(room.objectives.index == 1, "A downed operative cannot use the console")
	await frames(5)
	assert(room.mission_result == -1, "One standing teammate keeps the mission alive")

	# --- A downed operative is not targeted while a standing one is known. This checks the
	# shared target choice through the assault rule; sentry sight is in test_jaffa_perception.
	var sentry := room.enemies.get_node("Jaffa_P2_0") as JaffaAI
	sentry.profile = JaffaAI.Profile.ASSAULT
	var here := sentry.global_position
	var spots: Array[Vector3] = sentry.patrol_points.duplicate()
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(here) < b.distance_to(here))
	assert(spots.size() >= 2 and spots[1].distance_to(here) < sentry.combat_range)
	place(player, spots[0])
	place(buddy, spots[1])
	await frames(2)
	sentry._find_nearest_target()
	assert(sentry.current_target == buddy, "The standing operative is chosen over a nearer downed one")
	var away := buddy_spot
	for item in level.layout.instances:
		var spot := level.marker(item.id, &"entry")
		if spot.distance_to(here) > away.distance_to(here):
			away = spot
	place(buddy, away)
	await frames(2)
	assert(buddy.global_position.distance_to(here) > sentry.combat_range * 1.5, "Buddy is out of perception")
	sentry._find_nearest_target()
	assert(sentry.current_target == player, "With nobody standing in reach, the downed operative is the target")
	sentry.current_target = null
	sentry.profile = JaffaAI.Profile.SENTRY
	place(buddy, buddy_spot)
	place(player, console.global_position + Vector3(0, 0, 1.5))
	player.health_component.revive(buddy)
	assert(not player.health_component.is_downed and player.health_component.current_health > 0.0)
	console.interact(player)
	assert(room.objectives.index == 2)
	console.interact(player)
	console.interact(buddy)
	assert(room.objectives.index == 2 and events == [1, 2], "Repeat use completes nothing twice")
	assert(not console.is_in_group("interactable"))

	# --- Extraction: every standing operative must be in the zone; downed ones do not block.
	place(player, entry)
	await frames(20)
	assert(room.mission_result == -1, "A standing teammate is still outside the zone")
	buddy.health_component.take_damage(9999.0)
	assert(buddy.health_component.is_downed)
	for i in range(60):
		await physics_frame
		if room.mission_result >= 0:
			break
	assert(room.mission_result == 1 and room.objectives.is_complete())
	assert(events == [1, 2, 3] and room.hud.is_mission_ended)
	assert(room.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	player.health_component.take_damage(9999.0)
	await frames(5)
	assert(room.mission_result == 1, "Squad wipe after success does not change the result")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS modular extraction: lobby launch, patrol combat and cover, failure, retry, objectives, extraction")
	await preload("res://tests/support/finish.gd").success(self)
