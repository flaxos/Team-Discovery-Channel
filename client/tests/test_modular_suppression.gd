extends "res://tests/test_jaffa_prop_cover.gd"
## Production modular mission plus real ballistic traces through its authored crate cover.


func near_miss_direction(origin: Vector3, guard: JaffaAI) -> Vector3:
	var torso := guard.global_position + Vector3.UP * 1.05
	var side := (torso - origin).cross(Vector3.UP).normalized()
	for offset: float in [-0.78, 0.78, -1.02, 1.02]:
		var point := torso + side * offset
		var query := PhysicsRayQueryParameters3D.create(origin, point, 1 | 4 | 128)
		if room.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return (point - origin).normalized()
	return Vector3.ZERO


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	net.request_start_game()
	await frames(3)
	room = main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	player.set_physics_process(false)
	for enemy: Node in room.enemies.get_children():
		enemy.queue_free()
	probe = Node3D.new()
	room.add_child(probe)
	await frames(4)
	var setup := crate_setup()
	assert(not setup.is_empty())
	place(player, setup.threat)
	var guard := sentry(setup.start, (setup.start - setup.threat).normalized())
	guard.sight_range = 0.1
	guard.proximity_radius = 0.1
	await frames(4)
	var weapon := player.current_weapon
	weapon.noise_radius = 0.0 # Isolate physical pressure from the separately tested hearing system.
	var origin := player.global_position + Vector3.UP * 1.05
	var direction := near_miss_direction(origin, guard)
	assert(direction != Vector3.ZERO, "The fixture has a clean line next to the guard")
	var health := guard.health_component.current_health

	weapon._perform_shot(origin, direction)
	assert(not guard.is_suppressed, "A single miss does not suppress")
	await frames(50)
	weapon._perform_shot(origin, direction)
	assert(not guard.is_suppressed, "An old pass does not build up pressure")
	weapon._perform_shot(origin, direction)
	assert(guard.is_suppressed and guard.is_crouching, "Two nearby rounds make the guard duck")
	assert(guard.health_component.current_health == health, "A near miss does no damage")
	assert(guard.perception.target == null and guard.perception.stimulus == Vector3.INF, "Pressure conveys no sighting")
	assert(guard._suppression_cover.is_finite(), "Guard has a short route to the authored crate")
	guard.current_target = player
	assert(guard._has_line_of_sight(player), "The guard could fire from its exposed position")
	guard._dispatch_single_plasma_bolt()
	assert(shots == 0, "Suppression cancels a queued staff shot")
	guard.current_target = null
	var cover := guard._suppression_cover
	var distance := guard.global_position.distance_to(cover)
	await frames(38)
	assert(guard.is_suppressed and guard.global_position.distance_to(cover) < distance - 0.30, "Guard moves towards the crate while ducked")
	assert(shots == 0)
	await frames(50)
	assert(not guard.is_suppressed, "Guard returns to ordinary behavior when fire stops")
	await frames(65)
	assert(guard._suppression_recovery == 0.0)

	# The exposed guard is now repositioned to an authored protected location.
	place(guard, setup.spot)
	guard._set_crouching(true)
	await frames(4)
	guard._set_crouching(true)
	assert(LevelNavigator.prop_blocks(setup.prop, guard.global_position, player.global_position))
	var protected_torso := guard.global_position + Vector3.UP * 0.60
	var blocked_ray := (protected_torso - origin).normalized()
	weapon._perform_shot(origin, blocked_ray)
	weapon._perform_shot(origin, blocked_ray)
	assert(guard._incoming_fire_window == 0.0 and not guard.is_suppressed, "Cover blocks pressure as well as damage")
	assert(guard.health_component.current_health == health)

	place(guard, setup.start)
	await frames(4)
	direction = near_miss_direction(origin, guard)
	assert(direction != Vector3.ZERO)
	var zat := WeaponZat.new()
	player.weapon_holder.add_child(zat)
	zat.noise_radius = 0.0
	zat._perform_shot(origin, direction)
	zat._perform_shot(origin, direction)
	assert(not guard.is_suppressed and guard._incoming_fire_window == 0.0, "A missed Zat shot does not suppress")
	weapon._perform_shot(origin, direction)
	weapon._perform_shot(origin, direction)
	assert(guard.is_suppressed)
	# Exercise budget refresh without moving the open ray fixture along with the guard.
	for tick in range(181):
		if tick % 8 == 0:
			guard.register_incoming_fire(origin)
		await physics_frame
	assert(not guard.is_suppressed and guard._suppression_recovery > 0.0, "Continuous pressure has a hard cap")
	guard.register_incoming_fire(origin)
	guard.register_incoming_fire(origin)
	assert(not guard.is_suppressed, "Recovery prevents immediate pinning again")
	await frames(66)
	guard.register_incoming_fire(origin)
	guard.register_incoming_fire(origin)
	assert(guard.is_suppressed)
	guard.health_component.apply_zat_shot(player)
	assert(guard.current_state == JaffaAI.State.STUNNED and not guard.is_suppressed, "Incapacitation clears pressure")
	print("PASS modular suppression: real shots, no damage on misses, cover, Zat exclusion, bounded pin and stun")
	net.disconnect_game()
	await frames(10)
	await preload("res://tests/support/finish.gd").success(self)
