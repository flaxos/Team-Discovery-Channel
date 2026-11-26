extends SceneTree
## The palette reaches the whole live infiltration compound. Corridors, compact chambers
## and the arrival hangar use built pieces,
## and nothing a theme does changes collision or navigation (decision D-010). The same layout
## is assembled twice, once as authored and once forced to the neutral theme, and compared.
const LAYOUT := "res://resources/levels/goauld_infiltration_01.tres"
const KIT := "res://resources/level_themes/goauld/"
const PIECE_MODULES: Array[StringName] = [
	&"room01",
	&"room02",
	&"room03",
	&"room04",
	&"room05",
	&"room06",
	&"room07",
	&"room08",
	&"room09",
	&"room16",
]
const FRIEZE_BASE := 2.8


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


## Every collision shape under a level: path, pose, layer and size.
func collision(assembly: Node3D) -> Dictionary:
	var result := {}
	for node in assembly.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var body := shape.get_parent() as CollisionObject3D
		var box := shape.shape as BoxShape3D
		# Keyed by the body and the shape's index: some shapes have generated names.
		result["%s#%d" % [assembly.get_path_to(shape.get_parent()), shape.get_index()]] = [
			shape.global_transform,
			body.collision_layer if body != null else -1,
			box.size if box != null else Vector3.ZERO,
			shape.disabled
		]
	return result


## Everything a theme must leave alone: collision, navigation, module, socket and marker
## poses, and which props count as cover.
func structure(assembly: LevelAssembly) -> Dictionary:
	var poses := {}
	for item in assembly.layout.instances:
		var module := assembly.get_node(str(item.id)) as LevelModule
		poses[str(item.id)] = module.global_transform
		for group: String in ["Sockets", "Markers"]:
			for node in module.get_node(group).get_children():
				poses["%s/%s/%s" % [item.id, group, node.name]] = (node as Node3D).global_transform
	var polygons: Array[PackedInt32Array] = []
	var mesh := assembly.navigation.navigation_mesh
	for i in range(mesh.get_polygon_count()):
		polygons.append(mesh.get_polygon(i))
	return {
		"collision": collision(assembly),
		"vertices": mesh.get_vertices(),
		"polygons": polygons,
		"poses": poses,
		"cover": LevelNavigator.cover_props(assembly).size()
	}


func material_name(mesh: MeshInstance3D) -> String:
	var material := mesh.mesh.surface_get_material(0) if mesh.mesh != null else null
	return material.resource_path.get_file().get_basename() if material != null else ""


func flat(point: Vector3) -> float:
	return Vector2(point.x, point.z).length()


