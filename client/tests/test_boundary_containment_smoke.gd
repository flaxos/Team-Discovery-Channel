extends SceneTree


## Modular collision, portal floors, ballistic glass, shaft gates and void recovery.
func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	for path: String in [
		"Level28Complex/ControlRoomMezzanine/ControlObservationGlassNorth",
		"Level28Complex/LaboratorySector/ObservationWindow",
		"Level27Complex/BriefingRoom/BriefingGateRoomOverlook"
	]:
		assert((room.get_node(path) as CSGBox3D).use_collision, "Observation glass must be solid")
	for name: String in ["ShaftEast", "ShaftNorth", "ShaftSouth"]:
		assert(
			(map.get_node(name).get_child(1) as CollisionShape3D).shape is BoxShape3D,
			"Shaft must be enclosed"
		)
	var space := room.get_world_3d().direct_space_state
	for c in map.definition.connections:
		if c.kind != "walk":
			continue
		var p := c.points[0]
		var hit := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 0.5, 0), 1)
		)
		assert(
			not hit.is_empty() and absf(hit.position.y - p.y) < 0.05,
			"Portal must have flush floor: " + str(c.id)
		)
	var pawn := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	room.get_node("Players").add_child(pawn)
	pawn.set_physics_process(false)
	pawn.position = Vector3(34, 5.5, 18)
	assert(
		pawn.test_move(pawn.global_transform, Vector3(3, 0, 0)), "Empty L27 shaft must be guarded"
	)
	pawn.position = Vector3(10, -6, 10)
	pawn.velocity = Vector3(0, -20, 0)
	pawn._physics_process(0.016)
	assert(
		pawn.position.y >= 0 and pawn.velocity == Vector3.ZERO,
		"Void recovery must remain effective"
	)
	print(
		"PASS modular boundaries, flush portals, observation glass, shaft containment and void recovery"
	)
	await preload("res://tests/support/finish.gd").success(self)
