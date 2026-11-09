extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	call_deferred("run")


func module_for(id: String) -> LevelModuleDefinition:
	for name: String in LevelCatalogue.all_modules():
		var module := (
			load("res://resources/level_modules/" + name + ".tres") as LevelModuleDefinition
		)
		if str(module.id) == id:
			return module
	return null


func configured(preset: LevelRoomPreset, module: LevelModuleDefinition) -> LevelLayout:
	var model := Model.new()
	model.restore(model.placed(module, Vector2.ZERO, 0))
	return model.configured(model.layout.instances[0].id, preset)


func build(layout: LevelLayout) -> LevelAssembly:
	var assembly := LevelAssembly.new()
	assembly.layout = layout
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert(assembly.last_errors.is_empty(), str(assembly.last_errors))
	return assembly


func run() -> void:
	var presets := {}
	for id: String in LevelPresetCatalogue.PRESETS:
		var preset := LevelPresetCatalogue.preset(id)
		assert(preset.id == StringName(id) and not presets.has(id))
		presets[id] = preset
		for module_id: String in preset.compatible_modules:
			var candidate := configured(preset, module_for(module_id))
			var errors := LevelLayoutValidator.validate(candidate)
			if not errors.is_empty():
				print("INVALID PRESET ", id, " ", module_id, " ", errors)
				quit(1)
				return
		var layout := configured(preset, module_for(preset.compatible_modules[0]))
		var assembly := await build(layout)
		var item := layout.instances[0]
		for attachment in LevelRoomComposer.resolved(item):
			var node := (
				assembly.get_node(str(item.id) + "/" + str(LevelRoomComposer.node_path(attachment)))
				as Node3D
			)
			assert(node != null)
			if attachment.scene != null:
				assert(node.scene_file_path == attachment.scene.resource_path)
			if attachment.placeholder_size != Vector3.ZERO:
				assert(node.scene_file_path == "res://scenes/level/RoomPlaceholder.tscn")
			if node is TransportRings:
				assert(
					(
						not node.spawn_enemies_on_beam
						and node.current_state == TransportRings.RingState.INACTIVE
					)
				)
			if node is DHDDialer:
				assert(
					(
						node.target_stargate != null
						and node.current_phase == DHDDialer.DialPhase.INACTIVE
					)
				)
		# Revalidating cannot duplicate equipment or replace the shell.
		var count := assembly.get_child_count()
		await assembly.validate_and_bake()
		assert(assembly.last_errors.is_empty() and assembly.get_child_count() == count)
		assert(ResourceSaver.save(layout, "user://preset_roundtrip.tres") == OK)
		var packed := PackedScene.new()
		assert(packed.pack(assembly) == OK)
		assert(ResourceSaver.save(packed, "user://preset_scene.tscn") == OK)
		assembly.queue_free()
		await process_frame
		var reloaded := (
			ResourceLoader.load(
				"user://preset_roundtrip.tres", "", ResourceLoader.CACHE_MODE_IGNORE
			)
			as LevelLayout
		)
		assert(reloaded.instances[0].room_preset.id == preset.id)
		var reopened := (
			(
				ResourceLoader
				. load("user://preset_scene.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
				. instantiate()
			)
			as LevelAssembly
		)
		root.add_child(reopened)
		while not reopened.ready_for_navigation and reopened.last_errors.is_empty():
			await process_frame
		assert(reopened.last_errors.is_empty())
		reopened.queue_free()
		await process_frame
	var model := Model.new()
	model.restore(configured(presets["cargo"], module_for("room04")))
	var item := model.layout.instances[0]
	var original_module := item.module
	var override_pose := Transform3D(Basis.IDENTITY, Vector3(2.5, 0, -2.5))
	model.restore(model.attachment_changed(item.id, &"console", override_pose, false))
	model.restore(
		model.attachment_changed(
			item.id, &"crate_01", Transform3D(Basis.IDENTITY, Vector3(-2.5, 0, -2.5)), false
		)
	)
	var cargo_snapshot := Model.copy(model.layout)
	model.restore(model.configured(item.id, presets["jaffa_barracks"]))
	assert(
		model.layout.instances[0].module == original_module and model.layout.connections.is_empty()
	)
	assert(LevelRoomComposer.warnings(model.layout).size() == 1)
	assert(
		LevelRoomComposer.resolved(model.layout.instances[0])[0].local_transform == override_pose
	)
	assert(model.layout.instances[0].attachment_overrides.size() == 2)
	assert(cargo_snapshot.instances[0].room_preset.id == &"cargo")
	# Required attachment removal, outside bounds and blocked portal edits reject before commit.
	assert(not model.accepted(model.attachment_changed(item.id, &"console", override_pose, true)))
	assert(
		not model.accepted(
			model.attachment_changed(
				item.id, &"console", Transform3D(Basis.IDENTITY, Vector3(50, 0, 0)), false
			)
		)
	)
	assert(
		not model.accepted(
			model.attachment_changed(
				item.id, &"console", Transform3D(Basis.IDENTITY, Vector3(0, 0, -3)), false
			)
		)
	)
	assert(model.layout.instances[0].attachment_overrides[0].local_transform == override_pose)
	model.restore(model.configured(item.id, presets["cargo"]))
	assert(LevelRoomComposer.warnings(model.layout).is_empty())
	assert(model.accepted(model.attachment_reset(item.id, &"console")))
	assert(
		model.accepted(model.attachment_changed(item.id, &"cover_01", Transform3D.IDENTITY, true)),
		"Optional cover marker can be disabled"
	)
	# Materials change independently of scene identity/collision/nav.
	var assembly := await build(model.layout)
	var crate := assembly.get_node(str(item.id) + "/Attachments/RoomContent/crate_01") as Node3D
	var hit := assembly.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(-.9, .6, -2.5), Vector3(-3.6, .6, -2.5), 1)
	)
	assert(
		not hit.is_empty() and crate.is_ancestor_of(hit.collider),
		"Cargo visual placeholder must have real collision"
	)
	var body := crate.get_node("Structure/Body") as StaticBody3D
	body.collision_layer = 0
	assert("Attachment collision mismatch" in str(LevelRoomComposer.validate_world(assembly)))
	body.collision_layer = 1
	var nav := assembly.navigation.navigation_mesh
	var shape := (
		assembly.get_node(str(item.id) + "/Structure/Collision/Floor0/Shape") as CollisionShape3D
	)
	var previous_shape := shape.shape
	var theme := load("res://resources/level_themes/neutral.tres") as LevelVisualTheme
	model.layout.instances[0].theme = theme
	LevelRoomComposer.apply_theme(model.layout.instances[0], assembly.get_node(str(item.id)))
	assert(assembly.navigation.navigation_mesh == nav and shape.shape == previous_shape)
	assembly.queue_free()
	await process_frame
	await configured_walkthrough()
	await negative_contracts()
	print(
		"PASS 16 presets, all declared structural compatibilities, real asset identity, required approaches, derived-content reload, role switch/overrides, invalid edits and visual-theme independence"
	)
	await preload("res://tests/support/finish.gd").success(self)


