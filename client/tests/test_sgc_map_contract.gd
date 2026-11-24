extends SceneTree

const SERVICE_REGIONS: Array[StringName] = [
	&"WEST_SERVICE", &"WEST_FALLBACK", &"SECURITY_STATION", &"UPPER_ELEVATOR_LOBBY",
	&"SUPPORT_LOBBY", &"SUPPORT_CORRIDOR", &"STAGING", &"STORAGE", &"SERVICE_ROOM", &"SERVICE_STAIRWELL",
]
const SERVICE_STAIR := "SERVICE_STAIRWELL__SERVICE_ROOM"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	var definition := map.definition
	assert(definition.validate().is_empty())
	assert(definition.FLOOR_HEIGHTS.keys() == [28, 27, 26])
	assert(definition.region(&"BRIEFING_ROOM").confidence == "reference_relationship")
	assert(definition.region(&"STAGING").confidence == "gameplay_extension")
	var blocked: Array[StringName] = [&"GATE_ROOM__GATE_EAST_ACCESS"]
	var route := definition.route(&"GATE_ROOM", &"ARMORY", blocked)
	assert(
		not route.is_empty() and route[0].to_region == &"GATE_WEST_ACCESS",
		"Fallback loop must route around blocked eastern exits"
	)
	var style_ids: Array[StringName] = []
	for style in definition.styles:
		style_ids.append(style.id)
		assert(not style.description.is_empty() and not style.reference.is_empty())
	for slot in definition.asset_slots:
		assert(
			slot.style_id in style_ids and slot.dimensions.x > 0 and not slot.description.is_empty()
		)
	if not check_medical_cover(map):
		push_error("Level 26 medical props must fit the live slots and keep their original cover colliders")
		quit(1)
		return
	if not check_service_cabinet(map):
		push_error("Service cabinet must reuse the steel finish and retain its physical cover")
		quit(1)
		return
	if not await check_medical_camera(room, map):
		push_error("Crouch occlusion must fade the visible medical cabinet and restore its finish")
		quit(1)
		return
	check_service_architecture(room, map)
	# Art replacements must preserve gameplay collision and reject over-sized visuals.
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.2, 1)
	visual.mesh = box
	var scene := PackedScene.new()
	scene.pack(visual)
	visual.free()
	var body := map.get_node("STAGINGFloor") as StaticBody3D
	var collision: Shape3D = body.get_child(1).shape
	assert(map.replace_asset_visual(&"STAGINGFloor", scene))
	assert(body.get_child(1).shape == collision, "Art replacement must preserve collision")
	visual = MeshInstance3D.new()
	box = BoxMesh.new()
	box.size = Vector3(100, 100, 100)
	visual.mesh = box
	scene = PackedScene.new()
	scene.pack(visual)
	visual.free()
	assert(not map.replace_asset_visual(&"STAGINGFloor", scene), "Oversize art must be rejected")
	var actor := CharacterBody3D.new()
	room.add_child(actor)
	actor.position = Vector3(5, 0, 4)
	var nav := SGCNavigator.new(actor)
	assert(
		nav.next_position(Vector3(1000, 0, 1000)) == actor.position and nav.status == "unreachable",
		"Unknown goals must not produce direct wall-crossing movement"
	)
	print(
		"PASS source provenance, fallback routes, service architecture, visual bounds and unreachable destinations"
	)
	await preload("res://tests/support/finish.gd").success(self)


func check_service_architecture(room: GateRoom, map: SGCMap) -> void:
	for region_id: StringName in SERVICE_REGIONS:
		var region := map.definition.region(region_id)
		var fixture := map.get_node(str(region_id) + "LightFixture") as StaticBody3D
		var conduit := map.get_node(str(region_id) + "ServiceConduit") as StaticBody3D
		var fixture_slot := fixture.get_meta("asset_slot") as SGCAssetSlot
		var light := map.get_node(str(region_id) + "Light") as OmniLight3D
		assert(light.position == region.anchor + Vector3(0, 3.3, 0))
		assert(is_equal_approx(light.light_energy, region.light_energy))
		assert(light.light_color.is_equal_approx(region.light_color))
		var ceiling_height := map.definition.floor_y(region) + region.ceiling_height
		assert(is_equal_approx(fixture.position.y + fixture_slot.dimensions.y / 2.0, ceiling_height))
		var housing := fixture.get_node(^"ReplacementVisual") as Node3D
		assert(not (fixture.get_child(0) as MeshInstance3D).visible)
		assert(fixture.find_children("*", "CollisionShape3D", true, false).is_empty())
		var diffuser_is_lit := false
		for part: MeshInstance3D in housing.find_children("*", "MeshInstance3D", true, false):
			var envelope := AABB(-fixture_slot.dimensions / 2.0, fixture_slot.dimensions).grow(0.001)
			assert(envelope.encloses(part.transform * part.get_aabb()))
			var finish := part.get_active_material(0) as StandardMaterial3D
			diffuser_is_lit = diffuser_is_lit or finish.emission_enabled
		assert(diffuser_is_lit)
		var pipe := conduit.get_node(^"ReplacementVisual") as MeshInstance3D
		assert(not (conduit.get_child(0) as MeshInstance3D).visible)
		assert(conduit.find_children("*", "CollisionShape3D", true, false).is_empty())
		var pipe_slot := conduit.get_meta("asset_slot") as SGCAssetSlot
		assert(pipe.get_aabb().size.is_equal_approx(pipe_slot.dimensions))

	var ceiling_finish := preload("res://resources/materials/sgc/service_ceiling.tres")
	var finished_panels := 0
	for body: StaticBody3D in get_nodes_in_group("sgc_ceiling"):
		var slot := body.get_meta("asset_slot") as SGCAssetSlot
		if slot.style_id != &"ceiling" or slot.pbr_material != ceiling_finish:
			continue
		assert(body.collision_layer == 128 and body.get_child(1) is CollisionShape3D)
		assert((body.get_child(0) as MeshInstance3D).material_override == ceiling_finish)
		finished_panels += 1
	assert(finished_panels == 12, "The ten rooms include the split ceilings at the service stair")

	var tread_finish := preload("res://resources/materials/sgc/service_tread.tres")
	var walk := map.get_node(SERVICE_STAIR + "WalkSurface") as StaticBody3D
	var walk_collider := walk.get_child(1) as CollisionShape3D
	assert(walk_collider != null and walk_collider.shape is BoxShape3D and not walk_collider.disabled)
	assert((walk.get_child(0) as MeshInstance3D).material_override == tread_finish)
	for index in range(35):
		var tread := map.get_node(SERVICE_STAIR + "Tread" + str(index)) as StaticBody3D
		assert((tread.get_child(0) as MeshInstance3D).material_override == tread_finish)
		assert(tread.get_child_count() == 1, "The walk surface owns stair collision")
	var frame_finish := preload("res://resources/materials/sgc/service_frame.tres")
	for name: String in [SERVICE_STAIR + "Rail-1.3", SERVICE_STAIR + "Rail1.3", "ServiceHoleNorthGuard"]:
		var rail := map.get_node(name.validate_node_name()) as StaticBody3D
		assert(rail.get_child(1) is CollisionShape3D)
		assert((rail.get_child(0) as MeshInstance3D).material_override == frame_finish)

	var alarm := room.get_node(^"EmergencyLights/SERVICE_ROOMAlarm") as OmniLight3D
	room.set_emergency_lights(true)
	room._process(0.30)
	assert(alarm.light_energy > 0.0)
	room.set_emergency_lights(false)
	assert(is_zero_approx(alarm.light_energy))


