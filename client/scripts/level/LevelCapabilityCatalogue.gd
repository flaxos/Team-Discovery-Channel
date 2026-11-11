@tool
class_name LevelCapabilityCatalogue
extends RefCounted
const METADATA = "res://resources/level_capabilities/semantics.tres"


static func encode(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is AABB:
		return {"position": encode(value.position), "size": encode(value.size)}
	if value is Transform3D:
		return {
			"origin": encode(value.origin),
			"basis": [encode(value.basis.x), encode(value.basis.y), encode(value.basis.z)]
		}
	if value is Resource:
		return value.resource_path
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item: Variant in value:
			result.append(encode(item))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = encode(value[key])
		return result
	return value


static func presets() -> Array[LevelRoomPreset]:
	var result: Array[LevelRoomPreset] = []
	var files := DirAccess.get_files_at("res://resources/room_presets/")
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var resource := load("res://resources/room_presets/" + file)
			if resource is LevelRoomPreset:
				result.append(resource)
	return result


static func preset_by_id(id: StringName) -> LevelRoomPreset:
	for preset in presets():
		if preset.id == id:
			return preset
	return null


static func composites() -> Array[LevelCompositeDefinition]:
	var result: Array[LevelCompositeDefinition] = []
	var files := DirAccess.get_files_at("res://resources/level_composites/")
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var resource := load("res://resources/level_composites/" + file)
			if resource is LevelCompositeDefinition:
				result.append(resource)
	return result


static func composite_by_id(id: StringName) -> LevelCompositeDefinition:
	for composite in composites():
		if composite.id == id:
			return composite
	return null


static func semantics() -> Dictionary:
	var metadata := load(METADATA) as LevelCatalogueMetadata
	var result := {}
	for entry in metadata.entries:
		result[entry.id] = entry
	return result


static func scene_metadata(scene: PackedScene) -> Dictionary:
	var result: Dictionary = {"markers": [], "attachment_branches": [], "visual_slots": []}
	var state := scene.get_state()
	for i in range(state.get_node_count()):
		var path := str(state.get_node_path(i)).trim_prefix("./")
		var properties := {}
		for j in range(state.get_node_property_count(i)):
			properties[str(state.get_node_property_name(i, j))] = state.get_node_property_value(
				i, j
			)
		if path.begins_with("Markers/"):
			result.markers.append(
				{
					"id": str(state.get_node_name(i)),
					"position":
					encode(
						properties.get(
							"position",
							(
								(properties.get("transform", Transform3D.IDENTITY) as Transform3D)
								. origin
							)
						)
					)
				}
			)
		if path.begins_with("Attachments/"):
			result.attachment_branches.append(path)
		if properties.has("metadata/visual_slot"):
			result.visual_slots.append(
				{
					"id": str(properties["metadata/visual_slot"]),
					"dimensions": encode(properties.get("metadata/dimensions", Vector3.ZERO)),
					"path": path
				}
			)
	return result


static func source_digest(paths: PackedStringArray) -> String:
	paths.sort()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		hash.update(path.to_utf8_buffer())
		if FileAccess.file_exists(path):
			hash.update(FileAccess.get_file_as_bytes(path))
	return hash.finish().hex_encode()


static func validate_sources() -> PackedStringArray:
	var errors := PackedStringArray()
	var module_ids := {}
	for module in LevelCatalogue.module_definitions():
		if module.id == &"" or module_ids.has(module.id):
			errors.append("Duplicate/empty catalogue module ID: " + str(module.id))
		module_ids[module.id] = true
	var ids := {}
	for preset in presets():
		if preset.id == &"" or ids.has(preset.id):
			errors.append("Duplicate/empty catalogue preset ID: " + str(preset.id))
		ids[preset.id] = true
		for id: String in preset.compatible_modules:
			if not module_ids.has(StringName(id)):
				errors.append("Stale preset module reference: %s/%s" % [preset.id, id])
	ids.clear()
	for theme in LevelThemeResolver.definitions():
		if theme.id == &"" or ids.has(theme.id):
			errors.append("Duplicate/empty catalogue theme ID: " + str(theme.id))
		ids[theme.id] = true
		errors.append_array(LevelThemeResolver.validate_theme(theme))
	ids.clear()
	var metadata := load(METADATA) as LevelCatalogueMetadata
	for entry in metadata.entries:
		if entry == null:
			errors.append("Null catalogue semantics entry")
			continue
		if ids.has(entry.id) or not module_ids.has(entry.id):
			errors.append("Stale/duplicate catalogue semantic reference: " + str(entry.id))
		ids[entry.id] = true
	for composite in composites():
		if composite.layout == null:
			errors.append("Missing composite layout: " + str(composite.id))
		else:
			errors.append_array(LevelLayoutValidator.validate(composite.layout))
	return errors


static func generate(detail: bool = false, query: String = "", kind: String = "all") -> Dictionary:
	var records: Array = []
	var paths := PackedStringArray([METADATA])
	var descriptions := semantics()
	var roles := presets()
	var themes := LevelThemeResolver.definitions()
	for module in LevelCatalogue.module_definitions():
		paths.append(module.resource_path)
		paths.append(module.scene.resource_path)
		var entry := descriptions.get(module.id) as LevelCapabilityDescription
		var label := (
			entry.label
			if entry != null
			else module.resource_path.get_file().get_basename().capitalize()
		)
		var record: Dictionary = {
			"kind": "module",
			"id": str(module.id),
			"name": label,
			"description": entry.description if entry != null else module.visual_brief,
			"synonyms": encode(entry.synonyms if entry != null else PackedStringArray()),
			"tags": encode(module.tags),
			"resource": module.resource_path,
			"scene": module.scene.resource_path,
			"footprint": encode(Vector2(module.occupied.size.x, module.occupied.size.z)),
			"occupied": encode(module.occupied),
			"sockets": [],
			"presets": [],
			"themes": []
		}
		for socket in module.sockets:
			var data: Dictionary = {
				"id": str(socket.id),
				"family": str(socket.family),
				"width": socket.width,
				"height": socket.height,
				"elevation_offset": socket.local_transform.origin.y
			}
			if detail:
				data.merge(
					{
						"transform": encode(socket.local_transform),
						"approach": encode(socket.approach)
					}
				)
			record.sockets.append(data)
		for preset in roles:
			if str(module.id) in preset.compatible_modules:
				record.presets.append(str(preset.id))
		record["tactical"] = module_tactics(module, entry)
		var item := LevelModuleInstance.new()
		item.module = module
		for theme in themes:
			var layout := LevelLayout.new()
			layout.default_theme = theme.id
			var theme_info := LevelThemeResolver.describe(layout, item)
			record.themes.append(theme_info if detail else str(theme.id))
		if detail:
			record.merge(scene_metadata(module.scene))
			record.merge(
				{
					"equipment_anchors": encode(module.equipment_anchors),
					"equipment_clearances": encode(module.equipment_clearances),
					"placement":
					{
						"quarter_turns": [0, 1, 2, 3],
						"translation": "horizontal",
						"deck_binding": "socket world elevation must equal bound deck elevation"
					},
					"validation_required":
					[
						"layout",
						"socket_alignment",
						"occupied_volume",
						"enclosure",
						"equipment_clearance",
						"navigation",
						"required_markers",
						"player_friendly_jaffa_traversal_regression"
					]
				}
			)
		records.append(record)
	for preset in roles:
		paths.append(preset.resource_path)
		var components: Array = []
		for attachment in preset.attachments:
			var item: Dictionary = {
				"id": str(attachment.id),
				"component": str(attachment.component),
				"required": attachment.required,
				"reachable": attachment.reachable
			}
			if detail:
				item.merge(
					{
						"scene": attachment.scene.resource_path if attachment.scene != null else "",
						"anchor": str(attachment.anchor),
						"transform": encode(attachment.local_transform),
						"bounds": encode(attachment.bounds),
						"approach": encode(attachment.approach),
						"placeholder_size": encode(attachment.placeholder_size),
						"node_path": str(LevelRoomComposer.node_path(attachment)),
						"references": encode(attachment.references)
					}
				)
			if attachment.scene != null:
				paths.append(attachment.scene.resource_path)
			components.append(item if detail else str(attachment.id))
		records.append(
			{
				"kind": "preset",
				"id": str(preset.id),
				"name": preset.label,
				"description":
				(
					preset.description
					if not preset.description.is_empty()
					else preset.label + " configuration with " + ", ".join(preset.system_references)
				),
				"synonyms": encode(preset.synonyms),
				"modules": encode(preset.compatible_modules),
				"attachments": components,
				"systems": encode(preset.system_references),
				"resource": preset.resource_path,
				"tactical": preset_tactics(preset)
			}
		)
	for theme in themes:
		paths.append(theme.resource_path)
		if theme.lighting != null:
			paths.append(theme.lighting.resource_path)
		var record: Dictionary = {
			"kind": "theme",
			"id": str(theme.id),
			"name": theme.display_name,
			"description": theme.description,
			"synonyms": encode(theme.synonyms),
			"fallback": str(theme.fallback_id),
			"art_status": theme.art_status,
			"resource": theme.resource_path,
			"families": encode(theme.compatible_families)
		}
		if detail:
			record.merge(
				{
					"materials": encode(theme.materials),
					"lighting_palette":
					theme.lighting.resource_path if theme.lighting != null else "",
					"decoration_slots": encode(theme.decoration_slots),
					"variants": []
				}
			)
			for variant in theme.variants:
				record.variants.append(
					{
						"id": str(variant.id),
						"slot": str(variant.slot),
						"modules": encode(variant.module_ids),
						"asset": variant.scene_path,
						"available":
						variant.scene_path.is_empty() or ResourceLoader.exists(variant.scene_path)
					}
				)
				if not variant.scene_path.is_empty() and FileAccess.file_exists(variant.scene_path):
					paths.append(variant.scene_path)
		records.append(record)
	for composite in composites():
		paths.append(composite.resource_path)
		paths.append(composite.layout.resource_path)
		var members: Array = []
		var used := {}
		for connection in composite.layout.connections:
			used[str(connection.from_instance) + "/" + str(connection.from_socket)] = true
			used[str(connection.to_instance) + "/" + str(connection.to_socket)] = true
		var openings: Array = []
		for item in composite.layout.instances:
			members.append(
				{
					"id": str(item.id),
					"module_id": str(item.module.id),
					"position": encode(item.position),
					"quarter_turn": item.quarter_turn,
					"deck": str(item.deck)
				}
			)
			for socket in item.module.sockets:
				if not used.has(str(item.id) + "/" + str(socket.id)) and item.allows(socket.id):
					openings.append(
						{
							"instance_id": str(item.id),
							"socket_id": str(socket.id),
							"family": str(socket.family)
						}
					)
		var record: Dictionary = {
			"kind": "composite",
			"id": str(composite.id),
			"name": composite.label,
			"description": composite.description,
			"synonyms": encode(composite.synonyms),
			"resource": composite.resource_path,
			"layout": composite.layout.resource_path,
			"openings": openings,
			"rooms": composite.layout.instances.size(),
			"entry": str(composite.layout.entry_instance),
			"decks": composite.layout.decks.keys(),
			"gameplay_roles": encode(composite.gameplay_roles),
			"presets": composite_presets(composite.layout)
		}
		if detail:
			record["members"] = members
		records.append(record)
	var filtered: Array = []
	for record: Dictionary in records:
		if kind != "all" and record.kind != kind:
			continue
		var text := JSON.stringify(record).to_lower().replace("_", " ").replace("-", " ")
		var matches := true
		for word: String in query.to_lower().replace("_", " ").replace("-", " ").split(" ", false):
			if not text.contains(word):
				matches = false
		if matches:
			filtered.append(record)
	var unique: Dictionary = {}
	for path: String in paths:
		unique[path] = true
	paths = PackedStringArray(unique.keys())
	var profile := LevelNavigation.profile()
	return {
		"schema_version": 1,
		"detail": detail,
		"query": query,
		"kind": kind,
		"source_digest": source_digest(paths),
		"sources": encode(paths) if detail else [],
		"grid_metres": LevelCatalogue.GRID_SIZE,
		"tactical_basis":
		"authored = designer intent in semantics.tres; derived = read from module/preset resources; inferred = heuristic from openings only. None of it is play-tested.",
		"agent_clearance":
		{
			"radius": profile.agent_radius,
			"height": profile.agent_height,
			"max_climb": profile.agent_max_climb,
			"max_slope": profile.agent_max_slope
		},
		"capabilities": filtered
	}


static func module_tactics(
	module: LevelModuleDefinition, entry: LevelCapabilityDescription
) -> Dictionary:
	var narrowest := INF
	var families := {}
	var rise := 0.0
	for socket in module.sockets:
		narrowest = minf(narrowest, socket.width)
		families[str(socket.family)] = true
		rise = maxf(rise, absf(socket.local_transform.origin.y))
	var height := module.occupied.size.y
	if not module.interiors.is_empty():
		height = module.interiors[0].size.y
	var markers: Array = []
	for marker: Dictionary in scene_metadata(module.scene).markers:
		markers.append(marker.id)
	var openings := module.sockets.size()
	var choke := "medium"
	if openings <= 2 and narrowest <= 3.0:
		choke = "high"
	elif openings >= 4 or narrowest > 3.0:
		choke = "low"
	return {
		"authored":
		{
			"gameplay_roles": encode(entry.gameplay_roles if entry != null else PackedStringArray()),
			"sightlines": entry.sightlines if entry != null else ""
		},
		"derived":
		{
			"openings": openings,
			"families": families.keys(),
			"narrowest_opening_m": narrowest,
			"reserved_area_m2": module.occupied.size.x * module.occupied.size.z,
			"clear_height_m": height,
			"deck_rise_m": rise,
			"markers": markers,
			"cover_props": 0,
			"equipment_anchors": module.equipment_anchors.keys()
		},
		"inferred": {"chokepoint_potential": choke}
	}


static func preset_tactics(preset: LevelRoomPreset) -> Dictionary:
	var groups := {"objective": [], "cover": [], "patrol": [], "spawn": []}
	var blocking := 0
	for attachment in preset.attachments:
		var component := str(attachment.component)
		if component in ["objective", "interaction", "console", "dhd", "gate", "rings"]:
			groups.objective.append(str(attachment.id))
		elif groups.has(component):
			groups[component].append(str(attachment.id))
		if attachment.blocks_movement or attachment.placeholder_size != Vector3.ZERO:
			blocking += 1
	return {
		"derived":
		{
			"objective_locations": groups.objective,
			"cover_attachments": groups.cover,
			"patrol_markers": groups.patrol,
			"spawn_markers": groups.spawn,
			"solid_props": blocking
		}
	}


static func composite_presets(layout: LevelLayout) -> Array:
	var result: Array = []
	for item in layout.instances:
		if item.room_preset != null and not str(item.room_preset.id) in result:
			result.append(str(item.room_preset.id))
	return result


## One short line of facts per capability, for choosing before asking for detail.
static func summarise(data: Dictionary) -> Dictionary:
	var lines: Array = []
	for record: Dictionary in data.capabilities:
		var line: Dictionary = {"kind": record.kind, "id": record.id, "name": record.name}
		if record.kind == "module":
			var sockets := {}
			for socket: Dictionary in record.sockets:
				sockets[socket.family] = sockets.get(socket.family, []) + [socket.id]
			line.merge(
				{
					"size_m": "%dx%d" % [record.footprint[0], record.footprint[1]],
					"sockets": sockets,
					"roles": record.tactical.authored.gameplay_roles,
					"sightlines": record.tactical.authored.sightlines,
					"chokepoint_inferred": record.tactical.inferred.chokepoint_potential,
					"presets": record.presets.size()
				}
			)
			if record.tactical.derived.deck_rise_m > 0.0:
				line["deck_rise_m"] = record.tactical.derived.deck_rise_m
		elif record.kind == "preset":
			line.merge(
				{
					"modules": record.modules,
					"objectives": record.tactical.derived.objective_locations,
					"cover": record.tactical.derived.cover_attachments.size(),
					"patrol_markers": record.tactical.derived.patrol_markers.size(),
					"about": record.description
				}
			)
		elif record.kind == "theme":
			line.merge({"art_status": record.art_status, "fallback": record.fallback})
		else:
			line.merge(
				{
					"rooms": record.rooms,
					"entry": record.entry,
					"decks": record.decks,
					"presets": record.presets,
					"roles": record.gameplay_roles,
					"openings": record.openings,
					"about": record.description
				}
			)
		lines.append(line)
	return {
		"schema_version": data.schema_version,
		"summary": true,
		"source_digest": data.source_digest,
		"tactical_basis": data.tactical_basis,
		"plan_kinds": LevelPlanner.KINDS,
		"capabilities": lines
	}


static func verify(snapshot: Dictionary) -> PackedStringArray:
	var live := generate(
		bool(snapshot.get("detail", true)),
		str(snapshot.get("query", "")),
		str(snapshot.get("kind", "all"))
	)
	if (
		JSON.stringify(JSON.parse_string(JSON.stringify(snapshot)))
		!= JSON.stringify(JSON.parse_string(JSON.stringify(live)))
	):
		return PackedStringArray(["Stale catalogue snapshot; regenerate from current resources"])
	return PackedStringArray()
