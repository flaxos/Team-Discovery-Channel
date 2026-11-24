extends SceneTree
## AP-1c cosmetic proof: the CC0 Poly Haven plastic crate dresses the SGC armoury ammo crates
## without changing their collision, size, interaction or the navigation they were baked with.
const MODEL := CrateStackVisual.MODEL_PATH
const MODEL_SIZE := Vector3(0.5055, 0.2541, 0.4055)
const BOX_SIZE := Vector3(1.6, 1.0, 1.2)
const STATION := "res://scripts/props/ArmoryResupplyStation.gd"


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func check_loader() -> void:
	assert(RuntimeGLB.load_scene("res://assets/props/missing_crate.glb") == null, "Missing model")
	var scene := RuntimeGLB.load_scene(MODEL)
	assert(scene != null, "The committed crate must load from res:// bytes")
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 1, "The crate is one mesh")
	var mesh := (meshes[0] as MeshInstance3D).mesh
	var indices := mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert(indices.size() / 3 == 5840, "Measured triangle count changed")
	assert((mesh.get_aabb().size - MODEL_SIZE).length() < 0.002, "Measured crate size changed")
	var source := mesh.surface_get_material(0) as StandardMaterial3D
	var prepared := CrateStackVisual.prepared_material(source, CrateStackVisual.DEFAULT_TINT)
	assert(source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "Source material untouched")
	assert(prepared.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Drawn opaque")
	assert(prepared.albedo_color == CrateStackVisual.DEFAULT_TINT, "Armoury tint applied")
	assert(prepared.ao_enabled and prepared.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED,
		"ARM occlusion wired")
	assert(prepared.metallic == 0.0, "D-015: matte, as authored")
	for texture: Texture2D in [prepared.albedo_texture, prepared.normal_texture,
			prepared.roughness_texture, prepared.ao_texture]:
		assert(texture != null and texture.get_image().has_mipmaps(), "Textures need mipmaps")
	scene.free()


func check_dressed(room: Node) -> void:
	var meshes := {}
	for crate_name: String in ["AmmoCrate1", "AmmoCrate2"]:
		var station := room.find_child(crate_name, true, false) as ArmoryResupplyStation
		assert(station != null, crate_name + " must remain an ArmoryResupplyStation")
		var box := station.get_node(^".") as CSGBox3D
		var visual := station.crate_visual
		assert(visual != null and visual.get_parent() == box, crate_name + " is dressed")
		assert(visual.name == "ReplacementVisual", "Same naming as SGCMap replacements")
		assert(box.size == BOX_SIZE and box.use_collision, crate_name + " keeps its box")
		assert(box.collision_layer == 1 and box.collision_mask == 1, "Collision layers unchanged")
		assert(station.is_in_group("interactable"), "Still interactable")
		assert(box.transparency == 1.0, "Box no longer drawn")
		assert(box.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Box casts no shadow")
		assert(visual.crate_count == 33 and is_equal_approx(snappedf(visual.crate_scale, 0.0001), 0.9839),
			"3 x 3 x 4 stack less the hidden core, uniformly scaled")
		var envelope := AABB(-BOX_SIZE / 2.0, BOX_SIZE)
		assert(envelope.grow(CrateStackVisual.ENVELOPE_TOLERANCE).encloses(visual.bounds), "Fits its box")
		assert(visual.bounds.position.y == envelope.position.y, "Stands on the floor")
		assert(visual.bounds.size.x > 1.45 and visual.bounds.size.z > 1.15 and visual.bounds.size.y > 0.98,
			"Fills its box, so no invisible walls")
		for node: Node in visual.find_children("*", "", true, false):
			assert(not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D),
				"Visual only")
		var crates := visual.get_node("Crates") as MultiMeshInstance3D
		meshes[crates.multimesh.mesh] = true
		# The original box still stops movement and fire at its own face.
		var space := box.get_world_3d().direct_space_state
		var from := box.global_position + Vector3(-1.5, 0.0, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, box.global_position, 1))
		assert(not hit.is_empty() and hit.collider == box, crate_name + " collision answers")
		assert(is_equal_approx(snappedf((hit.position as Vector3).x, 0.001), box.global_position.x - 0.8),
			"Collision face unchanged")
	assert(meshes.size() == 1, "Both stacks share one loaded crate mesh")


