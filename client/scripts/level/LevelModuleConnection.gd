@tool
class_name LevelModuleConnection
extends Resource
@export var from_instance: StringName
@export var from_socket: StringName
@export var to_instance: StringName
@export var to_socket: StringName
@export_enum("open") var state: String = "open"
