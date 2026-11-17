class_name MissionTrigger
extends Resource
## EV-2 chunk 1: completion of an authored objective releases a named security door.
## More conditions/actions belong here only when a mission actually needs them (D-003).
@export var id: StringName
@export var objective_id: StringName
@export var security_id: StringName
@export_multiline var notice: String = ""
