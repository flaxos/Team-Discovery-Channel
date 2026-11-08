class_name SGCAssetStyle
extends Resource
## Art replacement contract. Visual bounds never redefine collision or navigation.
@export var id: StringName
@export var description: String
@export var palette: PackedColorArray
@export var roughness: float = 0.85
@export var metallic: float = 0.0
@export var texture_scale_m: float = 2.0
@export var wear: String = "Scuffed edges, restrained grime around joints; legible signage."
@export var reference: String = "https://rdanderson.com/stargate/cheyenne/index.htm"
@export var replacement_status: String = "placeholder"
@export var material_slots: PackedStringArray = ["base_color", "normal", "roughness"]
