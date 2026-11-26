extends Label3D
## Mirrors this terminal's live interact objective and the mission clock on each peer.
var _records_index := -1
var _status := "RECORDS"
var _seconds := -1


func _ready() -> void:
	_bind_mission.call_deferred()


func _bind_mission() -> void:
	var station := get_node_or_null(^"../../MissionInteract") as MissionInteractable
	if station == null or station.objective.id != &"download_records":
		return
	var objectives := station.objectives
	_records_index = objectives.definition.objectives.find(station.objective)
	if _records_index < 0:
		return
	objectives.objective_changed.connect(_update_status)
	_update_status(objectives.index)
	var events := MissionWorld.of(self).get_node_or_null(^"Events") as MissionEvents
	if events != null:
		events.countdown_changed.connect(_update_clock)
		_update_clock("", events.remaining_seconds(), events.active and events.timer_state == MissionEvents.TimerState.RUNNING)


func _update_status(progress: int) -> void:
	if progress < _records_index:
		_status = "ACCESS LOCKED"
	elif progress == _records_index:
		_status = "RECORDS READY"
	else:
		_status = "RECORDS SENT"
	_refresh_text()


func _update_clock(_label: String, remaining: float, running: bool) -> void:
	var seconds := ceili(remaining) if running else -1
	if _seconds != seconds:
		_seconds = seconds
		_refresh_text()


func _refresh_text() -> void:
	text = _status
	if _seconds >= 0:
		text += "\n%02d:%02d" % [floori(_seconds / 60.0), _seconds % 60]
