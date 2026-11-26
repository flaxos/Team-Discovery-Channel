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


static func generator_lights(room: ModularMission) -> Array[MeshInstance3D]:
	var lights: Array[MeshInstance3D] = []
	var item := room.level.layout.instance(&"generator")
	var module := room.level.get_node(^"generator") as LevelModule
	for attachment: LevelRoomAttachment in LevelRoomComposer.resolved(item):
		if attachment.id not in [&"console", &"machinery"]:
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
					"Dressing must fit the original solid envelope: " + str(mesh.name))
			if mesh.name in [&"Display", &"FrontCore", &"RearCore"]:
				lights.append(mesh)
	assert(lights.size() == 3)
	return lights


static func check_generator_lights(lights: Array[MeshInstance3D], powered: bool) -> void:
	for light in lights:
		var material := light.get_active_material(0) as StandardMaterial3D
		assert(material != null and material.emission_enabled == powered,
			"Generator feedback follows the live mission release")
