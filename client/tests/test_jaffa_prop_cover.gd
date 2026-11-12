extends SceneTree
## Real cover from authored props (roadmap TA-1) on the integrated fixture, through the production
## mission, JaffaAI and LevelNavigator. The test places operatives and fresh sentries and reads
## state; movement, crouching, perception and fire are the production controller. Positions come
## from the level's own geometry.
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var probe: Node3D
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


func floor_near(spot: Vector3) -> Vector3:
	var point := NavigationServer3D.map_get_closest_point(level.navigation_map, spot)
	return point if point.distance_to(spot) < 0.8 else Vector3.INF


func clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func sentry(at: Vector3, facing: Vector3) -> JaffaAI:
	serial += 1
	var jaffa := (load(JAFFA) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "Guard%d" % serial
	jaffa.position = room.enemies.to_local(at + Vector3(0, 0.05, 0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var points: Array[Vector3] = [at]
	jaffa.start_patrol(points)
	jaffa.staff_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void: shots += 1)
	return jaffa


func retire(jaffa: JaffaAI) -> void:
	jaffa.queue_free()
	await frames(2)


## A crate, a threat spot 8-10 m from it with a clear view over it, and a start 2.5 m on the
## threat's side of it, from where the crate is the nearest qualifying cover.
func crate_setup() -> Dictionary:
	for prop in LevelNavigator.cover_props(level):
		var centre := prop.global_position
		for step in range(16):
			var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * step / 16.0)
			for distance: float in [9.0, 8.0, 10.0]:
				var threat := floor_near(centre + direction * distance)
				var start := floor_near(centre + direction * 2.5)
				if threat == Vector3.INF or start == Vector3.INF or absf(threat.y - centre.y) > 0.5:
					continue
				probe.global_position = start
				var found := LevelNavigator.prop_cover(level, probe, threat, 10.0)
				if found.is_empty() or found["prop"] != prop:
					continue
				var spot: Vector3 = found["spot"]
				if clear(spot + Vector3(0, JaffaAI.EYE_HEIGHT, 0), threat + Vector3(0, 1.5, 0)):
					return {"prop": prop, "threat": threat, "start": start, "spot": spot, "direction": direction}
	return {}


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
	probe = Node3D.new()
	room.add_child(probe)
	for enemy in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)

	# --- Which attachments count: solid low cover, never a marker or a tall machine.
	var props := LevelNavigator.cover_props(level)
	assert(props.size() >= 3, "The fixture's cargo crates are cover: %d" % props.size())
	for prop in props:
		var bounds: AABB = prop.get_meta("attachment_bounds")
		assert(prop is LevelPlaceholderProp, "Cover is solid: " + str(prop.name))
		assert(bounds.size.y >= LevelNavigator.LOW_COVER_MIN and bounds.size.y <= LevelNavigator.LOW_COVER_MAX)
	for node in level.find_children("cover_01", "Node3D", true, false):
		assert(not node in props, "A cover marker is not a prop")

	# --- The chosen spot: behind the prop, away from the threat, blocked at crouched height.
	var setup := crate_setup()
	assert(not setup.is_empty(), "Fixture has a crate with a threat spot and an exposed start")
	var prop: Node3D = setup.prop
	var threat: Vector3 = setup.threat
	var spot: Vector3 = setup.spot
	assert(LevelNavigator.prop_blocks(prop, spot, threat), "The prop blocks the line at torso height")
	assert(spot.distance_to(threat) > prop.global_position.distance_to(threat), "Behind, not in front")
	assert(spot.distance_to(threat) >= 4.0)
	assert(not LevelNavigator.prop_blocks(prop, setup.start, threat), "The start is exposed")
	probe.global_position = setup.start
	var other_side := floor_near(prop.global_position - (setup.direction as Vector3) * 9.0)
	if other_side != Vector3.INF:
		var flipped := LevelNavigator.prop_cover(level, probe, other_side, 10.0)
		if not flipped.is_empty() and flipped["prop"] == prop:
			assert(flipped["spot"].distance_to(spot) > 1.0, "A threat from the other side flips the spot")
	var taken: Array[Vector3] = [spot]
	var second := LevelNavigator.prop_cover(level, probe, threat, 10.0, taken)
	assert(second.is_empty() or second["spot"].distance_to(spot) > 1.0, "A held spot is not given twice")

	# --- Fighting from it: run there, crouch, stand to fire over it, keep seeing the target.
	place(player, threat)
	var s := sentry(setup.start, (threat - setup.start).normalized())
	await frames(10)
	s.health_component.take_damage(5.0, player)
	await frames(2)
	assert(s.current_state == JaffaAI.State.COVER and s.cover_prop == prop, "It takes the crate")
	assert(s.tactical_destination.distance_to(spot) < 0.5)
	var arrived := false
	for i in range(60 * 6):
		await physics_frame
		if Vector2(s.global_position.x - spot.x, s.global_position.z - spot.z).length() < 1.2:
			arrived = true
			break
	assert(arrived, "It reaches the spot behind the crate")
	shots = 0
	var crouched := 0
	var hits_before := player.health_component.current_health
	for i in range(60 * 8):
		await physics_frame
		if s.is_crouching:
			crouched += 1
		assert(s.current_state == JaffaAI.State.COVER and not s.investigating, "It holds the crate")
	assert(shots >= 2, "It stands up to fire over the crate: %d shots" % shots)
	assert(crouched > 60 * 8 / 2, "It spends most of the time down: %d frames" % crouched)
	assert(player.health_component.current_health < hits_before, "Its fire reaches the target")
	assert(s.awareness_level == JaffaPerception.Level.ALERTED and s.current_target == player)
	assert(LevelNavigator.prop_blocks(prop, s.global_position, player.global_position))

	# --- Flanked: once the target has an angle round the crate, it moves.
	var flank := Vector3.INF
	for step in range(16):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * step / 16.0)
		var candidate := floor_near(s.global_position + direction * 6.0)
		if (
			candidate != Vector3.INF
			and absf(candidate.y - s.global_position.y) < 0.5
			and not LevelNavigator.prop_blocks(prop, s.global_position, candidate)
			and clear(s.global_position + Vector3(0, 1.5, 0), candidate + Vector3(0, 1.5, 0))
		):
			flank = candidate
			break
	assert(flank != Vector3.INF, "Fixture has a flanking spot")
	var held := s.tactical_destination
	place(player, flank)
	var moved := false
	for i in range(60 * 3):
		await physics_frame
		if s.tactical_destination.distance_to(held) > 0.5 or s.current_state != JaffaAI.State.COVER:
			moved = true
			break
	assert(moved, "A flanked Jaffa leaves the useless cover")
	if s.cover_prop != null:
		assert(LevelNavigator.prop_blocks(s.cover_prop, s.tactical_destination, flank), "New cover faces the flank")
	await retire(s)

	# --- No prop in reach: the earlier behaviour (hold, or a room cover marker) is unchanged.
	var nearest_prop := INF
	var lonely := Vector3.INF
	for item in level.layout.instances:
		var at := level.marker(item.id, &"patrol")
		if floor_near(at) == Vector3.INF:
			continue
		nearest_prop = INF
		for candidate_prop in props:
			nearest_prop = minf(nearest_prop, candidate_prop.global_position.distance_to(at))
		if nearest_prop > 22.0:
			lonely = at
			break
	assert(lonely != Vector3.INF, "Fixture has a room far from any crate")
	place(player, lonely + Vector3(4, 0, 0))
	s = sentry(lonely, Vector3.RIGHT)
	await frames(10)
	s.health_component.take_damage(5.0, player)
	await frames(2)
	assert(s.cover_prop == null, "No prop cover far from any prop")
	assert(
		s.current_state in [JaffaAI.State.COMBAT, JaffaAI.State.ADVANCE],
		"The lead suppresses or advances, as before: %d" % s.current_state
	)
	await retire(s)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS prop cover: cover attachments, spot behind the prop, crouch and fire over it, flanked relocation, fallback")
	await preload("res://tests/support/finish.gd").success(self)
