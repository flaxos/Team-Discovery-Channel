@tool
class_name LevelModuleDefinition
extends Resource
@export var id: StringName
@export var scene: PackedScene
@export var occupied := AABB(Vector3(-4, -0.2, -4), Vector3(8, 3.8, 8))
@export var boundary_patches: Array[LevelBoundaryPatch] = []
@export var equipment_anchors: Dictionary = {}
@export var equipment_clearances: Dictionary = {}
@export var interiors: Array[AABB] = []
@export var sockets: Array[LevelSocketDefinition] = []
@export_enum("auto", "open", "door") var connection_default: String = "auto"
@export var tags: PackedStringArray = []
@export
var visual_brief: String = "Neutral concrete and steel placeholders; preserve collision and slot bounds."


func socket(id_value: StringName) -> LevelSocketDefinition:
	for s in sockets:
		if s.id == id_value:
			return s
	return null
