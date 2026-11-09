@tool
class_name LevelLightingPalette
extends Resource
@export var id: StringName = &"neutral"
@export var ambient_color := Color.WHITE
@export_range(0, 4) var ambient_energy := 0.8
@export var fixture_color := Color.WHITE
@export_range(0, 4) var fixture_energy := 1.0
