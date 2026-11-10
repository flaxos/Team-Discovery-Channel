@tool
class_name LevelVisualTheme
extends Resource
## Appearance only: does not alter collision, navigation or attachment transforms.
@export var id: StringName = &"neutral"
@export var display_name: String = "Neutral"
@export_multiline var description: String
@export var synonyms: PackedStringArray = []
@export var fallback_id: StringName = &"neutral"
@export var compatible_families: PackedStringArray = []
@export var lighting: LevelLightingPalette
@export var materials: Dictionary = {}
@export var variants: Array[LevelThemeVariant] = []
@export var decoration_slots: PackedStringArray = []
@export_enum("neutral", "fallback", "authored") var art_status: String = "fallback"
@export var surface_material: Material
@export var prop_material: Material
