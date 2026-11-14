@tool
class_name LevelThemeResolver
extends RefCounted
const DIRECTORY = "res://resources/level_themes/"
## Every slot a mesh or prop can resolve to: the only valid keys of a theme's materials.
const SLOTS: PackedStringArray = ["floor", "ceiling", "door_frame", "portal", "wall", "detail", "prop"]
static var _themes: Dictionary = {}
static var _theme_files: PackedStringArray = []


static func definitions() -> Array[LevelVisualTheme]:
	var result: Array[LevelVisualTheme] = []
	var files := DirAccess.get_files_at(DIRECTORY)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var resource := load(DIRECTORY + file)
			if resource is LevelVisualTheme:
				result.append(resource)
	return result


static func registry() -> Dictionary:
	var files := DirAccess.get_files_at(DIRECTORY)
	files.sort()
	if _themes.is_empty() or files != _theme_files:
		_themes.clear()
		_theme_files = files
		for theme in definitions():
			_themes[theme.id] = theme
	return _themes


static func selected(layout: LevelLayout, item: LevelModuleInstance) -> LevelVisualTheme:
	if item.theme != null:
		return item.theme
	var id := item.theme_id
	if id == &"" and item.style != &"neutral" and item.style != &"":
		id = item.style
	if id == &"" and layout != null:
		for zone in layout.theme_zones:
			if zone != null and zone.id == item.theme_zone:
				id = zone.theme_id
	if id == &"":
		id = layout.default_theme if layout != null else &"neutral"
	var themes := registry()
	return themes.get(id, themes.get(&"neutral")) as LevelVisualTheme


static func chain(theme: LevelVisualTheme) -> Array[LevelVisualTheme]:
	var themes := registry()
	var result: Array[LevelVisualTheme] = []
	var seen := {}
	while theme != null and not seen.has(theme.get_instance_id()):
		seen[theme.get_instance_id()] = true
		result.append(theme)
		theme = (
			themes.get(theme.fallback_id) as LevelVisualTheme if theme.fallback_id != &"" else null
		)
	return result


static func compatible(theme: LevelVisualTheme, item: LevelModuleInstance) -> bool:
	if theme.compatible_families.is_empty():
		return true
	for tag: String in item.module.tags:
		if tag in theme.compatible_families:
			return true
	return false


