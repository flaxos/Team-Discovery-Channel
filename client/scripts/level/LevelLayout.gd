@tool
class_name LevelLayout
extends Resource
@export var schema_version: int = 1
@export var decks: Dictionary = {"deck0": 0.0}
@export var default_theme: StringName = &"neutral"
@export var theme_zones: Array[LevelThemeZone] = []
@export var instances: Array[LevelModuleInstance] = []
@export var connections: Array[LevelModuleConnection] = []
@export var entry_instance: StringName
@export var entry_marker: StringName = &"entry"
@export var destination_instance: StringName
@export var destination_marker: StringName = &"destination"


func instance(id: StringName) -> LevelModuleInstance:
	for item in instances:
		if item.id == id:
			return item
	return null
