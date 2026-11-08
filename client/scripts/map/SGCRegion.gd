class_name SGCRegion
extends Resource

@export var id: StringName
@export var floor_number: int = 28
@export var footprint: Rect2
@export var surface_style: StringName = &"bunker"
@export var light_energy: float = 1.8
@export var light_color: Color = Color(0.78, 0.84, 0.88)
@export var description: String
@export var reference: String
@export var confidence: String = "gameplay_extension"
@export var anchor: Vector3


func contains(point: Vector3, floor_y: float) -> bool:
	return absf(point.y - floor_y) < 2.5 and footprint.has_point(Vector2(point.x, point.z))
