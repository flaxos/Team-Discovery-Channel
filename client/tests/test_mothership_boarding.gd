extends SceneTree
## Sprint 32: Ha'tak mothership boarding route, bulkhead/door/cargo prop families,
## two-deck layout with Goa'uld theme, reciprocal R16 transport rings breach,
## and complete entry/objective/return mission loop.

const LAYOUT_PATH := "res://resources/levels/ai2_goauld_mothership_boarding.tres"
const MISSION_DEF_PATH := "res://resources/missions/goauld_mothership_boarding.tres"
const MISSION_SCENE_PATH := "res://scenes/mission/GoauldMothershipBoardingMission.tscn"


func _init() -> void:
	call_deferred("run")


func assemble(layout: LevelLayout) -> LevelAssembly:
	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
	return assembly


func run() -> void:
	# 1. Layout & Theme Validation
	var layout: LevelLayout = load(LAYOUT_PATH)
	assert(layout != null, "Mothership layout loads")
	var layout_errors := LevelLayoutValidator.validate(layout)
	assert(layout_errors.is_empty(), "Layout validator passes: " + str(layout_errors))

	var transport_errors := LevelLayoutValidator.validate_transports(layout, true)
	assert(transport_errors.is_empty(), "Transport validator passes: " + str(transport_errors))

	var theme := LevelThemeResolver.registry().get(&"goauld") as LevelVisualTheme
	assert(theme != null, "goauld theme registered")
	assert(theme.art_status == "authored", "goauld has authored art status")

	# 2. Assembly, Enclosure and World Composition
	var assembly := await assemble(layout)
	var enclosure_errors := LevelEnclosureValidator.validate(assembly)
	assert(enclosure_errors.is_empty(), "LevelEnclosureValidator passes: " + str(enclosure_errors))
	var world_errors := LevelRoomComposer.validate_world(assembly)
	assert(world_errors.is_empty(), "LevelRoomComposer.validate_world passes: " + str(world_errors))

	# 3. Prop Families & Presets Verification
	var cargo_bay := assembly.get_node(^"cargo_bay") as LevelModule
	assert(cargo_bay != null, "cargo_bay module present")
	for crate_id: String in ["crate_01", "crate_02", "crate_03"]:
		var crate := cargo_bay.get_node_or_null("Attachments/RoomContent/" + crate_id) as LevelPlaceholderProp
		assert(crate != null, "Cargo crate present in cargo bay: " + crate_id)
		var body := crate.get_node_or_null(^"Structure/Body") as StaticBody3D
		assert(body != null and body.collision_layer == 1, "Crate has layer 1 collision")
		var shape := body.get_child(0) as CollisionShape3D
		assert(shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(1.4, 1.2, 1.4)))

	var checkpoint := assembly.get_node(^"interior_checkpoint") as LevelModule
	assert(checkpoint != null, "interior_checkpoint module present")
	var bulkhead := checkpoint.get_node_or_null(^"Attachments/RoomContent/door_control") as LevelPlaceholderProp
	assert(bulkhead != null, "Mothership boarding bulkhead present in checkpoint")
	var b_body := bulkhead.get_node_or_null(^"Structure/Body") as StaticBody3D
	assert(b_body != null and b_body.collision_layer == 1, "Bulkhead has layer 1 collision")

	var chk_console := checkpoint.get_node_or_null(^"Attachments/RoomContent/console") as LevelPlaceholderProp
	assert(chk_console != null, "Terminal console present in interior checkpoint")

	# 4. R16 Reciprocal Transport Rings Verification
	var ring_lower_mod := assembly.get_node(^"ring_lower") as LevelModule
	var ring_upper_mod := assembly.get_node(^"ring_upper") as LevelModule
	assert(ring_lower_mod != null and ring_upper_mod != null, "Both ring modules present")

	var bind_errors := LevelTransportBindings.bind_rings(layout, assembly)
	assert(bind_errors.is_empty(), "LevelTransportBindings.bind_rings succeeds: " + str(bind_errors))

	var rings_lower := ring_lower_mod.get_node_or_null(^"Attachments/Interactions/transport/Rings") as TransportRings
	var rings_upper := ring_upper_mod.get_node_or_null(^"Attachments/Interactions/transport/Rings") as TransportRings
	assert(rings_lower != null and rings_upper != null, "Both TransportRings nodes present")
	assert(rings_lower.paired_rings == rings_upper, "Lower rings paired to upper rings")
	assert(rings_upper.paired_rings == rings_lower, "Upper rings paired to lower rings")

	# Verify reciprocal pairing geometry and arrival coordinate mapping
	assert(rings_lower.global_position.y < 1.0, "Lower rings are at Deck 0 elevation")
	assert(rings_upper.global_position.y > 3.0, "Upper rings are at Deck 1 elevation")
	assert(rings_lower._aboard(rings_lower, TransportRings.BOARDING_RADIUS), "Boarding radius contains lower rings center")
	assert(rings_upper._aboard(rings_upper, TransportRings.BOARDING_RADIUS), "Boarding radius contains upper rings center")

	# Coordinate transformation from lower to upper rings
	var dummy_offset := Vector3(0.2, 0.0, 0.3)
	var point_on_lower := rings_lower.global_position + dummy_offset
	var local_on_lower := rings_lower.to_local(point_on_lower)
	local_on_lower.y = 0.08
	var projected_on_upper := rings_upper.to_global(local_on_lower)
	assert(is_equal_approx(projected_on_upper.y, rings_upper.global_position.y + 0.08), "Projected point is on Deck 1 pad surface")
	assert(projected_on_upper.distance_to(rings_upper.global_position) < 1.0, "Projected point remains within upper rings pad")

	# Test beam discharge FX & state activation
	rings_lower._discharge_beam()
	assert(rings_lower.current_state == TransportRings.RingState.BEAM, "Rings entered BEAM state on discharge")

	# 5. Route Connectivity
	var gate_pos := assembly.marker(&"gate", &"entry")
	var upper_checkpoint_pos := assembly.marker(&"interior_checkpoint", &"destination")
	var path_to_upper := assembly.local_path(gate_pos, upper_checkpoint_pos)
	assert(not path_to_upper.is_empty(), "Physical walkable path exists from gate to upper checkpoint via ramp")
	assert(path_to_upper[-1].distance_to(upper_checkpoint_pos) < 1.0, "Path reaches destination in checkpoint")

	assembly.queue_free()
	await process_frame

	# 6. Mission Definition & Loop Validation
	var mission_def: MissionDefinition = load(MISSION_DEF_PATH)
	assert(mission_def != null, "MissionDefinition loads")
	var mission_errors := mission_def.validate()
	assert(mission_errors.is_empty(), "MissionDefinition validates: " + str(mission_errors))
	assert(mission_def.objectives.size() == 5, "Mission has 5 objectives")

	var mission_scene: PackedScene = load(MISSION_SCENE_PATH)
	assert(mission_scene != null, "Mission scene loads")
	var mission := mission_scene.instantiate() as ModularMission
	assert(mission != null, "ModularMission instantiates")
	root.add_child(mission)
	while not mission.is_started:
		await process_frame
	assert(mission.setup_errors.is_empty(), "Mission setup has no errors: " + str(mission.setup_errors))
	assert(mission.objectives.index == 0, "Mission starts on objective 0 (reach_cargo)")

	var dummy_operative := Node3D.new()
	mission.players_container.add_child(dummy_operative)

	# Objective 0: reach_cargo
	var bay_mod := mission.level.get_node(^"cargo_bay") as LevelModule
	dummy_operative.global_position = bay_mod.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Inside cargo bay")
	assert(mission.objectives._advance(0), "Advanced to objective 1 (reach_rings)")
	assert(mission.objectives.index == 1)

	# Objective 1: reach_rings
	var r_lower := mission.level.get_node(^"ring_lower") as LevelModule
	dummy_operative.global_position = r_lower.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Inside ring_lower")
	assert(mission.objectives._advance(1), "Advanced to objective 2 (reach_checkpoint)")
	assert(mission.objectives.index == 2)

	# Objective 2: reach_checkpoint
	var chk_mod := mission.level.get_node(^"interior_checkpoint") as LevelModule
	dummy_operative.global_position = chk_mod.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Inside interior_checkpoint")
	assert(mission.objectives._advance(2), "Advanced to objective 3 (download_manifest)")
	assert(mission.objectives.index == 3)

	# Objective 3: download_manifest
	assert(mission.objectives.complete_interaction(mission.objectives.current()), "Download manifest complete")
	assert(mission.objectives.index == 4, "Advanced to objective 4 (extract)")

	# Objective 4: extract at gate
	var gate_mod := mission.level.get_node(^"gate") as LevelModule
	dummy_operative.global_position = gate_mod.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Inside gate extraction radius")
	assert(mission.objectives._advance(4), "Extraction complete")
	assert(mission.objectives.is_complete(), "All mission objectives complete")

	mission.queue_free()
	await process_frame

	# 7. Network Registration
	var net_missions: Dictionary = SGCNetworkManager.MISSIONS
	assert(net_missions.has(SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP), "MISSION_TRAVEL_MOTHERSHIP registered")
	var mothership_net_info: Dictionary = net_missions[SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP]
	assert(mothership_net_info.get("hidden", false) == true, "MISSION_TRAVEL_MOTHERSHIP is hidden from public lobby")
	assert(mothership_net_info["site"] == MISSION_SCENE_PATH, "Mission points to mothership site scene")

	print("PASS Sprint 32 Mothership boarding: bulkhead/door/cargo props, two-deck Goa'uld layout, reciprocal R16 transport rings breach, and mission loop")
	quit(0)