func run() -> void:
	var theme := LevelThemeResolver.registry()[&"goauld"] as LevelVisualTheme
	assert(LevelThemeResolver.validate_theme(theme).is_empty(), str(LevelThemeResolver.validate_theme(theme)))
	assert(theme.art_status == "authored" and theme.variants.size() == 130)
	for slot_id: String in theme.materials:
		assert(slot_id in LevelThemeResolver.SLOTS, slot_id)
	for slot_id: String in theme.decoration_slots:
		assert(slot_id in LevelThemeResolver.SLOTS, "Declared slot is a resolver slot: " + slot_id)

	# --- A material stored under a name the resolver never looks up is an error, not silence.
	var wrong := LevelVisualTheme.new()
	wrong.id = &"wrong_slots"
	wrong.materials = {"wall_panels": StandardMaterial3D.new()}
	assert("Unknown theme material slot" in str(LevelThemeResolver.validate_theme(wrong)))

	# --- The same compound, themed as authored and forced neutral.
	var source := load(LAYOUT) as LevelLayout
	assert(source.default_theme == &"goauld")
	var plain_layout := source.duplicate(true) as LevelLayout
	plain_layout.default_theme = &"neutral"
	var themed := await assemble(source)
	var with_theme := structure(themed)

	# --- Coverage: every room is Goa'uld; corridors, junctions, adapters and compact chambers have pieces.
	var pieced := 0
	var cosmetic_meshes := 0
	for item in source.instances:
		var module := themed.get_node(str(item.id)) as LevelModule
		var info := LevelThemeResolver.describe(source, item)
		var built := item.module.id in PIECE_MODULES
		assert(info.visual_source == "goauld" and info.requested == "goauld", str(info))
		assert(info.coverage == ("pieces" if built else "palette"), "%s: %s" % [item.id, info])
		assert(module.get_meta("architectural_theme").coverage == info.coverage)
		assert(LevelThemeResolver.apply(source, item, module).is_empty(), "Re-applying is clean: " + str(item.id))
		pieced += 1 if built else 0
		var floor_y := module.global_position.y
		for node in module.get_node("Visuals").get_children():
			var mesh := node as MeshInstance3D
			if mesh == null:
				continue
			var visual := mesh.get_node_or_null("ThemeVisual") as Node3D
			var slot_id := LevelThemeResolver.slot(mesh)
			if not built:
				assert(visual == null and mesh.mesh != null, "Palette only: %s/%s" % [item.id, mesh.name])
				assert(mesh.material_override == theme.materials[str(slot_id)], "%s/%s" % [item.id, mesh.name])
				continue
			assert(visual != null and mesh.mesh == null, "A piece replaces %s/%s" % [item.id, mesh.name])
			assert(visual.has_meta("theme_cosmetic"))
			assert(visual.find_children("*", "CollisionObject3D", true, false).is_empty())
			var parts := visual.find_children("*", "MeshInstance3D", true, false)
			cosmetic_meshes += parts.size()
			for part: MeshInstance3D in parts:
				var box := part.global_transform * part.mesh.get_aabb()
				# Gold stays above door-head height, clear of Jaffa and awareness markers.
				if material_name(part) == "gold":
					assert(box.position.y >= floor_y + FRIEZE_BASE - 0.001, "%s/%s/%s" % [item.id, mesh.name, part.name])
				# A floor is colour only: every part ends at the walking surface.
				if slot_id == &"floor":
					assert(is_equal_approx(box.end.y, mesh.global_position.y + 0.1), str(part.name))
			var centre := module.global_position
			var dims: Vector3 = mesh.get_meta("dimensions", Vector3.ONE)
			var thin_axis := 0 if dims.x < dims.z else 2
			if slot_id == &"wall":
				# Relief faces the room: the front layer is nearer the module's centre along the wall's thin axis.
				var plinth := visual.get_node("Plinth") as Node3D
				var mesh_local := module.to_local(mesh.global_position)
				var plinth_local := module.to_local(plinth.global_position)
				assert(
					absf(plinth_local[thin_axis]) < absf(mesh_local[thin_axis]),
					"Wall faces inward: %s/%s" % [item.id, mesh.name]
				)
				assert(material_name(visual.get_node("Band") as MeshInstance3D) == "gold")
				var pier := visual.find_children("Pier*", "MeshInstance3D", true, false)
				var jamb := visual.find_children("Jamb*", "MeshInstance3D", true, false)
				var ribs := visual.find_children("Rib*", "MeshInstance3D", true, false)
				if item.module.id == &"room04":
					# Each chamber segment: a pier in the corner, a jamb at the door.
					assert(pier.size() == 1 and jamb.size() == 1, "%s/%s" % [item.id, mesh.name])
					assert(
						flat((pier[0] as Node3D).global_position - centre) > flat((jamb[0] as Node3D).global_position - centre)
					)
				elif item.module.id == &"room01":
					assert(ribs.size() == 4)
				else:
					assert(pier.size() + jamb.size() + ribs.size() >= 1, "%s/%s" % [item.id, mesh.name])
			elif slot_id == &"door_frame":
				var cartouche := visual.get_node("Cartouche") as Node3D
				var mesh_local := module.to_local(mesh.global_position)
				var cartouche_local := module.to_local(cartouche.global_position)
				assert(absf(cartouche_local[thin_axis]) < absf(mesh_local[thin_axis]))
		# Sealed openings take the palette; they are never replaced.
		for node in module.get_node("Visuals/Closures").get_children():
			var closure := node as MeshInstance3D
			assert(closure.mesh != null and closure.material_override == theme.materials["portal"])
		# Cover and placeholder props are the light shapes at floor level.
		for attachment in LevelRoomComposer.resolved(item):
			var prop := module.get_node_or_null(LevelRoomComposer.node_path(attachment)) as LevelPlaceholderProp
			if prop != null:
				assert((prop.get_node("Visuals/Mesh") as MeshInstance3D).material_override == theme.materials["prop"])
	assert(pieced == 15, "Corridors, compact chambers and the arrival hangar have pieces: %d" % pieced)

	# --- Every built module, including those outside the compound, applies under each turn.
	for mod_id: StringName in PIECE_MODULES:
		var def := LevelCatalogue.module_by_id(mod_id)
		assert(def != null, str(mod_id))
		for turn in range(4):
			var dummy_inst := LevelModuleInstance.new()
			dummy_inst.id = mod_id
			dummy_inst.module = def
			var mod_node := def.scene.instantiate() as LevelModule
			mod_node.rotation.y = turn * PI / 2
			root.add_child(mod_node)
			var before := collision(mod_node)
			var warns := LevelThemeResolver.apply(source, dummy_inst, mod_node)
			assert(warns.is_empty(), "%s/%d: %s" % [mod_id, turn, warns])
			assert(before == collision(mod_node), "Rotated collision changes: %s/%d" % [mod_id, turn])
			assert(LevelThemeResolver.describe(source, dummy_inst).coverage == "pieces")
			for child: Node in mod_node.get_node("Visuals").get_children():
				if child is MeshInstance3D:
					assert(child.has_node("ThemeVisual") and (child as MeshInstance3D).mesh == null, "%s/%s" % [mod_id, child.name])
			mod_node.queue_free()

	# --- D-010: the same compound forced neutral has identical collision and navigation.
	# Built in the same place after the themed one is gone, so the two never touch.
	themed.queue_free()
	for i in range(4):
		await physics_frame
	var plain := await assemble(plain_layout)
	var without := structure(plain)
	var a: Dictionary = with_theme.collision
	var b: Dictionary = without.collision
	assert(a.size() == b.size() and a.size() > 200, "%d / %d collision shapes" % [a.size(), b.size()])
	for path: String in a:
		assert(b.has(path), "Collision only under the theme: " + path)
		assert((a[path][0] as Transform3D).is_equal_approx(b[path][0]), path)
		assert(a[path][1] == b[path][1] and a[path][2] == b[path][2] and a[path][3] == b[path][3], path)
	assert((with_theme.vertices as PackedVector3Array).size() > 100)
	assert(with_theme.vertices == without.vertices, "Navigation vertices differ under the theme")
	assert(with_theme.polygons == without.polygons, "Navigation polygons differ under the theme")
	assert((with_theme.poses as Dictionary).size() == (without.poses as Dictionary).size())
	for path: String in with_theme.poses:
		assert((with_theme.poses[path] as Transform3D).is_equal_approx(without.poses[path]), path)
	assert(with_theme.cover == without.cover and int(with_theme.cover) >= 7, str(with_theme.cover))

	# --- The neutral build has no trace of the kit.
	for item in plain_layout.instances:
		var info := LevelThemeResolver.describe(plain_layout, item)
		assert(info.visual_source == "neutral" and info.coverage == "palette", str(info))
		assert((plain.get_node(str(item.id)) as Node).find_children("ThemeVisual", "", true, false).is_empty())

	plain.queue_free()
	for i in range(4):
		await physics_frame
	# The CLI-authored gallery joins all nine definitions, including narrow/wide interfaces.
	var gallery_source := load("res://resources/levels/goauld_corridor_gallery.tres") as LevelLayout
	var gallery := await assemble(gallery_source)
	var gallery_state := structure(gallery)
	assert((gallery_state.vertices as PackedVector3Array).size() > 20)
	for item in gallery_source.instances:
		assert(LevelThemeResolver.describe(gallery_source, item).coverage == "pieces")
	gallery.queue_free()
	for i in range(4):
		await physics_frame
	var neutral_gallery := gallery_source.duplicate(true) as LevelLayout
	neutral_gallery.default_theme = &"neutral"
	gallery = await assemble(neutral_gallery)
	assert(gallery_state == structure(gallery), "Connected corridor gallery changes gameplay geometry or navigation")
	gallery.queue_free()
	await process_frame
	print(
		"PASS goa'uld theme: palette on 20 rooms, pieces on 15 (%d cosmetic meshes), collision, navigation, sockets and markers identical to neutral, gold above door height, flat floors, relief facing the room"
		% cosmetic_meshes
	)
	await preload("res://tests/support/finish.gd").success(self)
