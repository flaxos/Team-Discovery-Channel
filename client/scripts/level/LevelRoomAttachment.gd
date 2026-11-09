@tool
class_name LevelRoomAttachment
extends Resource
@export var id: StringName
@export var component: StringName = &"prop"
@export var scene: PackedScene
@export var anchor: StringName
@export var local_transform := Transform3D.IDENTITY
@export var bounds := AABB()
@export var placeholder_size := Vector3.ZERO
@export var blocks_movement := false
@export var required := true
@export var reachable := true
@export var approach := Vector3.ZERO
@export var references: PackedStringArray = []
