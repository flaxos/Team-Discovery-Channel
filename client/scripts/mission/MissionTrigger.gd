class_name MissionTrigger
extends Resource
## Completion of an authored objective releases a door or starts an extraction window.
## More conditions/actions belong here only when a mission actually needs them (D-003).
@export var id: StringName
@export var objective_id: StringName
@export_enum("release_door", "start_timer") var action: String = "release_door"
@export var security_id: StringName
@export_range(0.0, 86400.0, 0.1) var duration_seconds: float = 0.0
@export var timer_label: String = ""
@export_multiline var notice: String = ""
