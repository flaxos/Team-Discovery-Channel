extends SceneTree
## Hearing and searching for patrolling sentries (roadmap ST-2) on the integrated fixture,
## through the production mission, weapons, explosives and JaffaAI. The test places operatives,
## fresh sentries and charges, fires real weapons and reads state. Positions come from the
## level's own geometry.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var probe: Node3D
var serial := 0


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


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func blocked(from: Vector3, to: Vector3) -> bool:
	var space := room.get_world_3d().direct_space_state
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0, eye, 0), to + Vector3(0, aim, 0), 1
			)
			if space.intersect_ray(query).is_empty():
				return false
	return true


func marker_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for item in level.layout.instances:
		for id: StringName in [&"entry", &"patrol", &"cover"]:
			var spot := level.marker(item.id, id)
			if on_floor(spot):
				spots.append(spot)
	return spots


## A sentry post and a spot on the same deck 10-20 m away that the sentry cannot see from
## there, with no wall between them (behind it), and one with a wall between them.
func listening_setup(walled: bool) -> Dictionary:
	var spots := marker_spots()
	for at in spots:
		for spot in spots:
			var distance := at.distance_to(spot)
			if absf(spot.y - at.y) > 1.0 or distance < 10.0 or distance > 20.0:
				continue
			if blocked(at, spot) != walled:
				continue
			var away := Vector3(at.x - spot.x, 0, at.z - spot.z).normalized()
			return {"at": at, "facing": away if not walled else -away, "spot": spot}
	return {}


func farthest_from(point: Vector3) -> Vector3:
	var best := point
	for spot in marker_spots():
		if spot.distance_to(point) > best.distance_to(point):
			best = spot
	return best


