@tool
extends RefCounted
signal changed
var auto_doors := true
var active_deck: StringName = &"deck0"
var layout := LevelLayout.new()
var errors := PackedStringArray()


static func copy(source: LevelLayout) -> LevelLayout:
	var result := LevelLayout.new()
	result.decks = source.decks.duplicate(true)
	result.schema_version = source.schema_version
	result.entry_instance = source.entry_instance
	result.entry_marker = source.entry_marker
	result.destination_instance = source.destination_instance
	result.destination_marker = source.destination_marker
	for item in source.instances:
		var cloned := item.duplicate() as LevelModuleInstance
		cloned.socket_decks = item.socket_decks.duplicate()
		cloned.attachment_overrides = []
		for override in item.attachment_overrides:
			cloned.attachment_overrides.append(override.duplicate() as LevelRoomOverride)
		cloned.transport_endpoints = []
		for endpoint in item.transport_endpoints:
			cloned.transport_endpoints.append(endpoint.duplicate() as LevelTransportEndpoint)
		result.instances.append(cloned)
	for edge in source.connections:
		result.connections.append(edge.duplicate() as LevelModuleConnection)
	return result


func restore(value: LevelLayout) -> void:
	layout = copy(value)
	if not layout.decks.has(str(active_deck)) and not layout.decks.is_empty():
		active_deck = StringName(layout.decks.keys()[0])
	errors.clear()
	changed.emit()


func placed(module: LevelModuleDefinition, position: Vector2, turn: int) -> LevelLayout:
	var result := copy(layout)
	var item := LevelModuleInstance.new()
	var index := 1
	while result.instance(StringName("room_%03d" % index)) != null:
		index += 1
	item.id = StringName("room_%03d" % index)
	item.module = module
	item.deck = active_deck
	item.bind_matching_decks(result.decks)
	item.position = position
	item.quarter_turn = turn
	result.instances.append(item)
	if result.entry_instance == &"":
		result.entry_instance = item.id
	result.destination_instance = item.id
	if auto_doors:
		LevelAssembler.connect_touching(result)
	return result


func moved(id: StringName, position: Vector2, turn: int) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	var changed := (
		item != null and (item.position.distance_to(position) > 0.001 or item.quarter_turn != turn)
	)
	if item != null:
		item.position = position
		item.quarter_turn = turn
	if auto_doors and changed:
		LevelAssembler.connect_touching(result)
	return result


func removed(id: StringName) -> LevelLayout:
	var result := copy(layout)
	for i in range(result.instances.size() - 1, -1, -1):
		if result.instances[i].id == id:
			result.instances.remove_at(i)
	for i in range(result.connections.size() - 1, -1, -1):
		var c := result.connections[i]
		if c.from_instance == id or c.to_instance == id:
			result.connections.remove_at(i)
	if result.entry_instance == id:
		result.entry_instance = result.instances[0].id if not result.instances.is_empty() else &""
	if result.destination_instance == id:
		result.destination_instance = (
			result.instances[-1].id if not result.instances.is_empty() else &""
		)
	return result


func accepted(candidate: LevelLayout) -> bool:
	errors = LevelLayoutValidator.validate(candidate, false)
	return errors.is_empty()


func room_layout(id: StringName) -> LevelLayout:
	var item := layout.instance(id)
	if item == null:
		return null
	var result := copy(layout)
	var isolated := result.instance(id)
	isolated.transport_endpoints = []
	result.instances.assign([isolated])
	result.connections.clear()
	result.entry_instance = id
	result.destination_instance = id
	result.entry_marker = &"entry"
	result.destination_marker = &"destination"
	return result


func deck_changed(id: String, elevation: float) -> LevelLayout:
	var result := copy(layout)
	result.decks[id] = elevation
	for item in result.instances:
		item.bind_matching_decks(result.decks)
	return result


func socket_bound(id: StringName, socket_id: StringName, deck_id: StringName) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		item.socket_decks[str(socket_id)] = str(deck_id)
	return result


func redecked(id: StringName, deck_id: StringName) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		item.deck = deck_id
		item.socket_decks.clear()
		item.bind_matching_decks(result.decks)
	return result


func configured(id: StringName, preset: LevelRoomPreset) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		item.room_preset = preset
		item.role = preset.id if preset != null else &""
	return result


func attachment_changed(
	id: StringName, attachment_id: StringName, pose: Transform3D, disabled: bool
) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		var found: LevelRoomOverride
		for override in item.attachment_overrides:
			if override.id == attachment_id:
				found = override
		if found == null:
			found = LevelRoomOverride.new()
			found.id = attachment_id
			item.attachment_overrides.append(found)
		found.local_transform = pose
		found.disabled = disabled
	return result


func attachment_reset(id: StringName, attachment_id: StringName) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		for i in range(item.attachment_overrides.size() - 1, -1, -1):
			if item.attachment_overrides[i].id == attachment_id:
				item.attachment_overrides.remove_at(i)
	return result
