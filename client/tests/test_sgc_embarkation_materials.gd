extends SceneTree
## Exercises the real SGC scene, shared PBR resources and the existing camera fade.

const SGC_SCENE := preload("res://scenes/main/SGCUATBase.tscn")
const PLAYER_SCENE := preload("res://scenes/entities/Player.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := SGC_SCENE.instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready

	var materials: Dictionary[StandardMaterial3D, bool] = {}
	var slot_count := 0
	var wall_mesh: MeshInstance3D
	for body: Node in map.get_children():
		if not body.has_meta("asset_slot"):
			continue
		var slot := body.get_meta("asset_slot") as SGCAssetSlot
		if slot.pbr_material == null:
			continue
		var mesh := body.get_child(0) as MeshInstance3D
		if slot.id == &"GATE_EAST_ACCESSWall0_12.0_0.0":
			wall_mesh = mesh
		assert(mesh.material_override == slot.pbr_material and mesh.visible)
		assert(mesh.get_aabb().size.is_equal_approx(slot.dimensions))
		materials[slot.pbr_material] = true
		slot_count += 1
	assert(slot_count == 35 and materials.size() == 3, "Expected 35 slots sharing three sets, got %d" % slot_count)
	var decoded_texture_bytes := 0
	for material: StandardMaterial3D in materials:
		assert(material.normal_enabled and material.ao_enabled and material.uv1_triplanar)
		assert(material.ao_texture == material.roughness_texture)
		assert(material.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
		assert(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
		for texture: Texture2D in [material.albedo_texture, material.normal_texture, material.ao_texture]:
			var image := texture.get_image()
			assert(image.get_size() == Vector2i(1024, 1024) and image.has_mipmaps())
			decoded_texture_bytes += image.get_data_size()

	var ramp := room.get_node("BunkerGeometry/GateRamp") as CSGBox3D
	var platform := room.get_node("BunkerGeometry/StargatePlatform") as CSGBox3D
	var steel := ramp.material as StandardMaterial3D
	assert(ramp.use_collision and platform.use_collision and platform.material == steel)
	assert(steel.metallic == 1.0 and steel.metallic_texture == steel.ao_texture)
	assert(steel.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
	assert(not map.get_node("ARMORYFloor").get_meta("asset_slot").pbr_material)

	var fallback := SGCAssetSlot.new()
	fallback.id = &"IncompleteMaterialFixture"
	fallback.pbr_material = StandardMaterial3D.new()
	fallback.texture = steel.albedo_texture
	map.definition.asset_slots.append(fallback)
	var fallback_mesh := map._box(str(fallback.id), Vector3(0, -4, 0), Vector3.ONE, &"floor", false)
	assert(fallback_mesh.material_override != fallback.pbr_material)
	assert((fallback_mesh.material_override as StandardMaterial3D).albedo_texture == fallback.texture)

	var pawn := PLAYER_SCENE.instantiate() as PlayerController3D
	pawn.name = "1"
	room.players_container.add_child(pawn)
	pawn.set_physics_process(false)
	pawn.global_position = Vector3(15, 0.05, 4)
	await physics_frame

	assert(wall_mesh != null, "The east approach uses PBR on the occluding wall")
	var original := wall_mesh.material_override as StandardMaterial3D
	pawn.camera.global_position = Vector3(15, 1.25, 0)
	pawn._update_wall_occlusion()
	var faded := wall_mesh.material_override as StandardMaterial3D
	assert(faded != original and faded.albedo_color.a < 0.5, "The camera must fade the textured wall")
	assert(faded.normal_texture == original.normal_texture and original.albedo_color.a == 1.0)
	pawn.camera.global_position = Vector3(15, 1.25, 3.2)
	pawn._update_wall_occlusion()
	assert(wall_mesh.material_override == original, "Exit restores the shared surface resource")

	var space := room.get_world_3d().direct_space_state
	var aperture := room.stargate_mesh.global_position
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(aperture - Vector3.FORWARD, aperture + Vector3.FORWARD, 1)).is_empty(), "The gate aperture stays clear")
	var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, 2), Vector3(0, 0.8, 0), 1))
	assert(cover.get("collider") == room.get_node("BunkerGeometry/Barricades/SandbagsCenter"))
	var ramp_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 3, -4), Vector3(0, -1, -4), 1))
	assert(ramp_hit.get("collider") == ramp)
	var route := map.local_path(Vector3(15, 0, 4), Vector3(0, 2.0, -12))
	assert(route.size() > 2 and route[-1].distance_to(Vector3(0, 2, -12)) < 0.75, "Existing route still reaches the gate platform")

	pawn.global_position = Vector3(0, 0.18, -0.5)
	pawn.velocity = Vector3.ZERO
	for i in range(210):
		await physics_frame
		pawn.velocity.z = -3.5
		pawn.velocity.y -= 9.8 / 60.0
		pawn.move_and_slide()
		if pawn.global_position.z < -10.0:
			break
	assert(pawn.global_position.z < -10.0 and absf(pawn.global_position.y - 2.0) < 0.25,
		"An operative can walk from the ramp foot onto the dressed platform")
	print("test_sgc_embarkation_materials: PASS 35 slots, legacy fallback, fade, gate aperture and ramp")
	print("Embarkation texture image payload with mipmaps: %d bytes" % decoded_texture_bytes)
	# Let overlap notifications finish before the world and test operative exit together.
	pawn.collision_layer = 0
	await physics_frame
	await physics_frame
	pawn.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)
