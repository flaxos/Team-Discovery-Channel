extends SceneTree
## Sentry perception (roadmap ST-1) on the integrated fixture, through the production mission,
## JaffaAI and JaffaPerception. The test places operatives and fresh sentries and reads state;
## sight, awareness, movement and fire are the production controller. Positions are found from
## the level's own geometry, so the cases do not depend on hand-written coordinates.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var serial := 0
var shots := 0


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func on_floor(spot: Vector3) -> bool:
	return NavigationServer3D.map_get_closest_point(level.navigation_map, spot).distance_to(spot) < 0.4


## Rays between the heights a Jaffa looks from and the heights it looks at.
func rays_clear(from: Vector3, to: Vector3) -> int:
	var space := room.get_world_3d().direct_space_state
	var count := 0
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0, eye, 0), to + Vector3(0, aim, 0), 1
			)
			if space.intersect_ray(query).is_empty():
				count += 1
	return count


func clear(from: Vector3, to: Vector3) -> bool:
	return rays_clear(from, to) == 4


func blocked(from: Vector3, to: Vector3) -> bool:
	return rays_clear(from, to) == 0


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func marker_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for item in level.layout.instances:
		for id: StringName in [&"entry", &"patrol", &"cover"]:
			var spot := level.marker(item.id, id)
			if on_floor(spot):
				spots.append(spot)
	return spots


## A sentry spot with clear floor 7 m ahead and 4 m behind.
func open_setup() -> Dictionary:
	for item in level.layout.instances:
		var at := level.marker(item.id, &"patrol")
		for facing: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var front := at + facing * 7.0
			var behind := at - facing * 4.0
			if (
				on_floor(at) and on_floor(front) and on_floor(behind)
				and clear(at, front) and clear(at, behind)
			):
				return {"at": at, "facing": facing, "front": front, "behind": behind}
	return {}


## A spot straight ahead of a sentry, 5-18 m away and fully hidden by a wall (same deck) or a
## floor (other deck).
func hidden_setup(other_deck: bool) -> Dictionary:
	var spots := marker_spots()
	for at in spots:
		for spot in spots:
			if (absf(spot.y - at.y) > 3.0) != other_deck:
				continue
			var distance := at.distance_to(spot)
			var flat := Vector3(spot.x - at.x, 0, spot.z - at.z)
			if distance < 5.0 or distance > 18.0 or flat.length() < 0.5 or not blocked(at, spot):
				continue
			return {"at": at, "facing": flat.normalized(), "spot": spot}
	return {}


## An ordinary door with floor 4.5 m either side: clear through it when open, blocked when shut.
func door_setup() -> Dictionary:
	for node in get_nodes_in_group("modular_door"):
		var door := node as ModularDoor
		if door == null or not level.is_ancestor_of(door) or door.is_security or door.locked:
			continue
		var normal := door.global_basis.z
		normal.y = 0.0
		normal = normal.normalized()
		var at := door.global_position + normal * 4.5
		var spot := door.global_position - normal * 4.5
		if not (on_floor(at) and on_floor(spot)):
			continue
		door.sync_open(true)
		await frames(2)
		var open := clear(at, spot)
		door.sync_open(false)
		await frames(2)
		if open and blocked(at, spot):
			return {"door": door, "at": at, "facing": -normal, "spot": spot}
	return {}


## The marker farthest from every given point.
func farthest_from(points: Array[Vector3]) -> Vector3:
	var best := Vector3.ZERO
	var clearance := 0.0
	for spot in marker_spots():
		var nearest := INF
		for point in points:
			nearest = minf(nearest, spot.distance_to(point))
		if nearest > clearance:
			clearance = nearest
			best = spot
	return best