func check_gear_stations(room: Node) -> bool:
	var north := room.find_child("WeaponRackNorth", true, false) as ArmoryResupplyStation
	var south := room.find_child("WeaponRackSouth", true, false) as ArmoryResupplyStation
	var rack := north.occlusion_visual as MeshInstance3D
	var other := south.occlusion_visual as MeshInstance3D
	if rack == null or other == null or rack.mesh != other.mesh:
		return false
	var box := north.get_node(^".") as CSGBox3D
	var envelope := AABB(-box.size / 2.0, box.size)
	var hit := box.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		box.global_position + Vector3(-1.5, 0, 0), box.global_position, 1))
	if not box.use_collision or envelope.size != Vector3(0.8, 2.8, 4.0) or box.transparency != 1.0 \
			or not envelope.grow(0.001).encloses(rack.get_aabb()) or hit.get("collider") != box:
		return false
	var armor := room.find_child("ArmoryArmorStation", true, false) as ArmoryArmorStation
	var original := armor.get_node(^"RackMesh") as MeshInstance3D
	var shelf := armor.get_node_or_null(^"ImportedShelf") as Node3D
	if OS.get_cmdline_user_args().has("--expect-armory-fallback"):
		return shelf == null and original.visible and not ResourceLoader.exists(CrateStackVisual.LOD_MESH_PATH)
	if shelf == null or original.visible or armor.interact_area == null:
		return false
	var imported := shelf.get_node(^"worn_metal_rack") as MeshInstance3D
	var fit := shelf.transform * imported.transform * imported.get_aabb()
	var material := imported.mesh.surface_get_material(0) as StandardMaterial3D
	return (original.transform * original.get_aabb()).grow(0.001).encloses(fit) \
		and material.albedo_texture.get_image().has_mipmaps() \
		and ResourceLoader.exists(CrateStackVisual.LOD_MESH_PATH)


func check_fallbacks() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var missing := CSGBox3D.new()
	missing.size = BOX_SIZE
	holder.add_child(missing)
	assert(CrateStackVisual.dress_box(missing, CrateStackVisual.DEFAULT_TINT, "res://nope.glb") == null,
		"Missing model is refused")
	assert(missing.transparency == 0.0 and missing.get_child_count() == 0, "Box stays as it was")
	var small := CSGBox3D.new()
	small.size = Vector3(0.3, 0.3, 0.3)
	holder.add_child(small)
	assert(CrateStackVisual.dress_box(small) == null, "A crate is never squashed to fit")
	assert(small.transparency == 0.0 and small.get_child_count() == 0, "Small box stays as it was")
	var plain := CSGBox3D.new()
	plain.size = BOX_SIZE
	plain.set_script(load(STATION))
	plain.set("imported_crate_visual", false)
	holder.add_child(plain)
	assert(plain.get("crate_visual") == null and plain.transparency == 0.0, "Opt-out keeps the box")
	var dressed := CSGBox3D.new()
	dressed.size = BOX_SIZE
	dressed.set_script(load(STATION))
	holder.add_child(dressed)
	assert(dressed.get("crate_visual") != null, "Any ammo crate box is dressed by its station")
	holder.queue_free()
	await process_frame


func check_camera_fade(room: Node) -> void:
	var first := room.find_child("AmmoCrate1", true, false) as ArmoryResupplyStation
	var second := room.find_child("AmmoCrate2", true, false) as ArmoryResupplyStation
	var first_stack := first.crate_visual.get_node(^"Crates") as MultiMeshInstance3D
	var second_stack := second.crate_visual.get_node(^"Crates") as MultiMeshInstance3D
	var shared := first_stack.material_override as StandardMaterial3D
	assert(shared != null and second_stack.material_override == shared, "Both stacks share the opaque material")
	var player := (load("res://scenes/entities/Player.tscn") as PackedScene).instantiate() as PlayerController3D
	player.name = "1"
	room.get_node(^"Players").add_child(player)
	player.set_physics_process(false)
	player.is_crouch_toggled = true
	player.global_position = first.global_position + Vector3(1.4, -0.5, 0)
	player.rotation.y = -PI / 2.0
	player.camera_rig.global_position = player.global_position
	player._process_cover_and_peeking(0.1, Vector3.ZERO)
	await frames(2)
	player._update_camera_and_occlusion(1.0 / 60.0)
	var faded := first_stack.material_override as StandardMaterial3D
	assert(player.occluded_nodes.has(first_stack), "The real crate collider redirects the fade to its visible stack")
	assert(faded != shared and faded.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Only the occluding stack should fade")
	assert(second_stack.material_override == shared and shared.albedo_color.a == 1.0, "Fading must not change the shared material")
	player.rotation.y = PI / 2.0
	player._update_camera_and_occlusion(1.0 / 60.0)
	assert(first_stack.material_override == shared, "Turning the camera clear of cover restores the shared material")
	player.queue_free()
	await process_frame


func run() -> void:
	check_loader()
	await check_fallbacks()
	var room := (load("res://scenes/main/GateRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await (room.get_node("SGCMap") as SGCMap).navigation_ready
	await frames(3)
	check_dressed(room)
	if not check_gear_stations(room):
		push_error("SGC equipment rack, re-armour shelf, crate LOD or stock fallback did not match the fit contract")
		quit(1)
		return
	await check_camera_fade(room)
	print("test_imported_crate_visual: PASS")
	await preload("res://tests/support/finish.gd").success(self)