func configured_walkthrough() -> void:
	var rotation_model := Model.new()
	rotation_model.restore(
		configured(LevelPresetCatalogue.preset("security_control"), module_for("room04"))
	)
	rotation_model.restore(
		rotation_model.attachment_changed(
			rotation_model.layout.instances[0].id,
			&"console",
			Transform3D(Basis(Vector3.UP, PI), Vector3(-2.6, 0, 2.6)),
			false
		)
	)
	var rotated := await build(rotation_model.layout)
	rotated.queue_free()
	await process_frame
	var source := load("res://resources/levels/room_presets_demo.tres") as LevelLayout
	var assembly := await build(source)
	var door := assembly.get_node("Door_000") as ModularDoor
	door.sync_open(true)
	var start := assembly.marker(source.entry_instance, &"entry")
	var goal := assembly.marker(source.destination_instance, &"entry")
	for scene: String in ["Player", "SGCAirman", "JaffaGuard"]:
		var pawn := (
			load("res://scenes/entities/" + scene + ".tscn").instantiate() as CharacterBody3D
		)
		pawn.name = "1"
		assembly.add_child(pawn)
		pawn.set_process(false)
		pawn.set_physics_process(false)
		pawn.floor_snap_length = .4
		for reverse: bool in [false, true]:
			var from := goal if reverse else start
			var to := start if reverse else goal
			pawn.position = from + Vector3(0, .03, 0)
			pawn.velocity = Vector3.ZERO
			await physics_frame
			var path := assembly.local_path(from, to)
			assert(not path.is_empty() and path[-1].distance_to(to) < .5)
			var index := 0
			var arrived := false
			for tick in range(700):
				var direction := path[index] - pawn.position
				direction.y = 0
				if direction.length() < .15 and index < path.size() - 1:
					index += 1
					continue
				direction = direction.normalized()
				pawn.velocity = Vector3(direction.x * 3, -.5, direction.z * 3)
				pawn.move_and_slide()
				await physics_frame
				if pawn.position.distance_to(to) < .45:
					arrived = true
					break
			assert(arrived, "Configured-room props must preserve capsule passage: " + scene)
		pawn.queue_free()
		await process_frame
	assembly.queue_free()
	await process_frame
	# Preset composition invokes the existing reciprocal ring-binding contract.
	var rings := Model.new()
	var shell := module_for("room15")
	rings.restore(rings.placed(shell, Vector2.ZERO, 0))
	rings.restore(rings.placed(shell, Vector2(0, 8), 0))
	for i in range(2):
		rings.restore(
			rings.configured(
				rings.layout.instances[i].id, LevelPresetCatalogue.preset("ring_transport")
			)
		)
		var endpoint := LevelTransportEndpoint.new()
		endpoint.id = StringName("preset_ring_%d" % i)
		endpoint.target_id = StringName("preset_ring_%d" % (1 - i))
		endpoint.node_path = NodePath("Attachments/Interactions/transport/Rings")
		rings.layout.instances[i].transport_endpoints.append(endpoint)
	assembly = await build(rings.layout)
	var a := (
		assembly.get_node("room_001/Attachments/Interactions/transport/Rings") as TransportRings
	)
	var b := (
		assembly.get_node("room_002/Attachments/Interactions/transport/Rings") as TransportRings
	)
	assert(a.paired_rings == b and b.paired_rings == a and not a.spawn_enemies_on_beam)
	assembly.queue_free()
	await process_frame


