@tool
class_name LevelModuleConnection
extends Resource
@export var from_instance: StringName
@export var from_socket: StringName
@export var to_instance: StringName
@export var to_socket: StringName
@export var security_id: StringName
@export var initially_locked := false
@export_enum("open", "door", "security_door") var state: String = "open"
