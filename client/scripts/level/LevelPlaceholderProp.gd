@tool
class_name LevelPlaceholderProp
extends Node3D
@export var size := Vector3.ONE


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	$Structure/Body/Shape.shape = shape
	$Structure/Body.position.y = size.y / 2
	var mesh := BoxMesh.new()
	mesh.size = size
	$Visuals/Mesh.mesh = mesh
	$Visuals/Mesh.position.y = size.y / 2
