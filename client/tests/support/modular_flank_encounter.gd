extends RefCounted
## Locate a real adjacent-room sightline with another usable entrance in an existing layout.
## Only ordinary doors are opened through the host AI interface; layout data stays untouched.


static func choose(room: ModularMission) -> Dictionary:
	var level := room.level
	var probe := CharacterBody3D.new()
	room.add_child(probe)
	var route := LevelNavigator.new(probe, level)
	for i in range(level.layout.connections.size()):
		if route._is_connection_locked(i):
			continue
		var edge := level.layout.connections[i]
		for pair: Array in [[edge.from_instance, edge.to_instance], [edge.to_instance, edge.from_instance]]:
			var known := level.marker(pair[1], &"entry")
			var start := route._connection_approach_points(i, pair[0])[0]
			var forward := known - start
			forward.y = 0.0
			if forward.length() < 3.5:
				continue
			var side := forward.normalized().cross(Vector3.UP) * 0.65
			var lead := NavigationServer3D.map_get_closest_point(level.navigation_map, start + side)
			var trailing := NavigationServer3D.map_get_closest_point(level.navigation_map, start - side)
			if lead.distance_to(start + side) > 0.5 or trailing.distance_to(start - side) > 0.5:
				continue
			probe.global_position = trailing + Vector3(0, 0.05, 0)
			if route.plan_flank(known).is_empty():
				continue
			var door := level.get_node_or_null("Door_%03d" % i) as ModularDoor
			if door != null:
				probe.global_position = start + Vector3(0, 0.05, 0)
				if not door.open_for(probe):
					continue
				await room.get_tree().physics_frame
			var query := PhysicsRayQueryParameters3D.create(lead + Vector3.UP * JaffaAI.EYE_HEIGHT, known + Vector3.UP * 1.5, 1)
			var other := PhysicsRayQueryParameters3D.create(trailing + Vector3.UP * JaffaAI.EYE_HEIGHT, known + Vector3.UP * 1.5, 1)
			if not room.get_world_3d().direct_space_state.intersect_ray(query).is_empty() or not room.get_world_3d().direct_space_state.intersect_ray(other).is_empty():
				continue
			var park := known
			for item in level.layout.instances:
				var point := level.marker(item.id, &"entry")
				if point.distance_to(start) > park.distance_to(start):
					park = point
			if park.distance_to(start) < 26.0:
				continue
			var result := {"lead": lead, "trailing": trailing, "known": known, "park": park,
				"rooms": route.flank_rooms.duplicate(), "end": route.destination}
			probe.queue_free()
			return result
	probe.queue_free()
	return {}


static func spawn(room: ModularMission, encounter: Dictionary) -> Array[JaffaAI]:
	var guards: Array[JaffaAI] = []
	for rank in range(2):
		var guard := load("res://scenes/entities/JaffaGuard.tscn").instantiate() as JaffaAI
		guard.name = "FlankLead" if rank == 0 else "FlankTrail"
		guard.position = room.enemies.to_local(encounter.lead if rank == 0 else encounter.trailing) + Vector3(0, 0.05, 0)
		guard.formation_rank = rank
		guard.notice_time_near = 0.05
		guard.notice_time_far = 0.05
		guard.fire_timer = 100000.0
		var offset: Vector3 = encounter.known - guard.position - room.enemies.global_position
		guard.rotation.y = atan2(-offset.x, -offset.z)
		room.enemies.add_child(guard, true)
		guard.start_patrol([guard.global_position])
		guards.append(guard)
	return guards
