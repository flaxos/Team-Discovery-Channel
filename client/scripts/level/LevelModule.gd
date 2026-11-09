@tool
class_name LevelModule
extends Node3D
@export var instance_id: StringName
@export var definition: LevelModuleDefinition
@export_file("*.tres") var definition_path: String
@export var deck: StringName = &"deck0"
@export var socket_decks: Dictionary = {}
@export var available_sockets: PackedStringArray = []


func set_portal(id: StringName, connected: bool) -> void:
	var cap := get_node("Structure/PortalClosures/" + str(id)) as StaticBody3D
	cap.collision_layer = 0 if connected else 1
	cap.visible = not connected
	get_node("Visuals/Closures/" + str(id)).visible = not connected


func _ready() -> void:
	if definition == null and not definition_path.is_empty():
		definition = load(definition_path) as LevelModuleDefinition
