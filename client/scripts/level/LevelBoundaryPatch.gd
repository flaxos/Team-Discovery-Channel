@tool
class_name LevelBoundaryPatch
extends Resource
## A sampled parallelogram on a non-axis-aligned enclosed interior boundary.
@export var id: StringName
@export var origin := Vector3.ZERO
@export var span_u := Vector3.RIGHT
@export var span_v := Vector3.UP
@export var normal := Vector3.BACK
@export var socket: StringName
