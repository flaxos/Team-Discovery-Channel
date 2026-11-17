extends RefCounted
## Helpers shared by EV-2's production mission tests; no event state is manufactured here.
const ID := "generator_releases_command"


static func door(room: ModularMission) -> ModularDoor:
	for child in room.level.get_children():
		if child is ModularDoor and (child as ModularDoor).security_id == &"cmd_command":
			return child as ModularDoor
	return null


static func console(room: ModularMission) -> MissionInteractable:
	return room.level.get_node("generator").find_child("MissionInteract", true, false) as MissionInteractable


static func place(player: PlayerController3D, spot: Vector3) -> void:
	player.global_position = spot + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO


static func console_spot(room: ModularMission) -> Vector3:
	var station := console(room)
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var spot := NavigationServer3D.map_get_closest_point(room.level.navigation_map, station.global_position + offset)
		if spot.distance_to(station.global_position) < MissionInteractable.REACH - 0.3:
			return spot
	return Vector3.INF


static func stand_down(room: ModularMission) -> void:
	room.alert.set_physics_process(false)
	for enemy in room.enemies.get_children():
		(enemy as JaffaAI).stand_down()
	for player: PlayerController3D in room.players_container.get_children():
		player.health_component.current_health = 1000000.0
