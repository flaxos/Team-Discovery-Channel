class_name MissionPatrol
extends Resource
## A looping hostile patrol over named rooms; each room contributes its `marker`.
@export var rooms: PackedStringArray = []
@export var marker: StringName = &"patrol"
@export_range(1, 4) var size: int = 2
@export var shock_guard := false
@export var personal_shield := false
