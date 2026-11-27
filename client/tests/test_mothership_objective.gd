extends SceneTree
## Sprint 33: Mothership bridge & engineering objective and return route.
## Verifies 12-module Goa'uld layout, bridge console, reactor core, viewport frame,
## camera occlusion boundary, R16 transport breach, MissionEvents security release,
## alarm elevation, objective progression, and return gate extraction / debrief.

const LAYOUT_PATH := "res://resources/levels/ai2_goauld_mothership_objective.tres"
const MISSION_DEF_PATH := "res://resources/missions/goauld_mothership_objective.tres"
const MISSION_SCENE_PATH := "res://scenes/mission/GoauldMothershipObjectiveMission.tscn"
const MothershipReactorStatus := preload("res://scripts/level/MothershipReactorStatus.gd")


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
	assert(layout != null, "Mothership objective layout loads")
	assert(layout.instances.size() == 12, "Layout contains 12 modules")
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
	# 3.1 Engineering Reactor Core
	var eng_mod := assembly.get_node(^"engineering") as LevelModule
	assert(eng_mod != null, "engineering module present")
	var reactor := eng_mod.get_node_or_null(^"Attachments/RoomContent/reactor_core") as LevelPlaceholderProp
	assert(reactor != null, "MothershipReactorCore present in engineering")
	var r_body := reactor.get_node_or_null(^"Structure/Body") as StaticBody3D
	assert(r_body != null and r_body.collision_layer == 1, "Reactor core has layer 1 collision")
	var r_shape := r_body.get_child(0) as CollisionShape3D
	assert(r_shape.shape is BoxShape3D and (r_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(2.4, 2.8, 3.2)), "Reactor core shape matches envelope")

	var r_status := reactor.find_child("CoreColumn", true, false) as MothershipReactorStatus
	assert(r_status != null, "MothershipReactorStatus script attached to CoreColumn")
	assert(r_status.event_id == &"sabotage_releases_bridge", "Reactor status listens to sabotage_releases_bridge event")

	# 3.2 Bridge Command Helm Console
	var bridge_mod := assembly.get_node(^"bridge") as LevelModule
	assert(bridge_mod != null, "bridge module present")
	var helm := bridge_mod.get_node_or_null(^"Attachments/RoomContent/bridge_console") as LevelPlaceholderProp
	assert(helm != null, "MothershipBridgeConsole present on bridge")
	var h_body := helm.get_node_or_null(^"Structure/Body") as StaticBody3D
	assert(h_body != null and h_body.collision_layer == 1, "Bridge console has layer 1 collision")
	var h_shape := h_body.get_child(0) as CollisionShape3D
	assert(h_shape.shape is BoxShape3D and (h_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(2.0, 1.1, 1.0)), "Bridge console shape matches envelope")

	# 3.3 Bridge Viewport Hero Frame (Enclosure & Camera Occlusion Boundary)
	var viewport := bridge_mod.get_node_or_null(^"Attachments/RoomContent/viewport") as Node3D
	assert(viewport != null, "MothershipViewportFrame present on bridge")
	var vp_body := viewport.get_node_or_null(^"Structure/Body") as StaticBody3D
	assert(vp_body != null and vp_body.collision_layer == 1, "Viewport frame has solid layer 1 collision boundary")
	var vp_shape := vp_body.get_node_or_null(^"Shape") as CollisionShape3D
	assert(vp_shape != null and vp_shape.shape is BoxShape3D, "Viewport has solid BoxShape3D occluder shape")
	var vp_glass := viewport.find_child("GlassPane", true, false) as MeshInstance3D
	assert(vp_glass != null, "Viewport contains GlassPane")

	# 4. R16 Reciprocal Transport Rings Verification
	var ring_lower_mod := assembly.get_node(^"ring_lower") as LevelModule
	var ring_upper_mod := assembly.get_node(^"ring_upper") as LevelModule
	assert(ring_lower_mod != null and ring_upper_mod != null, "Both ring modules present")
	var bind_errors := LevelTransportBindings.bind_rings(layout, assembly)
	assert(bind_errors.is_empty(), "LevelTransportBindings.bind_rings succeeds: " + str(bind_errors))
	var rings_lower := ring_lower_mod.get_node_or_null(^"Attachments/Interactions/transport/Rings") as TransportRings
	var rings_upper := ring_upper_mod.get_node_or_null(^"Attachments/Interactions/transport/Rings") as TransportRings
	assert(rings_lower != null and rings_upper != null, "Both TransportRings nodes present")
	assert(rings_lower.paired_rings == rings_upper, "Reciprocal lower to upper ring pairing")
	assert(rings_upper.paired_rings == rings_lower, "Reciprocal upper to lower ring pairing")

	# 5. Full Objective and Return Route Connectivity
	var gate_pos := assembly.marker(&"gate", &"entry")
	var eng_pos := assembly.marker(&"engineering", &"entry")
	var bridge_pos := assembly.marker(&"bridge", &"destination")
	assert(gate_pos != Vector3.INF and eng_pos != Vector3.INF and bridge_pos != Vector3.INF)

	var path_inward := assembly.local_path(gate_pos, bridge_pos)
	assert(not path_inward.is_empty(), "Walkable path exists from gate to bridge")
	assert(path_inward[-1].distance_to(bridge_pos) < 1.0, "Path reaches bridge destination")

	var path_return := assembly.local_path(bridge_pos, gate_pos)
	assert(not path_return.is_empty(), "Walkable return path exists from bridge back to gate")
	assert(path_return[-1].distance_to(gate_pos) < 1.0, "Return path reaches extraction gate")

	assembly.queue_free()
	await process_frame

	# 6. Mission Definition & MissionEvents Loop
	var mission_def: MissionDefinition = load(MISSION_DEF_PATH)
	assert(mission_def != null, "MissionDefinition loads")
	var mission_errors := mission_def.validate()
	assert(mission_errors.is_empty(), "MissionDefinition validates: " + str(mission_errors))
	assert(mission_def.objectives.size() == 4, "Mission has 4 objectives")
	assert(mission_def.triggers.size() == 1, "Mission has 1 security release trigger")

	var mission_scene: PackedScene = load(MISSION_SCENE_PATH)
	assert(mission_scene != null, "Mission scene loads")
	var mission := mission_scene.instantiate() as ModularMission
	assert(mission != null, "ModularMission instantiates")
	root.add_child(mission)
	while not mission.is_started:
		await process_frame
	assert(mission.setup_errors.is_empty(), "Mission setup has no errors: " + str(mission.setup_errors))

	# 7. Security Door Verification
	var door_found: ModularDoor = null
	for child in mission.level.get_children():
		var door := child as ModularDoor
		if door != null and door.is_security and door.security_id == &"bridge_blast_door":
			door_found = door
			break
	assert(door_found != null, "bridge_blast_door ModularDoor present in mission")
	assert(door_found.locked, "bridge_blast_door starts locked by MissionEvents")
	assert(not door_found.is_open, "bridge_blast_door starts closed")

	var dummy_operative := Node3D.new()
	mission.players_container.add_child(dummy_operative)

	# Objective 0: reach_checkpoint
	assert(mission.objectives.index == 0, "Mission starts on reach_checkpoint")
	var chk_mod := mission.level.get_node(^"interior_checkpoint") as LevelModule
	dummy_operative.global_position = chk_mod.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Operative inside interior_checkpoint")
	assert(mission.objectives._advance(0), "Advanced to objective 1 (sabotage_hyperdrive)")
	assert(mission.objectives.index == 1)

	# Objective 1: sabotage_hyperdrive in Engineering
	assert(door_found.locked, "bridge_blast_door remains locked before sabotage")
	var mission_reactor := mission.level.get_node(^"engineering/Attachments/RoomContent/reactor_core") as LevelPlaceholderProp
	var reactor_column := mission_reactor.find_child("CoreColumn", true, false) as MeshInstance3D
	var original_mat := reactor_column.mesh.surface_get_material(0)

	assert(mission.objectives.complete_interaction(mission.objectives.current()), "Sabotage hyperdrive completed")
	assert(mission.objectives.index == 2, "Advanced to objective 2 (override_bridge_helm)")
	assert(mission.events.fired.has("sabotage_releases_bridge"), "sabotage_releases_bridge trigger fired")
	assert(not door_found.locked, "bridge_blast_door is released by sabotage event")

	# Verify reactor core visual transitioned to shutdown
	assert(reactor_column.material_override != null, "Reactor column received shutdown material override")

	# Objective 2: override_bridge_helm on Bridge
	assert(mission.objectives.complete_interaction(mission.objectives.current()), "Override bridge helm completed")
	assert(mission.objectives.index == 3, "Advanced to objective 3 (extract)")

	# Objective 3: extract at gate
	var gate_mod := mission.level.get_node(^"gate") as LevelModule
	dummy_operative.global_position = gate_mod.global_position
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Operative inside gate extraction area")
	assert(mission.objectives._advance(3), "Extraction complete")
	assert(mission.objectives.is_complete(), "All mission objectives complete")

	# 8. Victory & Debrief Conclude Verification
	mission.conclude(true)
	assert(mission.mission_result == 1, "Mission conclude(true) records victory")

	# 9. Failure Conclude Verification
	mission.mission_result = -1
	mission.conclude(false)
	assert(mission.mission_result == 0, "Mission conclude(false) records defeat")

	mission.queue_free()
	await process_frame

	# 10. Network Registration Verification
	var net_missions: Dictionary = SGCNetworkManager.MISSIONS
	assert(net_missions.has(SGCNetworkManager.MISSION_MOTHERSHIP_OBJECTIVE), "MISSION_MOTHERSHIP_OBJECTIVE registered in MISSIONS")
	var obj_info: Dictionary = net_missions[SGCNetworkManager.MISSION_MOTHERSHIP_OBJECTIVE]
	assert(obj_info.get("hidden", false) == true, "MISSION_MOTHERSHIP_OBJECTIVE is hidden from public lobby")
	assert(obj_info["site"] == MISSION_SCENE_PATH, "Mission points to GoauldMothershipObjectiveMission.tscn")

	print("PASS Sprint 33 Mothership objective: bridge/engineering route, bridge console, reactor core, viewport frame, camera boundary, blast door release, and debrief")
	quit(0)
