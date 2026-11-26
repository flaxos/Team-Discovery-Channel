extends SceneTree
## Sprint 31: Alpha Site outpost dressing, field equipment families,
## observation aperture with exterior vista, civilian presence, and complete
## entry/objective/return mission loop.

const LAYOUT_PATH := "res://resources/levels/ai2_tauri_alpha_site.tres"
const MISSION_DEF_PATH := "res://resources/missions/tauri_alpha_site.tres"
const MISSION_SCENE_PATH := "res://scenes/mission/TauriAlphaSiteMission.tscn"


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
	assert(layout != null, "Alpha Site layout loads")
	var layout_errors := LevelLayoutValidator.validate(layout)
	assert(layout_errors.is_empty(), "Layout validator passes: " + str(layout_errors))

	var theme := LevelThemeResolver.registry().get(&"tauri_sgc") as LevelVisualTheme
	assert(theme != null, "tauri_sgc theme registered")
	assert(theme.art_status == "authored", "tauri_sgc has authored art status")
	assert(theme.materials.size() == 7, "All 7 resolver slots mapped in tauri_sgc")
	for slot_name: String in LevelThemeResolver.SLOTS:
		assert(theme.materials.has(slot_name) and theme.materials[slot_name] != null, "Slot material exists: " + slot_name)

	# 2. Assembly, Enclosure and World Composition
	var assembly := await assemble(layout)
	var enclosure_errors := LevelEnclosureValidator.validate(assembly)
	assert(enclosure_errors.is_empty(), "LevelEnclosureValidator passes: " + str(enclosure_errors))
	var world_errors := LevelRoomComposer.validate_world(assembly)
	assert(world_errors.is_empty(), "LevelRoomComposer.validate_world passes: " + str(world_errors))

	# Verify room visual source and coverage
	for item in layout.instances:
		var info := LevelThemeResolver.describe(layout, item)
		assert(info.art_status == "authored")
		assert(info.visual_source == "tauri_sgc")
		assert(info.coverage == "palette")

	# 3. Family 2: Field Equipment & Storage Props
	var store_long := assembly.get_node(^"stores_store_long") as LevelModule
	assert(store_long != null, "stores_store_long module present")
	for crate_id: String in ["crate_01", "crate_02", "crate_03"]:
		var crate := store_long.get_node_or_null("Attachments/RoomContent/" + crate_id) as LevelPlaceholderProp
		assert(crate != null, "Crate prop present: " + crate_id)
		var body := crate.get_node_or_null(^"Structure/Body") as StaticBody3D
		assert(body != null and body.collision_layer == 1, "Crate has layer 1 collision")
		var shape := body.get_child(0) as CollisionShape3D
		assert(shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(1.4, 1.2, 1.4)))

	# 4. Family 2 & 3: Observation / Communications, Vista & Civilian
	var obs := assembly.get_node(^"cmd_observation") as LevelModule
	assert(obs != null, "cmd_observation module present")

	var console := obs.get_node_or_null(^"Attachments/RoomContent/console") as LevelPlaceholderProp
	assert(console != null, "Field console present in observation")
	var rack := obs.get_node_or_null(^"Attachments/RoomContent/communications_display") as LevelPlaceholderProp
	assert(rack != null, "Field comms rack present in observation")

	# Vista verification
	var vista := obs.get_node_or_null(^"Attachments/RoomContent/observation_vista") as Node3D
	assert(vista != null, "observation_vista present in cmd_observation")
	assert(vista.find_children("*", "CollisionShape3D", true, false).is_empty(), "Vista is non-colliding")
	var aperture := vista.get_node_or_null(^"InteriorAperture") as Node3D
	assert(aperture != null, "Interior aperture frame present")
	var exterior := vista.get_node_or_null(^"ExteriorVista") as Node3D
	assert(exterior != null, "Exterior vista scenery present")
	assert(exterior.get_node_or_null(^"RidgeLeft") != null, "Exterior mountain ridges present")
	assert(exterior.get_node_or_null(^"SkyBackdrop") != null, "Sky backdrop present")

	# Verify enclosure boundary wall behind vista remains closed in collision
	var closure_south := obs.get_node_or_null(^"Structure/PortalClosures/south") as StaticBody3D
	assert(closure_south != null and closure_south.collision_layer == 1, "South portal closure retains collision layer 1")

	# Civilian verification (Reused Sprint 26 appearance)
	var civilian := obs.get_node_or_null(^"Attachments/RoomContent/staff_station") as SGCCivilianVisual
	assert(civilian != null, "SGCCivilian present at staff_station")
	assert(civilian.role == SGCCivilianVisual.Role.LABORATORY, "Civilian has laboratory role")
	assert(civilian.find_children("*", "CollisionObject3D", true, false).is_empty(), "Civilian has no collision")
	assert(civilian.find_children("*", "HealthComponent", true, false).is_empty(), "Civilian has no combat health")
	assert(civilian.work_prop != null and civilian.work_prop.has_node(^"Clipboard"), "Civilian holds clipboard work prop")

	# 5. Mission Definition & Entry/Objective/Return Loop
	var mission_def: MissionDefinition = load(MISSION_DEF_PATH)
	assert(mission_def != null, "MissionDefinition loads")
	var mission_errors := mission_def.validate()
	assert(mission_errors.is_empty(), "MissionDefinition validates: " + str(mission_errors))
	assert(mission_def.objectives.size() == 3, "Mission has 3 objectives (reach -> download -> extract)")
	assert(mission_def.objectives[0].id == &"reach_command" and mission_def.objectives[0].kind == "reach")
	assert(mission_def.objectives[1].id == &"download_records" and mission_def.objectives[1].kind == "interact")
	assert(mission_def.objectives[2].id == &"extract" and mission_def.objectives[2].kind == "extract")

	# Verify route connectivity from entry to command and observation
	var entry_pos := assembly.marker(&"entry", &"entry")
	var cmd_pos := assembly.marker(&"cmd_command", &"destination")
	var path_to_cmd := assembly.local_path(entry_pos, cmd_pos)
	assert(not path_to_cmd.is_empty(), "Walkable path exists from entry to cmd_command")
	assert(path_to_cmd[-1].distance_to(cmd_pos) < 0.5, "Path reaches destination in cmd_command")

	var obs_pos := obs.global_position
	var path_to_obs := assembly.local_path(entry_pos, obs_pos)
	assert(not path_to_obs.is_empty(), "Walkable path exists from entry to cmd_observation")

	# Clean up assembly
	assembly.queue_free()
	await process_frame

	# 6. Live Mission Run (headless simulation)
	var mission_scene: PackedScene = load(MISSION_SCENE_PATH)
	assert(mission_scene != null, "Mission scene loads")
	var mission := mission_scene.instantiate() as ModularMission
	assert(mission != null, "ModularMission instantiates")
	root.add_child(mission)
	while not mission.is_started:
		await process_frame
	assert(mission.setup_errors.is_empty(), "Mission setup has no errors: " + str(mission.setup_errors))
	assert(mission.objectives.index == 0, "Mission starts on objective 0 (reach_command)")

	# Simulate operative reaching cmd_command
	var dummy_operative := Node3D.new()
	mission.players_container.add_child(dummy_operative)
	dummy_operative.global_position = cmd_pos
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Operative is inside cmd_command")
	assert(mission.objectives._advance(0), "Advanced past reach_command to download_records")
	assert(mission.objectives.index == 1, "Mission is on objective 1 (download_records)")

	# Complete download objective via interaction
	assert(mission.objectives.complete_interaction(mission.objectives.current()), "Completed download_records interaction")
	assert(mission.objectives.index == 2, "Objective advanced to extraction (objective 2)")

	# Simulate return to entry insertion point
	dummy_operative.global_position = entry_pos
	assert(mission.objectives.inside(dummy_operative, mission.objectives.current()), "Operative is inside entry extraction zone")
	assert(mission.objectives._advance(2), "Advanced extraction to completed")
	assert(mission.objectives.is_complete(), "Mission objectives completed successfully")

	mission.queue_free()
	await process_frame

	print("PASS Sprint 31 Alpha Site outpost: pre-fab shelter theme, field equipment, observation aperture vista, civilian presence, and entry/objective/return mission loop")
	quit(0)