func sentry(at: Vector3, facing: Vector3, route: Array[Vector3] = []) -> JaffaAI:
	serial += 1
	var jaffa := (load(JAFFA) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "Listener%d" % serial
	jaffa.position = room.enemies.to_local(at + Vector3(0, 0.05, 0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var points: Array[Vector3] = [at]
	if not route.is_empty():
		points = route.duplicate()
	jaffa.start_patrol(points)
	assert(jaffa.is_in_group(&"noise_listeners"), "Sentries listen")
	return jaffa


func retire(jaffa: JaffaAI) -> void:
	jaffa.queue_free()
	await frames(2)


## Fires one shot upwards from where the operative stands, with a fresh weapon of `kind`.
func shoot(kind: GDScript) -> void:
	var gun := kind.new() as WeaponBase
	player.add_child(gun)
	await frames(1)
	assert(gun.try_fire(1.0, Vector3(0.2, 1.0, 0.0).normalized()), "The weapon fires")
	gun.queue_free()


func radius_of(kind: GDScript) -> float:
	var gun := kind.new() as WeaponBase
	var radius := gun.noise_radius
	gun.free()
	return radius


func seen_from(jaffa: JaffaAI, spot: Vector3) -> bool:
	probe.global_position = spot
	return jaffa.perception.can_see(probe)


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
	probe = Node3D.new()
	room.add_child(probe)
	player.health_component.current_health = 1000000.0
	var route: Array[Vector3] = []
	for id: String in room.definition.patrols[0].rooms:
		route.append(level.marker(StringName(id), &"patrol"))
	for enemy in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)
	var open := listening_setup(false)
	assert(not open.is_empty(), "Fixture has an open spot behind a sentry post")
	var walled := listening_setup(true)
	assert(not walled.is_empty(), "Fixture has a spot behind a wall from a sentry post")
	var far := farthest_from(open.at)
	assert(far.distance_to(open.at) > 30.0, "Fixture has a spot beyond the loudest small-arms radius")
	var s: JaffaAI

	# --- Radii are per weapon: suppressed is short, explosives are long.
	assert(radius_of(WeaponMP5) < 10.0 and radius_of(WeaponP90) >= 25.0)
	assert(radius_of(WeaponM249) > radius_of(WeaponP90) and radius_of(WeaponZat) < 15.0)
	assert(C4Satchel.NOISE_RADIUS > 40.0 and ClaymoreMine.NOISE_RADIUS > 30.0)

	# --- A suppressed shot behind the sentry, out of sight, is not heard.
	place(player, open.spot)
	s = sentry(open.at, open.facing)
	await frames(10)
	assert(not s.perception.can_see(player), "Precondition: the shooter is unseen")
	var start := s.global_position
	await shoot(WeaponMP5)
	assert(await watch(s, 3.0) == JaffaPerception.Level.UNAWARE, "A suppressed shot at this range is silent")
	assert(s.global_position.distance_to(start) < 1.0 and not s.investigating)

	# --- An unsuppressed shot from the same place is heard: suspicious, and it goes to look.
	await shoot(WeaponP90)
	await frames(2)
	assert(s.awareness_level == JaffaPerception.Level.SUSPICIOUS and s.investigating, "The shot is heard")
	assert(s.perception.stimulus.distance_to(player.global_position) < 1.5, "It goes to the shot")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Hearing a noise is not being spotted")
	var shot_at := player.global_position
	place(player, far)
	var closest := flat_distance(s.global_position, shot_at)
	for i in range(60 * 4):
		await physics_frame
		closest = minf(closest, flat_distance(s.global_position, shot_at))
	assert(closest < flat_distance(start, shot_at) - 3.0, "It walks towards the noise")
	assert(s.awareness_level < JaffaPerception.Level.ALERTED)
	await retire(s)

	# --- Beyond the radius nothing is heard.
	place(player, far)
	s = sentry(open.at, open.facing)
	await frames(10)
	await shoot(WeaponP90)
	assert(await watch(s, 2.0) == JaffaPerception.Level.UNAWARE, "Out of range")
	await retire(s)

	# --- Walls do not muffle a shot (no propagation model): a shot behind a wall is heard.
	place(player, walled.spot)
	s = sentry(walled.at, walled.facing)
	await frames(10)
	assert(not s.perception.can_see(player))
	await shoot(WeaponP90)
	await frames(2)
	assert(s.investigating and s.awareness_level == JaffaPerception.Level.SUSPICIOUS)
	await retire(s)

	# --- A fighting sentry keeps its target; noise does not distract it.
	place(player, open.spot)
	s = sentry(open.at, open.facing)
	await frames(10)
	s.health_component.take_damage(5.0, player)
	await frames(2)
	assert(s.awareness_level == JaffaPerception.Level.ALERTED and s.current_target == player)
	await shoot(WeaponM249)
	await frames(2)
	assert(s.awareness_level == JaffaPerception.Level.ALERTED and not s.investigating)
	await retire(s)

	# --- A C4 blast is heard from farther than any small arm.
	place(player, far)
	s = sentry(open.at, open.facing)
	await frames(10)
	var charge := (load("res://scenes/props/C4Satchel.tscn") as PackedScene).instantiate() as C4Satchel
	charge.planter = player
	room.add_child(charge)
	var blast_at := Vector3.INF
	for spot in marker_spots():
		var d := spot.distance_to(s.global_position)
		if d > radius_of(WeaponP90) + 1.0 and d < C4Satchel.NOISE_RADIUS - 1.0:
			blast_at = spot
	assert(blast_at != Vector3.INF, "Fixture has a spot beyond rifle range but within a blast's")
	charge.global_position = blast_at + Vector3(0, 0.3, 0)
	await frames(45)
	assert(charge.is_armed)
	place(player, blast_at)
	await shoot(WeaponP90)
	place(player, far)
	await frames(2)
	assert(not s.investigating, "A P90 is not heard that far")
	var blast_point := charge.global_position
	charge.detonate()
	await frames(2)
	assert(s.investigating, "The blast is heard")
	assert(s.perception.stimulus.distance_to(blast_point) < 1.5)
	await retire(s)

	# --- The search: look at the noise, visit points around it, then resume the route in order.
	var post := route[0]
	var heading := route[1] - route[0]
	heading.y = 0.0
	s = sentry(post, heading.normalized(), route)
	await frames(60 * 2)
	var resume_index := s.patrol_index
	var source := Vector3.INF
	for spot in marker_spots():
		var d := spot.distance_to(s.global_position)
		if absf(spot.y - post.y) < 1.0 and d > 8.0 and d < 20.0 and not seen_from(s, spot):
			source = spot
			break
	assert(source != Vector3.INF, "Fixture has an unseen spot within earshot of the route")
	place(player, source)
	await shoot(WeaponP90)
	place(player, far)
	assert(s.investigating)
	var arrived := false
	for i in range(60 * 25):
		await physics_frame
		if s._search_wait >= 0.0:
			arrived = true
			break
	assert(arrived, "It reaches the noise and starts looking")
	var centre := s.global_position
	var planned := s._search_route.duplicate()
	assert(planned.size() >= 2, "It plans at least two search points: %d" % planned.size())
	for point: Vector3 in planned:
		assert(flat_distance(point, centre) >= 2.4 and flat_distance(point, centre) <= s.search_radius + 0.5)
		assert(absf(point.y - centre.y) < 1.0 and on_floor(point))
	var visited := 0
	var waited := 0
	while s.investigating and waited < 60 * 40:
		await physics_frame
		waited += 1
		if visited < planned.size() and flat_distance(s.global_position, planned[visited]) < 1.2:
			visited += 1
		assert(flat_distance(s.global_position, centre) < s.search_radius * 2.0 + 1.0, "It searches near the noise")
	assert(not s.investigating and visited == planned.size(), "Every search point is visited")
	assert(waited >= int((s.investigate_wait + s.search_look_time * planned.size()) * 60.0) - 30)
	assert(s.current_state == JaffaAI.State.PATROL and s.awareness_level == JaffaPerception.Level.UNAWARE)
	assert(s.patrol_index == resume_index, "The patrol keeps its place in the route")
	await retire(s)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS sentry hearing: per-weapon radii, suppressed silence, heard shot investigated, range, walls, fighting sentry, C4 blast, search points and resume")
	await preload("res://tests/support/finish.gd").success(self)