func check_medical_cover(map: SGCMap) -> bool:
	var footprints := {
		"STAGINGCover": Vector3(1.6, 1, 1),
		"STORAGECover": Vector3(1.6, 1, 1),
		"SupplyRack0": Vector3(1.4, 1.8, 1.5),
		"SupplyRack1": Vector3(1.4, 1.8, 1.5),
		"SupplyRack2": Vector3(1.4, 1.8, 1.5),
		"SupplyRack3": Vector3(1.4, 1.8, 1.5),
		"StagingBench0": Vector3(3.5, 0.7, 0.6),
		"StagingBench1": Vector3(3.5, 0.7, 0.6),
		"EAST_CORRIDORCover": Vector3(1.6, 1, 1),
		"WEST_SERVICECover": Vector3(1.6, 1, 1),
		"WEST_FALLBACKCover": Vector3(1.6, 1, 1),
	}
	for id: String in footprints:
		var body := map.get_node(id) as StaticBody3D
		var visual := body.get_node_or_null(^"ReplacementVisual") as MeshInstance3D
		var original := body.get_child(0) as MeshInstance3D
		var collision := body.get_child(1) as CollisionShape3D
		var size := footprints[id] as Vector3
		if visual == null or original.visible or collision.disabled or (collision.shape as BoxShape3D).size != size:
			return false
		var replacement_bounds := visual.transform * visual.get_aabb()
		if not AABB(-size / 2.0, size).grow(0.002).encloses(replacement_bounds):
			return false
		var target := body.global_position
		if id == "SupplyRack0":
			target.y += 0.4
		var query := PhysicsRayQueryParameters3D.create(target + Vector3(size.x / 2 + 0.18, 0, 0), target, 1)
		if body.get_world_3d().direct_space_state.intersect_ray(query).get("collider") != body:
			return false
	return true


func check_service_cabinet(map: SGCMap) -> bool:
	var body := map.get_node(^"ServiceCabinet") as StaticBody3D
	var visual := body.get_child(0) as MeshInstance3D
	var collision := body.get_child(1) as CollisionShape3D
	var material := visual.material_override as StandardMaterial3D
	var shared_steel := preload("res://resources/materials/sgc/embarkation_steel.tres")
	if not visual.visible or material == null or material.albedo_texture != shared_steel.albedo_texture:
		return false
	if material.normal_texture != shared_steel.normal_texture or material.ao_texture != shared_steel.ao_texture:
		return false
	if collision.disabled or (collision.shape as BoxShape3D).size != Vector3(1.2, 2, 1.2):
		return false
	var query := PhysicsRayQueryParameters3D.create(
		body.global_position + Vector3(1.0, 0, 0), body.global_position, 1
	)
	return body.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == body


func check_medical_camera(room: GateRoom, map: SGCMap) -> bool:
	var body := map.get_node(^"STAGINGCover") as StaticBody3D
	var cabinet := body.get_node(^"ReplacementVisual") as MeshInstance3D
	var original_finish := cabinet.material_override
	var operative := preload("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	operative.name = "1"
	room.players_container.add_child(operative)
	operative.set_physics_process(false)
	operative.global_position = body.global_position + Vector3(0, -0.5, -1.25)
	operative.camera_rig.global_position = operative.global_position
	operative.is_crouch_toggled = true
	operative._process_cover_and_peeking(0.1, Vector3.ZERO)
	await physics_frame
	operative._update_camera_and_occlusion(1.0 / 60.0)
	var faded := operative.occluded_nodes.has(cabinet) and cabinet.material_override != original_finish
	operative.rotation.y = PI
	operative._update_camera_and_occlusion(1.0 / 60.0)
	var restored := cabinet.material_override == original_finish
	operative.queue_free()
	await process_frame
	return faded and restored
