class_name MissionObjective
extends Resource
## One step of a sequential mission. Places are level room, marker and attachment ids;
## a mission never stores coordinates.
@export var id: StringName
## reach: a standing operative enters the room, or the marker radius when a marker is set.
## interact: an operative uses the named room attachment.
## extract: every standing operative (at least one) is inside the marker radius.
@export_enum("reach", "interact", "extract") var kind: String = "reach"
@export var room: StringName
@export var marker: StringName
@export var attachment: StringName
@export var radius: float = 3.0
@export var text: String
@export var prompt: String = "USE CONSOLE"
