@tool
class_name LevelThemeVariant
extends Resource
## Soft visual reference: absent artwork falls back instead of breaking structural resources.
@export var id: StringName
@export var slot: StringName = &"wall"
@export var module_ids: PackedStringArray = []
@export_file("*.tscn") var scene_path: String
@export var local_transform := Transform3D.IDENTITY
@export var material: Material
