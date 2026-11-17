class_name MissionTrigger
extends Resource
## A completed objective releases a door or starts a clock; a raised alarm can start a clock.
## More conditions/actions belong here only when a mission actually needs them (D-003).
@export var id: StringName
@export_enum("objective_completed", "alarm_raised") var condition: String = "objective_completed"
@export var objective_id: StringName
@export_enum("release_door", "start_timer") var action: String = "release_door"
@export var security_id: StringName
@export_range(0.0, 86400.0, 0.1) var duration_seconds: float = 0.0
@export var timer_label: String = ""
@export_multiline var notice: String = ""
