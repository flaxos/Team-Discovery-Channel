extends SceneTree
## Headless contract proof for OW-0 (decision D-006):
## Separate exterior terrain scene joins an enclosed modular LevelLayout strictly at declared
## doorways without relaxing interior enclosure validation, sharing one NavigationServer3D map
## for bidirectional outdoor <-> interior traversal (including 2 km two-world offset).

const MISSION_SCENE := "res://scenes/mission/OutdoorGateSiteMission.tscn"
const BUNKER_LAYOUT := "res://resources/levels/outdoor_gate_site_bunker.tres"
const MISSION_DEF := "res://resources/missions/outdoor_gate_site.tres"


func _init() -> void:
	call_deferred(&"_run")


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _run() -> void:
	# 1. Interior layout remains a 100% pure, sealed modular LevelLayout.
	var layout := load(BUNKER_LAYOUT) as LevelLayout
	assert(layout != null, "Bunker layout loads")
	assert(LevelLayoutValidator.validate(layout).is_empty(), "Bunker layout passes pure interior validation")

	var sealed := LevelAssembly.new()
	sealed.layout = layout
	root.add_child(sealed)
	if not sealed.ready_for_navigation:
		await sealed.navigation_ready
	assert(sealed.ready_for_navigation and sealed.last_errors.is_empty(), "Sealed bunker bakes with zero errors: %s" % [sealed.last_errors])
	var south_cap := sealed.get_node("bunker_entry/Structure/PortalClosures/south") as StaticBody3D
	assert(south_cap != null and south_cap.collision_layer == 1, "Unopened bunker_entry/south remains sealed in pure interior mode")
	sealed.queue_free()
	await _frames(3)

	# 2. Invalid exterior portal declarations are rejected cleanly.
	var bad_portal := LevelAssembly.new()
	bad_portal.layout = layout
	bad_portal.register_exterior_portal(&"bunker_entry", &"north", true)  # already connected indoors
	root.add_child(bad_portal)
	await _frames(8)
	assert(not bad_portal.ready_for_navigation, "Already-connected interior socket cannot be declared exterior")
	assert(not bad_portal.last_errors.is_empty(), "Reports exterior portal error")
	bad_portal.queue_free()
	await _frames(3)

	# 3. MissionDefinition rejects exterior objectives/patrols when exterior_markers is empty.
	var bad_def := (load(MISSION_DEF) as MissionDefinition).duplicate(true) as MissionDefinition
	bad_def.exterior_markers = PackedStringArray()
	var def_errors := bad_def.validate()
	assert(not def_errors.is_empty(), "MissionDefinition rejects undeclared exterior markers")

	# 4. Verify live OW-0 boundary contract at origin AND at 2 km world offset (D-002 / GT-1).
	for world_offset: Vector3 in [Vector3.ZERO, Vector3(2000.0, 0.0, 0.0)]:
		var mission := (load(MISSION_SCENE) as PackedScene).instantiate() as ModularMission
		mission.position = world_offset
		root.add_child(mission)
		if not mission.is_started:
			await mission.started
		await _frames(4)

		assert(mission.setup_errors.is_empty(), "Outdoor mission starts with zero setup errors at %s: %s" % [world_offset, mission.setup_errors])
		assert(mission.level.ready_for_navigation, "Interior LevelAssembly ready")
		assert(mission.outdoor != null and mission.outdoor.ready_for_navigation, "OutdoorBoundary ready")
		assert(mission.outdoor.last_errors.is_empty(), "OutdoorBoundary zero errors: %s" % [mission.outdoor.last_errors])
		assert(mission.outdoor.navigation != null and mission.outdoor.navigation.get_navigation_map() == mission.level.navigation_map, "Exterior NavigationRegion3D shares LevelAssembly navigation_map")
		assert(mission.outdoor.doorway_link != null and mission.outdoor.doorway_link.get_navigation_map() == mission.level.navigation_map, "OutdoorDoorwayLink shares navigation_map")

		# Declared doorway is open with a runtime ModularDoor; other unconnected sockets stay sealed.
		var open_cap := mission.level.get_node("bunker_entry/Structure/PortalClosures/south") as StaticBody3D
		var sealed_east_cap := mission.level.get_node("bunker_entry/Structure/PortalClosures/east") as StaticBody3D
		assert(open_cap.collision_layer == 0, "Declared exterior doorway portal closure opened")
		assert(sealed_east_cap.collision_layer == 1, "Undeclared exterior socket stays sealed")
		var ext_door := mission.outdoor.exterior_door()
		assert(ext_door != null and not ext_door.locked, "Exterior doorway mounts unlocked ModularDoor")

		# Round-trip navigation across the doorway boundary.
		var arrival := mission.outdoor.marker_position(&"gate_arrival")
		var bunker_entry := mission.level.marker(&"bunker_entry", &"entry")
		var bunker_cmd := mission.level.marker(&"bunker_command", &"entry")
		var path_in := mission.level.local_path(arrival, bunker_cmd)
		var path_out := mission.level.local_path(bunker_cmd, arrival)
		assert(not path_in.is_empty() and path_in[-1].distance_to(bunker_cmd) < 0.65, "Continuous outdoor -> interior path reaches bunker_command")
		assert(not path_out.is_empty() and path_out[-1].distance_to(arrival) < 0.65, "Continuous interior -> outdoor path returns to gate_arrival")

		# Live NPC steering (LevelNavigator) crosses doorway, triggers ModularDoor, and returns outside.
		var mover := (load("res://scenes/entities/JaffaGuard.tscn") as PackedScene).instantiate() as JaffaAI
		mover.name = "OW0NavProbe"
		mover.profile = JaffaAI.Profile.SENTRY
		mover.position = mission.enemies.to_local(mission.outdoor.marker_position(&"bunker_threshold") + Vector3(0.0, 0.05, 0.0))
		mission.enemies.add_child(mover)
		await _frames(3)
		var nav := LevelNavigator.new(mover, mission.level)
		var reached_inside := false
		for _step in range(360):
			var next_pt := nav.next_position(bunker_entry, 1.0 / 60.0)
			var delta_v := next_pt - mover.global_position
			delta_v.y = 0.0
			if delta_v.length_squared() > 0.001:
				mover.velocity = delta_v.normalized() * 5.0
				mover.move_and_slide()
			await physics_frame
			if mover.global_position.distance_to(bunker_entry) < 1.1:
				reached_inside = true
				break
		assert(reached_inside, "AI steered by LevelNavigator crosses outdoor threshold through exterior ModularDoor into bunker_entry")
		assert(ext_door.is_open, "Crossing doorway opened ExteriorDoor ModularDoor")

		nav.reset()
		var returned_outside := false
		var threshold := mission.outdoor.marker_position(&"bunker_threshold")
		for _step in range(360):
			var next_pt := nav.next_position(threshold, 1.0 / 60.0)
			var delta_v := next_pt - mover.global_position
			delta_v.y = 0.0
			if delta_v.length_squared() > 0.001:
				mover.velocity = delta_v.normalized() * 5.0
				mover.move_and_slide()
			await physics_frame
			if mover.global_position.distance_to(threshold) < 1.1:
				returned_outside = true
				break
		assert(returned_outside, "AI steered by LevelNavigator returns from bunker_entry back out to exterior terrain")

		mission.queue_free()
		await _frames(5)

	print("PASS test_ow0_outdoor_boundary")
	quit(0)
