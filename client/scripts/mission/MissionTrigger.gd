class_name MissionTrigger
extends Resource
## Data-driven mission rule: objective completion, alert changes, or room entry can release/lock
## security doors, start an extraction timer, enable dormant objectives, or post HUD notices.
@export var id: StringName
@export_enum("objective_completed", "alarm_raised", "room_entered", "alert_searching") var condition: String = "objective_completed"
@export var objective_id: StringName
@export var room: StringName
@export_enum("release_door", "lock_door", "start_timer", "enable_objective", "show_notice") var action: String = "release_door"
@export var security_id: StringName
@export var target_objective_id: StringName
@export_range(0.0, 86400.0, 0.1) var duration_seconds: float = 0.0
@export var timer_label: String = ""
@export_multiline var notice: String = ""
