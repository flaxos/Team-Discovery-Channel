extends SceneTree
var world: Node3D
var player: PlayerController3D
var tick: int = 0
var progress: float = 0.0
var stage: int = 0

func _init() -> void:
	call_deferred("setup")

func setup() -> void:
	world = load("res://scenes/main/GateRoom.tscn").instantiate() as Node3D
	root.add_child(world)
	player = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "TraversalProbe"
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

func _physics_process(delta: float) -> bool:
	if player == null:
		return false
	tick += 1
	var stairs: Node3D = world.get_node("Level27Complex/SpiralStairsInterconnect")
	if tick == 15:
		player.global_position = stairs.path_point(0.0) + Vector3.UP * 0.05
	if tick < 15:
		return false
	if stage == 0:
		var target: Vector3 = stairs.path_point(minf(progress + 0.018, 1.0))
		var direction: Vector3 = target - player.global_position
		direction.y = 0
		if direction.length() < 0.14:
			progress = minf(progress + 0.01, 1.0)
		player.velocity = direction.normalized() * 1.8
		player.velocity.y = -1.5
		player.move_and_slide()
		if progress >= 0.99 and player.global_position.y > 5.35:
			print("PASS continuous spiral ascent: ", player.global_position)
			stage = 1
			player.global_position = Vector3(23, 0.05, 27.5)
			tick = 15
	else:
		player.velocity = Vector3(0, -1.5, -2.5)
		player.move_and_slide()
		if player.global_position.y > 5.35:
			print("PASS continuous east service ascent: ", player.global_position)
			world.queue_free()
			quit(0)
	if tick % 120 == 0:
		print("walking ", stage, " ", progress, " ", player.global_position)
		for i: int in range(player.get_slide_collision_count()):
			print("hit ", player.get_slide_collision(i).get_collider().name)
	if tick > 1800:
		push_error("Traversal timed out stage=%d progress=%.2f position=%s" % [stage, progress, player.global_position])
		quit(1)
	return false
