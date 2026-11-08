extends SceneTree
var room: GateRoom
var map: SGCMap


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)


func run() -> void:
	seed(271128)
	room = load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	map = room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	for ally in room.get_node("Allies").get_children():
		ally.queue_free()
	await physics_frame
	# Exercise the production friendly order state through both lift journeys.
	for c in map.definition.connections:
		if c.kind in ["spiral", "stairs"]:
			c.enabled = false
	var ally := load("res://scenes/entities/SGCAirman.tscn").instantiate() as SGCAirmanAI
	room.get_node("Allies").add_child(ally)
	ally.position = Vector3(33, 0.02, 18)
	room.sync_blast_doors(true)
	for i in range(90):
		await physics_frame
	ally.order_move_to(Vector3(5, 0, 4))
	for i in range(2000):
		await physics_frame
		if ally.position.distance_to(Vector3(5, 0, 4)) < 1.2:
			break
	check(
		ally.position.distance_to(Vector3(5, 0, 4)) < 1.2 and not room.is_blast_doors_closed,
		"Friendly AI must open a closed blast door before crossing"
	)
	ally.order_move_to(Vector3(31, 11, 18))
	for i in range(4000):
		await physics_frame
		if ally.position.distance_to(Vector3(31, 11, 18)) < 1.2:
			break
	check(
		ally.position.distance_to(Vector3(31, 11, 18)) < 1.2,
		(
			"Friendly AI must call, board and exit lifts: "
			+ str(ally.position)
			+ " "
			+ ally.navigator.status
		)
	)
	ally.queue_free()
	await physics_frame
	for c in map.definition.connections:
		c.enabled = true
	# With defenders absent, actual hostile advance states must stream into both corridors
	# and continue through the fallback floors without a visible target or a wave rewrite.
	var enemies: Array[JaffaAI] = []
	for i in range(6):
		var enemy := load("res://scenes/entities/JaffaGuard.tscn").instantiate() as JaffaAI
		enemy.name = "Overrun" + str(i)
		room.get_node("Enemies").add_child(enemy)
		enemy.position = Vector3(-8 if i % 2 == 0 else 8, 0.03, -3 - i)
		enemy.column_x_lane = -0.8 if i % 2 == 0 else 0.8
		enemy.current_state = JaffaAI.State.ADVANCE
		enemies.append(enemy)
	var west_seen := false
	var east_seen := false
	var upper_seen := false
	var support_seen := false
	for i in range(10000):
		await physics_frame
		for enemy in enemies:
			var region := map.definition.region_at(enemy.position)
			west_seen = west_seen or region == &"WEST_CORRIDOR"
			east_seen = east_seen or region == &"EAST_CORRIDOR"
			upper_seen = upper_seen or enemy.position.y > 5.0
			support_seen = support_seen or region == &"STAGING"
		if west_seen and east_seen and upper_seen and support_seen:
			break
	check(
		west_seen and east_seen and upper_seen and support_seen,
		"Seeded overrun must reach both corridors and Level 26"
	)
	check(map.overrun_stage == 2, "Corridor pressure must escalate the defensive fallback")
	print("PASS production friendly lift navigation and seeded three-floor hostile overrun")
	await preload("res://tests/support/finish.gd").success(self)
