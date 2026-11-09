@tool
class_name LevelRoomPreset
extends Resource
@export var id: StringName
@export var label: String
@export var compatible_modules: PackedStringArray = []
@export var attachments: Array[LevelRoomAttachment] = []
@export var system_references: PackedStringArray = []
