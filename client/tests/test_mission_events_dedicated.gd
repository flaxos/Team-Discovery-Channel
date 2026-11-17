extends "res://tests/test_mission_events_multiplayer.gd"
## Same console/late-join/retry contract with a pawnless dedicated host.
func dedicated() -> bool:
	return true
