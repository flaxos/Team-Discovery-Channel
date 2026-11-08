extends SceneTree
## Actual SGC capsule routes, starting on the Gate Room floor. No waypoint teleports.
var world: Node3D
var player: PlayerController3D
var route: Array[Vector3] = []
var labels: Dictionary = {}
var cursor: int = 0
var ticks: int = 0
var waypoint_ticks: int = 0

func _init() -> void:
	call_deferred("setup")

func add_point(point: Vector3, label: String = "") -> void:
	route.append(point)
	if not label.is_empty():
		labels[route.size() - 1] = label

func add_helix(ascending: bool) -> void:
	var stairs: Node3D = world.get_node("Level27Complex/SpiralStairsInterconnect")
	for index: int in range(181):
		var progress: float = float(index) / 180.0
		add_point(stairs.path_point(progress if ascending else 1.0 - progress))

func setup() -> void:
	world = load("res://scenes/main/GateRoom.tscn").instantiate() as Node3D
	root.add_child(world)
	player = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "TraversalProbe"
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position = Vector3(0, 0.05, 4)
	add_point(Vector3(0, 0, 9.5), "Gate Room -> Control Room")
	add_point(Vector3(-3.4, 0, 9.5))
	add_helix(true)
	add_point(Vector3(-5, 5.5, 14.9), "Ground floor -> spiral -> Briefing Room")
	add_point(Vector3(-5, 5.5, 15))
	add_point(Vector3(-10, 5.5, 15), "Briefing Room -> Security Operations")
	add_point(Vector3(-15, 5.5, 15))
	add_point(Vector3(-5, 5.5, 15))
	add_point(Vector3(-4, 5.5, 18.5))
	add_point(Vector3(4, 5.5, 18.5))
	add_point(Vector3(4, 5.5, 15))
	add_point(Vector3(10, 5.5, 15), "Briefing Room -> General's Office")
	add_point(Vector3(10, 5.5, 18))
	add_point(Vector3(17, 5.5, 18))
	add_point(Vector3(17, 5.5, 15))
	add_point(Vector3(23, 5.5, 15), "Office -> Upper Corridor")
	add_point(Vector3(28, 5.5, 15))
	add_point(Vector3(32, 5.5, 18), "Upper Corridor -> Elevator Lobby")
	add_point(Vector3(28, 5.5, 15))
	add_point(Vector3(23, 5.5, 15))
	add_point(Vector3(23, 5.5, 19))
	add_point(Vector3(23, 0, 28.2), "Upper Corridor -> east stairs -> Level 28")
	add_point(Vector3(26, 0, 31))
	add_point(Vector3(26, 0, 36), "East stairs -> Round Hallway")
	add_point(Vector3(39, 0, 36), "Round Hallway -> Armory")
	add_point(Vector3(47, 0, 36))
	add_point(Vector3(26, 0, 36))
	add_point(Vector3(26, 0, 47), "Round Hallway -> Laboratory")
	add_point(Vector3(22.5, 0, 47))
	add_point(Vector3(22.5, 0, 52), "Laboratory ROM bench approach")
	add_point(Vector3(22.5, 0, 47))
	add_point(Vector3(26, 0, 47))
	add_point(Vector3(26, 0, 36))
	add_point(Vector3(11, 0, 36), "Round Hallway -> Connector Tunnel")
	add_point(Vector3(2.8, 0, 36), "Connector Tunnel -> Fallback Hallway")
	add_point(Vector3(2.8, 0, 31))
	add_point(Vector3(0, 0, 28))
	add_point(Vector3(0, 0, 18), "Fallback Hallway -> Control Room")
	add_point(Vector3(0, 0, 4))
	add_point(Vector3(-23, 0, 4), "Gate Room -> West Corridor")
	add_point(Vector3(0, 0, 4))
	add_point(Vector3(23, 0, 4), "Gate Room -> East Corridor")
	add_point(Vector3(23, 0, 15), "East Corridor -> Lower Elevator Lobby")
	add_point(Vector3(20, 0, 15))
	add_point(Vector3(12, 0, 15), "Lower Elevator Lobby -> Control Connector")
	add_point(Vector3(4, 0, 15), "Control Connector -> Control Room")
	add_point(Vector3(12, 0, 15))
	add_point(Vector3(23, 0, 15))
	add_point(Vector3(26, 0, 15))
	add_point(Vector3(26, 0, 28.5))
	add_point(Vector3(23, 0, 28.5))
	add_point(Vector3(23, 0, 27.5))
	add_point(Vector3(23, 5.5, 18.2), "Level 28 -> east stairs -> Upper Corridor")
	add_point(Vector3(23, 5.5, 15))
	add_point(Vector3(17, 5.5, 15))
	add_point(Vector3(17, 5.5, 18))
	add_point(Vector3(10, 5.5, 18))
	add_point(Vector3(10, 5.5, 15))
	add_point(Vector3(4, 5.5, 15))
	add_point(Vector3(4, 5.5, 18.5))
	add_point(Vector3(-4, 5.5, 18.5))
	add_point(Vector3(-5, 5.5, 14.9))
	add_point(Vector3(-5, 5.5, 12.6))
	add_helix(false)
	add_point(Vector3(-3.4, 0, 9.5), "Briefing Room -> spiral -> ground floor")
	add_point(Vector3(0, 0, 9.5))
	add_point(Vector3(0, 0, 4), "Return to Gate Room without jumping or teleporting")

func _physics_process(delta: float) -> bool:
	if player == null:
		return false
	ticks += 1
	if ticks < 20:
		return false
	if cursor == route.size():
		print("PASS full SGC room connectivity and bidirectional stairs (", route.size(), " waypoints)")
		world.queue_free()
		quit(0)
		return false
	var target: Vector3 = route[cursor]
	var direction: Vector3 = target - player.global_position
	direction.y = 0
	if direction.length() < 0.11 and absf(player.global_position.y - target.y) < 0.25:
		if labels.has(cursor):
			print("PASS ", labels[cursor], " at ", player.global_position)
		cursor += 1
		waypoint_ticks = 0
		return false
	waypoint_ticks += 1
	player.velocity.x = direction.normalized().x * 2.4
	player.velocity.z = direction.normalized().z * 2.4
	player.velocity.y = -0.2 if player.is_on_floor() else player.velocity.y - player.gravity * delta
	player.move_and_slide()
	if waypoint_ticks > 1200 or player.global_position.y < -0.5:
		push_error("Route blocked at waypoint %d target=%s actual=%s" % [cursor, target, player.global_position])
		for index: int in range(player.get_slide_collision_count()):
			print("BLOCKER ", player.get_slide_collision(index).get_collider().name, " normal=", player.get_slide_collision(index).get_normal(), " hit=", player.get_slide_collision(index).get_position(), " velocity=", player.velocity)
		quit(1)
	return false
