extends SceneTree
## The Goa'uld infiltration mission with every phase 3 system live (roadmap GI-2): hearing
## (ST-2), the compound alert, alarm runner and reinforcements (EV-1) and prop cover (TA-1),
## through the production lobby, mission host and sentries. The quiet route is covered by
## test_goauld_infiltration_mission; this suite plays the loud one to extraction.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var probe: Node3D


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func until(check: Callable, limit: float) -> bool:
	for i in range(int(limit * 60.0)):
		if check.call():
			return true
		await physics_frame
	return bool(check.call())


func floor_near(spot: Vector3) -> Vector3:
	var point := NavigationServer3D.map_get_closest_point(level.navigation_map, spot)
	return point if point.distance_to(spot) < 0.8 else Vector3.INF


func clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func room_of(node: Node) -> String:
	var parent := node.get_parent()
	while parent != null and parent.get_parent() != level:
		parent = parent.get_parent()
	return str(parent.name) if parent != null else ""


func sentry_named(prefix: String) -> JaffaAI:
	for enemy in room.enemies.get_children():
		if str(enemy.name).begins_with(prefix):
			return enemy as JaffaAI
	return null


## A spot in reach of a mission console, on the floor.
func console_spot(room_id: StringName, node_name: String) -> Vector3:
	var console := level.get_node(str(room_id)).find_child(node_name, true, false) as Node3D
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var spot := floor_near(console.global_position + offset)
		if spot != Vector3.INF and spot.distance_to(console.global_position) < MissionInteractable.REACH - 0.3:
			return spot
	assert(false, "No floor beside the console in " + str(room_id))
	return Vector3.ZERO


func use_console(room_id: StringName) -> void:
	var console := level.get_node(str(room_id)).find_child("MissionInteract", true, false) as MissionInteractable
	place(player, console_spot(room_id, "MissionInteract"))
	var before := room.objectives.index
	for i in range(30):
		console.interact(player)
		await frames(2)
		if room.objectives.index > before:
			return
	assert(false, "Console in %s did not complete its objective" % room_id)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	for i in range(600):
		room = main.current_gate_room as ModularMission
		if room != null:
			break
		await frames(1)
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 1000000.0
	probe = Node3D.new()
	room.add_child(probe)
	var alert := room.alert

	# --- Cover where the guarded fights happen: the checkpoint, the upper antechamber, the stores.
	var cover := {}
	for prop in LevelNavigator.cover_props(level):
		cover[room_of(prop)] = int(cover.get(room_of(prop), 0)) + 1
	assert(int(cover.get("checkpoint", 0)) >= 2 and int(cover.get("cmd_antechamber", 0)) >= 2, str(cover))
	assert(int(cover.get("stores", 0)) >= 3, str(cover))

	# --- Noise in the compound: a rifle shot in maintenance draws the generator watch to look,
	# without anyone being spotted.
	var watch := sentry_named("Jaffa_P1_")
	assert(watch != null and watch.profile == JaffaAI.Profile.SENTRY)
	var shot_at := level.marker(&"maint", &"patrol")
	probe.global_position = shot_at
	assert(
		await until(
			func() -> bool: return watch.global_position.distance_to(shot_at) < 28.0 and not watch.perception.can_see(probe),
			30.0
		),
		"The generator watch passes within earshot of maintenance"
	)
	place(player, shot_at)
	var gun := WeaponP90.new()
	player.add_child(gun)
	assert(gun.try_fire(1.0, Vector3(0.2, 1.0, 0.0).normalized()))
	place(player, level.marker(level.layout.entry_instance, level.layout.entry_marker))
	gun.queue_free()
	await frames(2)
	assert(watch.investigating, "The generator watch heard the shot")
	assert(alert.alert_level == MissionAlert.Level.CALM, "A noise is not a sighting")

	# --- A guard fights from a barricade or crate in a guarded room: put it beside one, with the
	# operative inside the room and the room's doors open, as in a fight.
	var guard := sentry_named("Jaffa_P0_0")
	var setup := {}
	for prop in LevelNavigator.cover_props(level):
		var room_id := room_of(prop)
		if not room_id in ["checkpoint", "cmd_antechamber", "stores"] or not setup.is_empty():
			continue
		var module := level.get_node(room_id) as Node3D
		for node in get_nodes_in_group("modular_door"):
			var door := node as ModularDoor
			if door != null and door.global_position.distance_to(module.global_position) < 6.0:
				door.sync_open(true)
		await frames(2)
		for gx in range(-8, 9):
			for gz in range(-8, 9):
				if not setup.is_empty():
					break
				var threat := floor_near(prop.global_position + Vector3(gx, 0, gz))
				if threat == Vector3.INF or absf(threat.y - prop.global_position.y) > 0.5:
					continue
				var towards := Vector3(threat.x - prop.global_position.x, 0, threat.z - prop.global_position.z)
				if towards.length() < 3.0:
					continue
				var start := floor_near(prop.global_position + towards.normalized() * 2.2)
				if start == Vector3.INF:
					continue
				probe.global_position = start
				var found := LevelNavigator.prop_cover(level, probe, threat, 10.0)
				if not found.is_empty() and found["prop"] == prop:
					if clear(found["spot"] + Vector3(0, JaffaAI.EYE_HEIGHT, 0), threat + Vector3(0, 1.5, 0)):
						setup = {"prop": prop, "threat": threat, "start": start}
	assert(not setup.is_empty(), "A guarded room has cover the guards can use")
	place(player, setup.threat)
	guard.global_position = setup.start + Vector3(0, 0.05, 0)
	guard.health_component.take_damage(5.0, player)
	await frames(2)
	assert(guard.cover_prop == setup.prop and guard.current_state == JaffaAI.State.COVER, "The guard takes the cover")
	print("Cover fight in %s" % room_of(setup.prop))

	# --- The fight escalates: a runner raises the alarm and the reinforcements arrive.
	assert(await until(func() -> bool: return alert.alert_level != MissionAlert.Level.CALM, 5.0))
	assert(await until(func() -> bool: return alert.is_raised(), 30.0), "The alarm is raised")
	place(player, level.marker(level.layout.entry_instance, level.layout.entry_marker))
	assert(await until(func() -> bool: return alert.reinforcements_spawned == 4, 25.0), "Reinforcements arrive")
	assert(room.hud.enemies_label.text.begins_with("ALARM RAISED"))

	# --- Loud route to extraction while the compound hunts: generator, command records, the gate.
	await use_console(&"generator")
	assert(room.objectives.index == 1)
	await use_console(&"cmd_command")
	assert(room.objectives.index == 2)
	place(player, level.marker(level.layout.entry_instance, level.layout.entry_marker))
	assert(await until(func() -> bool: return room.mission_result >= 0, 5.0))
	assert(room.mission_result == 1 and room.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	assert(room.hud.stat_status.text.ends_with("ALARM RAISED"), room.hud.stat_status.text)
	for enemy in room.enemies.get_children():
		assert(not enemy.is_physics_processing(), "Every hostile, reinforcements included, stands down")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS goa'uld infiltration loud: cover in the guarded rooms, heard shot, barricade fight, alarm, reinforcements, objectives under alarm and extraction")
	await preload("res://tests/support/finish.gd").success(self)
