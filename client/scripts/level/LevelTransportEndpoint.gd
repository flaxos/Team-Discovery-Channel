@tool
class_name LevelTransportEndpoint
extends Resource
## Structural pairing contract; no teleport or elevator mechanics live here.
@export var id: StringName
@export_enum("rings", "elevator") var kind: String = "rings"
@export var target_id: StringName
@export var anchor: StringName = &"transport"
@export var node_path: NodePath
