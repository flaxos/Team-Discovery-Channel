extends "res://tests/support/mission_events_fixture.gd"
## Short clocks live in private resource copies, never in the cached authored mission.
const DEFINITION := "res://resources/missions/goauld_timed_extraction.tres"


static func copy_definition(source: MissionDefinition) -> MissionDefinition:
	var copy := source.duplicate() as MissionDefinition
	copy.triggers = []
	for trigger in source.triggers:
		copy.triggers.append(trigger.duplicate() as MissionTrigger)
	return copy


static func duration(room: ModularMission, seconds: float) -> void:
	var copy := copy_definition(room.definition)
	copy.triggers[1].duration_seconds = seconds
	room.definition = copy
	room.events.definition = copy
	room.objectives.definition = copy


static func station(room: ModularMission, index: int) -> MissionInteractable:
	var objective := room.definition.objectives[index]
	return room.level.get_node(str(objective.room)).find_child("MissionInteract", true, false) as MissionInteractable


static func spot(room: ModularMission, index: int) -> Vector3:
	var target := station(room, index)
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var point := NavigationServer3D.map_get_closest_point(room.level.navigation_map, target.global_position + offset)
		if point.distance_to(target.global_position) < MissionInteractable.REACH - 0.3:
			return point
	return Vector3.INF