func negative_contracts() -> void:
	var source := configured(LevelPresetCatalogue.preset("cargo"), module_for("room04"))
	var item := source.instances[0]
	item.room_preset = item.room_preset.duplicate() as LevelRoomPreset
	item.room_preset.attachments = []
	for attachment in LevelPresetCatalogue.preset("cargo").attachments:
		item.room_preset.attachments.append(attachment.duplicate() as LevelRoomAttachment)
	item.room_preset.attachments[0].approach = Vector3.ZERO
	var assembly := LevelAssembly.new()
	assembly.layout = source
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert("Attachment approach blocked: room_001/console" in assembly.last_errors)
	assembly.queue_free()
	await process_frame
	# A required component cannot be replaced with an empty marker.
	source = configured(LevelPresetCatalogue.preset("ring_transport"), module_for("room15"))
	item = source.instances[0]
	item.room_preset = item.room_preset.duplicate() as LevelRoomPreset
	item.room_preset.attachments = []
	for attachment in LevelPresetCatalogue.preset("ring_transport").attachments:
		item.room_preset.attachments.append(attachment.duplicate() as LevelRoomAttachment)
	item.room_preset.attachments[0].scene = null
	assembly = LevelAssembly.new()
	assembly.layout = source
	root.add_child(assembly)
	while not assembly.ready_for_navigation and assembly.last_errors.is_empty():
		await process_frame
	assert("Missing required component: room_001/Rings" in str(assembly.last_errors))
	assembly.queue_free()
	await process_frame