static func validate_scene(scene: PackedScene, seen: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	seen = seen.duplicate()
	if seen.has(scene.get_instance_id()):
		return errors
	seen[scene.get_instance_id()] = true
	var state := scene.get_state()
	if state.get_connection_count() > 0:
		errors.append("Cosmetic scene cannot contain signal connections")
	for i in range(state.get_node_count()):
		var nested := state.get_node_instance(i)
		if nested != null:
			errors.append_array(validate_scene(nested, seen))
		var type := state.get_node_type(i)
		if (
			type != &""
			and type != &"Node3D"
			and not ClassDB.is_parent_class(type, &"MeshInstance3D")
			and not ClassDB.is_parent_class(type, &"Light3D")
			and type != &"Decal"
		):
			errors.append("Cosmetic scene contains forbidden node: " + str(type))
		for j in range(state.get_node_property_count(i)):
			if (
				state.get_node_property_name(i, j) == &"script"
				and state.get_node_property_value(i, j) != null
			):
				errors.append("Cosmetic scene cannot contain scripts")
	return errors


static func validate_theme(theme: LevelVisualTheme) -> PackedStringArray:
	var errors := PackedStringArray()
	var themes := registry()
	var seen := {}
	var cursor := theme
	while cursor != null:
		if seen.has(cursor.get_instance_id()):
			errors.append("Theme fallback cycle: " + str(cursor.id))
			break
		seen[cursor.get_instance_id()] = true
		if cursor.id == &"":
			errors.append("Empty theme ID")
		for key: Variant in cursor.materials:
			if not cursor.materials[key] is Material:
				errors.append("Invalid theme material: %s/%s" % [cursor.id, key])
			if not str(key) in SLOTS:
				errors.append("Unknown theme material slot: %s/%s" % [cursor.id, key])
		if (
			cursor.lighting != null
			and (
				not is_finite(cursor.lighting.ambient_energy)
				or cursor.lighting.ambient_energy < 0
				or not is_finite(cursor.lighting.fixture_energy)
				or cursor.lighting.fixture_energy < 0
			)
		):
			errors.append("Invalid lighting palette: " + str(cursor.id))
		var ids := {}
		for variant in cursor.variants:
			if variant == null:
				errors.append("Null theme variant: " + str(cursor.id))
				continue
			if (
				variant.id == &""
				or ids.has(variant.id)
				or variant.slot == &""
				or not variant.local_transform.is_finite()
				or absf(variant.local_transform.basis.determinant()) < .001
			):
				errors.append("Invalid theme variant: %s/%s" % [cursor.id, variant.id])
			ids[variant.id] = true
			if not variant.scene_path.is_empty() and ResourceLoader.exists(variant.scene_path):
				var scene := load(variant.scene_path) as PackedScene
				if scene == null:
					errors.append(
						"Theme variant must reference a PackedScene: " + variant.scene_path
					)
				else:
					errors.append_array(validate_scene(scene))
		if cursor.fallback_id == &"":
			break
		if not themes.has(cursor.fallback_id):
			errors.append("Unknown theme fallback: %s -> %s" % [cursor.id, cursor.fallback_id])
			break
		cursor = themes[cursor.fallback_id]
	return errors


static func validate_layout(layout: LevelLayout) -> PackedStringArray:
	var errors := PackedStringArray()
	var themes := registry()
	if not themes.has(layout.default_theme):
		errors.append("Unknown map theme: " + str(layout.default_theme))
	var zones := {}
	for zone in layout.theme_zones:
		if zone == null:
			errors.append("Null theme zone")
			continue
		if zone.id == &"" or zones.has(zone.id):
			errors.append("Duplicate/empty theme zone: " + str(zone.id))
		zones[zone.id] = true
		if not themes.has(zone.theme_id):
			errors.append("Unknown zone theme: %s/%s" % [zone.id, zone.theme_id])
	var checked := {}
	for item in layout.instances:
		if item == null:
			continue
		if item.theme_zone != &"" and not zones.has(item.theme_zone):
			errors.append("Unknown theme zone: %s/%s" % [item.id, item.theme_zone])
		if item.theme_id != &"" and not themes.has(item.theme_id):
			errors.append("Unknown room theme: %s/%s" % [item.id, item.theme_id])
		var theme := selected(layout, item)
		if theme != null and not checked.has(theme.get_instance_id()):
			checked[theme.get_instance_id()] = true
			errors.append_array(validate_theme(theme))
	return errors


static func slot(node: MeshInstance3D) -> StringName:
	var name := str(node.name).to_lower()
	if name.begins_with("floor"):
		return &"floor"
	if name.begins_with("roof") or name.begins_with("ceiling"):
		return &"ceiling"
	if name.begins_with("header"):
		return &"door_frame"
	if str(node.get_parent().name) == "Closures":
		return &"portal"
	if name.begins_with("wall"):
		return &"wall"
	return &"detail"


static func material_for(
	theme: LevelVisualTheme, item: LevelModuleInstance, slot_id: StringName
) -> Material:
	for value in chain(theme):
		if not compatible(value, item):
			continue
		if value.materials.has(str(slot_id)):
			return value.materials[str(slot_id)] as Material
		if slot_id == &"prop" and value.prop_material != null:
			return value.prop_material
		if slot_id != &"prop" and value.surface_material != null:
			return value.surface_material
	return null


static func variant_for(
	theme: LevelVisualTheme, item: LevelModuleInstance, slot_id: StringName, exact: StringName
) -> LevelThemeVariant:
	for value in chain(theme):
		if not compatible(value, item):
			continue
		for exact_module: bool in [true, false]:
			for variant in value.variants:
				if variant == null:
					continue
				if exact_module != (not variant.module_ids.is_empty()):
					continue
				if (
					not variant.module_ids.is_empty()
					and not str(item.module.id) in variant.module_ids
				):
					continue
				if variant.slot == exact or variant.slot == slot_id:
					if variant.scene_path.is_empty() or ResourceLoader.exists(variant.scene_path):
						return variant
	return null


static func mesh_bounds(node: Node3D, parent: Transform3D = Transform3D.IDENTITY) -> Array[AABB]:
	var result: Array[AABB] = []
	var pose := parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		result.append(pose * node.mesh.get_aabb())
	for child: Node in node.get_children():
		if child is Node3D:
			result.append_array(mesh_bounds(child, pose))
	return result


static func lighting(layout: LevelLayout, item: LevelModuleInstance = null) -> LevelLightingPalette:
	var placeholder := item
	if placeholder == null:
		placeholder = LevelModuleInstance.new()
	for theme in chain(selected(layout, placeholder)):
		if theme.lighting != null:
			return theme.lighting
	return null


## What a room shows. visual_source is the first theme in the chain with art of its own;
## coverage says how much of this module that theme reaches: "pieces" when it has built
## scenes for this module, "palette" when it only recolours the slabs, "generic" otherwise.
static func describe(layout: LevelLayout, item: LevelModuleInstance) -> Dictionary:
	var theme := selected(layout, item)
	var names := PackedStringArray()
	var visual_source: StringName = &"generic"
	var coverage := "generic"
	for value in chain(theme):
		names.append(str(value.id))
		if (
			visual_source == &"generic"
			and compatible(value, item)
			and value.art_status != "fallback"
		):
			visual_source = value.id
			coverage = "pieces" if pieces(value, item) > 0 else "palette"
	return {
		"requested": str(theme.id),
		"visual_source": str(visual_source),
		"coverage": coverage,
		"fallback_chain": names,
		"art_status": theme.art_status
	}


## Built scenes a theme has for this room's module (its own, not its fallbacks').
static func pieces(theme: LevelVisualTheme, item: LevelModuleInstance) -> int:
	var count := 0
	for variant in theme.variants:
		if (
			variant != null
			and not variant.scene_path.is_empty()
			and ResourceLoader.exists(variant.scene_path)
			and (variant.module_ids.is_empty() or str(item.module.id) in variant.module_ids)
		):
			count += 1
	return count


static func apply(
	layout: LevelLayout, item: LevelModuleInstance, module: LevelModule
) -> PackedStringArray:
	var warnings := PackedStringArray()
	var theme := selected(layout, item)
	if theme == null:
		return warnings
	for node: Node in module.get_node("Visuals").find_children("*", "MeshInstance3D", true, false):
		if not is_instance_valid(node):
			continue
		var cursor := node.get_parent()
		var generated := false
		while cursor != module and cursor != null:
			if cursor.has_meta("theme_cosmetic"):
				generated = true
			cursor = cursor.get_parent()
		if generated:
			continue
		var mesh := node as MeshInstance3D
		if not mesh.has_meta("theme_original_mesh"):
			if mesh.mesh == null:
				continue
			mesh.set_meta("theme_original_mesh", mesh.mesh)
			if mesh.material_override != null:
				mesh.set_meta("theme_original_material", mesh.material_override)
		var old := mesh.get_node_or_null("ThemeVisual")
		if old != null and old.has_meta("theme_cosmetic"):
			mesh.remove_child(old)
			old.free()
		mesh.mesh = mesh.get_meta("theme_original_mesh") as Mesh
		mesh.material_override = mesh.get_meta("theme_original_material", null) as Material
		var slot_id := slot(mesh)
		var material := material_for(theme, item, slot_id)
		if material != null:
			mesh.material_override = material
		var variant := variant_for(
			theme, item, slot_id, StringName(str(mesh.get_meta("visual_slot", mesh.name)))
		)
		if variant == null:
			continue
		if variant.material != null:
			mesh.material_override = variant.material
		if variant.scene_path.is_empty():
			continue
		var scene := load(variant.scene_path) as PackedScene
		if scene == null or not validate_scene(scene).is_empty():
			warnings.append(
				"Invalid cosmetic asset; generic fallback: %s/%s" % [item.id, variant.id]
			)
			continue
		var visual := scene.instantiate() as Node3D
		if visual == null:
			continue
		var bounds := mesh_bounds(visual, variant.local_transform)
		var joined := AABB()
		if not bounds.is_empty():
			joined = bounds[0]
			for box in bounds:
				joined = joined.merge(box)
		var expected: Vector3 = mesh.get_meta("dimensions", mesh.mesh.get_aabb().size)
		var envelope := AABB(-expected / 2, expected)
		var fits := not bounds.is_empty() and envelope.grow(.01).encloses(joined)
		if slot_id != &"detail":
			fits = (
				fits
				and joined.position.distance_to(envelope.position) < .02
				and joined.size.distance_to(envelope.size) < .02
			)
		if not fits:
			warnings.append(
				"Cosmetic slot bounds mismatch; generic fallback: %s/%s" % [item.id, variant.id]
			)
			visual.free()
			continue
		visual.name = "ThemeVisual"
		visual.transform = variant.local_transform * visual.transform
		visual.set_meta("theme_cosmetic", true)
		mesh.add_child(visual)
		visual.owner = module.owner
		var palette := lighting(layout, item)
		if palette != null:
			var lights := visual.find_children("*", "Light3D", true, false)
			if visual is Light3D:
				lights.append(visual)
			for light: Light3D in lights:
				light.light_color = palette.fixture_color
				light.light_energy = palette.fixture_energy
		mesh.mesh = null
	module.set_meta("architectural_theme", describe(layout, item))
	return warnings