func sentry(at: Vector3, facing: Vector3, route: Array[Vector3] = []) -> JaffaAI:
	serial += 1
	var jaffa := (load(JAFFA) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "Sentry%d" % serial
	jaffa.position = room.enemies.to_local(at + Vector3(0, 0.05, 0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var points: Array[Vector3] = [at]
	if not route.is_empty():
		points = route.duplicate()
	jaffa.start_patrol(points)
	jaffa.staff_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void: shots += 1)
	assert(jaffa.profile == JaffaAI.Profile.SENTRY, "start_patrol selects the sentry profile")
	return jaffa


func retire(jaffa: JaffaAI) -> void:
	jaffa.queue_free()
	await frames(2)


## The highest awareness level reached over `duration` seconds.
func watch(jaffa: JaffaAI, duration: float) -> int:
	var highest := 0
	for i in range(int(duration * 60.0)):
		await physics_frame
		highest = maxi(highest, jaffa.awareness_level)
	return highest


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await frames(3)
	room = main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 1000000.0
	var route: Array[Vector3] = []
	for id: String in room.definition.patrols[0].rooms:
		route.append(level.marker(StringName(id), &"patrol"))
	# The mission's own patrols are removed: every case below uses one fresh sentry.
	for enemy in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)
	var s: JaffaAI

	# --- Walls and decks: the old rule acquires through them; a sentry does not.
	for other_deck: bool in [false, true]:
		var hidden := hidden_setup(other_deck)
		assert(not hidden.is_empty(), "Fixture has a hidden spot (other deck: %s)" % other_deck)
		place(player, hidden.spot)
		s = sentry(hidden.at, hidden.facing)
		await frames(2)
		s.profile = JaffaAI.Profile.ASSAULT
		s._find_nearest_target()
		assert(s.current_target == player, "Precondition: the assault rule acquires through geometry")
		s.profile = JaffaAI.Profile.SENTRY
		s.current_target = null
		var start := s.global_position
		shots = 0
		assert(await watch(s, 4.0) == JaffaPerception.Level.UNAWARE, "Nothing is seen through geometry")
		assert(s.current_target == null and shots == 0)
		assert(s.global_position.distance_to(start) < 1.0, "The sentry does not go towards it")
		await retire(s)

	# --- Behind the sentry, in clear line of sight: outside the cone, never noticed.
	var open := open_setup()
	assert(not open.is_empty(), "Fixture has an open spot for the cone cases")
	var away := farthest_from([open.at])
	assert(open.at.distance_to(away) > 26.0, "Fixture has a spot beyond sight of the open setup")
	place(player, open.behind)
	s = sentry(open.at, open.facing)
	assert(await watch(s, 4.0) == JaffaPerception.Level.UNAWARE, "Outside the cone is not seen")
	await retire(s)

	# --- In front: suspicious first, alerted only after the notice time, with the tell.
	place(player, open.front)
	s = sentry(open.at, open.facing)
	var reach := clampf((open.at.distance_to(open.front) - 4.0) / (s.sight_range - 4.0), 0.0, 1.0)
	var notice := lerpf(s.notice_time_near, s.notice_time_far, reach)
	var suspicious_frame := -1
	var alerted_frame := -1
	var question_shown := false
	for i in range(60 * 4):
		await process_frame
		if s.awareness_level == JaffaPerception.Level.SUSPICIOUS:
			if suspicious_frame < 0:
				suspicious_frame = i
			question_shown = question_shown or (s._tell.visible and s._tell.text == "?")
		if s.awareness_level == JaffaPerception.Level.ALERTED:
			alerted_frame = i
			break
	assert(suspicious_frame >= 0 and alerted_frame > suspicious_frame, "Suspicious before alerted")
	assert(question_shown, "Suspicion shows a '?' tell")
	assert(alerted_frame / 60.0 >= notice - 0.15, "Not alerted before the notice time")
	assert(alerted_frame / 60.0 <= notice + 0.5)
	await frames(2)
	assert(s.current_target == player and s._tell.visible and s._tell.text == "!")
	await retire(s)

	# --- Seen briefly, then gone: suspicion drains away without combat.
	place(player, open.front)
	s = sentry(open.at, open.facing)
	for i in range(60):
		await physics_frame
		if s.awareness_level == JaffaPerception.Level.SUSPICIOUS:
			break
	assert(s.awareness_level == JaffaPerception.Level.SUSPICIOUS)
	place(player, away)
	shots = 0
	assert(await watch(s, s.forget_time + 1.0) < JaffaPerception.Level.ALERTED, "Never alerted")
	assert(s.awareness_level == JaffaPerception.Level.UNAWARE and s.perception.awareness == 0.0)
	assert(s.current_target == null and shots == 0 and not s._tell.visible)
	await retire(s)

	# --- Smoke blocks sight until it clears.
	var cloud := Area3D.new()
	cloud.add_to_group("smoke_cloud")
	room.add_child(cloud)
	cloud.global_position = (open.at + open.front) * 0.5 + Vector3(0, 1.2, 0)
	place(player, open.front)
	s = sentry(open.at, open.facing)
	assert(await watch(s, 3.0) == JaffaPerception.Level.UNAWARE, "Smoke blocks sight")
	cloud.queue_free()
	assert(await watch(s, 3.0) >= JaffaPerception.Level.SUSPICIOUS, "Sight returns when it clears")
	await retire(s)

	# --- A closed door blocks sight; opening it restores sight.
	var doorway := await door_setup()
	assert(not doorway.is_empty(), "Fixture has an ordinary door with floor either side")
	place(player, doorway.spot)
	s = sentry(doorway.at, doorway.facing)
	assert(await watch(s, 3.0) == JaffaPerception.Level.UNAWARE, "A closed door blocks sight")
	(doorway.door as ModularDoor).sync_open(true)
	assert(await watch(s, 3.0) >= JaffaPerception.Level.SUSPICIOUS, "An open doorway does not")
	await retire(s)
	(doorway.door as ModularDoor).sync_open(false)

	# --- Being hit alerts at once, even from outside the cone.
	place(player, open.behind)
	s = sentry(open.at, open.facing)
	await frames(10)
	assert(s.awareness_level == JaffaPerception.Level.UNAWARE)
	s.health_component.take_damage(5.0, player)
	await frames(1)
	assert(s.awareness_level == JaffaPerception.Level.ALERTED and s.current_target == player)
	await retire(s)

	# --- An alert reaches a nearby sentry that saw nothing.
	var first := sentry(open.at, open.facing)
	var second := sentry(open.behind, -open.facing)
	place(player, open.front)
	for i in range(60 * 4):
		await physics_frame
		if first.awareness_level == JaffaPerception.Level.ALERTED:
			break
	await frames(2)
	assert(first.awareness_level == JaffaPerception.Level.ALERTED)
	assert(second.awareness_level == JaffaPerception.Level.ALERTED, "The alert spreads to a neighbour")
	assert(second.perception.stimulus.distance_to(player.global_position) < 1.0)
	await retire(first)
	await retire(second)

	# --- Target lost: investigate the last seen position, search around it, then resume the patrol
	# in order.
	var hideout := farthest_from(route)
	var clearance := INF
	for point in route:
		clearance = minf(clearance, hideout.distance_to(point))
	place(player, hideout)
	var heading := route[1] - route[0]
	heading.y = 0.0
	s = sentry(route[0], heading.normalized(), route)
	assert(clearance > s.sight_range + 2.0, "Fixture has a room beyond sight of the route")
	await frames(60 * 3)
	assert(s.current_state == JaffaAI.State.PATROL and s.awareness_level == 0)
	var last_seen := route[0]
	place(player, last_seen)
	s.health_component.take_damage(5.0, player)
	place(player, hideout)
	assert(s.awareness_level == JaffaPerception.Level.ALERTED)
	var started := false
	for i in range(60 * 5):
		await physics_frame
		if s.investigating:
			started = true
			break
	assert(started and s.current_state == JaffaAI.State.CHASE, "Lost target becomes a search")
	assert(s.awareness_level == JaffaPerception.Level.SUSPICIOUS and s.current_target == null)
	var resume_index := s.patrol_index
	var arrived := false
	for i in range(60 * 25):
		await physics_frame
		if flat_distance(s.global_position, last_seen) < 2.0:
			arrived = true
			break
	assert(arrived, "The sentry walks to the last seen position")
	var waited := 0
	while s.investigating and waited < 60 * 40:
		await physics_frame
		waited += 1
		assert(
			flat_distance(s.global_position, last_seen) < s.search_radius * 2.0 + 2.0,
			"It searches around where it arrived"
		)
	assert(
		not s.investigating and waited >= int((s.investigate_wait - 0.5) * 60.0),
		"Search ends: investigating=%s waited=%d points left=%d" % [
			s.investigating, waited, s._search_route.size()
		]
	)
	assert(s.current_state == JaffaAI.State.PATROL and s.awareness_level == 0)
	assert(s.patrol_index == resume_index, "The patrol keeps its place in the route")
	var reached: Array[int] = []
	s.patrol_waypoint_reached.connect(func(index: int) -> void: reached.append(index))
	for i in range(60 * 40):
		await physics_frame
		if not reached.is_empty():
			break
	assert(not reached.is_empty() and reached[0] == resume_index, "It continues to its next waypoint")
	await retire(s)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS sentry perception: walls, decks, cone, notice time, forgetting, smoke, doors, damage, spread, search and resume")
	await preload("res://tests/support/finish.gd").success(self)
