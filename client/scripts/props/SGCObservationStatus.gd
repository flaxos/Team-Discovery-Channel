extends Label3D
## The briefing readout follows the existing authoritative shutter state.


func _ready() -> void:
	var room := MissionWorld.of(self) as GateRoom
	if room == null:
		return
	room.observation_shutters_toggled.connect(update_status)
	update_status(room.is_observation_shutters_closed)


func update_status(closed: bool) -> void:
	text = "OBSERVATION\nSHUTTER SEALED" if closed else "OBSERVATION\nSHUTTER OPEN"
	modulate = Color(1.0, 0.5, 0.4) if closed else Color(0.55, 0.9, 1.0)
