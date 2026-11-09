@tool
class_name LevelModuleInstance
extends Resource
@export var id: StringName
@export var module: LevelModuleDefinition
@export var deck: StringName = &"deck0"
@export var position := Vector2.ZERO
@export_range(0, 3) var quarter_turn: int = 0
@export var available_sockets: PackedStringArray = []
@export var tags: PackedStringArray = []
@export var style: StringName = &"neutral"
@export var role: StringName = &""


func placement(elevation: float) -> Transform3D:
	return Transform3D(
		Basis(Vector3.UP, quarter_turn * PI / 2), Vector3(position.x, elevation, position.y)
	)


func allows(socket_id: StringName) -> bool:
	return available_sockets.is_empty() or str(socket_id) in available_sockets
