@tool
extends RefCounted
signal changed
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
		result.instances.append(item.duplicate() as LevelModuleInstance)
	for edge in source.connections:
		result.connections.append(edge.duplicate() as LevelModuleConnection)
	return result


func restore(value: LevelLayout) -> void:
	layout = copy(value)
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
	item.position = position
	item.quarter_turn = turn
	result.instances.append(item)
	if result.entry_instance == &"":
		result.entry_instance = item.id
	result.destination_instance = item.id
	return result


func moved(id: StringName, position: Vector2, turn: int) -> LevelLayout:
	var result := copy(layout)
	var item := result.instance(id)
	if item != null:
		item.position = position
		item.quarter_turn = turn
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
	result.instances.assign([item.duplicate() as LevelModuleInstance])
	result.connections.clear()
	result.entry_instance = id
	result.destination_instance = id
	result.entry_marker = &"entry"
	result.destination_marker = &"destination"
	return result
