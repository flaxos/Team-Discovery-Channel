class_name SGCConnection
extends Resource

@export var id: StringName
@export var from_region: StringName
@export var to_region: StringName
@export_enum("walk", "stairs", "spiral", "lift") var kind: String = "walk"
@export var points: PackedVector3Array
@export var width: float = 3.0
@export var clearance_height: float = 2.4
@export var door: bool = false
@export var enabled: bool = true
@export var cost: float = 1.0


func other(region: StringName) -> StringName:
	return to_region if region == from_region else from_region


func oriented_points(region: StringName) -> PackedVector3Array:
	var result := points.duplicate()
	if region == to_region:
		result.reverse()
	return result
