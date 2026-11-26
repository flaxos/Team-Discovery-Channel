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


static func records_display(room: ModularMission) -> Label3D:
	return station(room, 1).get_parent().get_node(^"Visuals/RecordsDisplay") as Label3D


static func assert_console_envelopes(room: ModularMission) -> void:
	var item := room.level.layout.instance(&"cmd_command")
	var module := room.level.get_node(^"cmd_command") as LevelModule
	for attachment: LevelRoomAttachment in LevelRoomComposer.resolved(item):
		if attachment.component != &"console":
			continue
		var prop := module.get_node(LevelRoomComposer.node_path(attachment)) as LevelPlaceholderProp
		var shape := prop.get_node(^"Structure/Body/Shape") as CollisionShape3D
		assert((shape.shape as BoxShape3D).size == attachment.bounds.size)
		assert(shape.global_position.is_equal_approx(prop.to_global(attachment.bounds.get_center())))
		var visuals := prop.get_node(^"Visuals") as Node3D
		assert(not (visuals.get_node(^"Mesh") as MeshInstance3D).visible)
		assert(visuals.find_children("*", "CollisionObject3D", true, false).is_empty())
		for mesh: MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
			if mesh.visible:
				assert(attachment.bounds.grow(0.005).encloses(mesh.transform * mesh.get_aabb()),
					"Command dressing fits its solid envelope: " + str(mesh.name))
