extends "res://tests/test_ev2_triggers_and_acoustics_multiplayer.gd"
## Dedicated-server counterpart of EV-2 multi-process ENet trigger and objective-enabling suite.
func port() -> int:
	return 19962


func dedicated() -> bool:
	return true
