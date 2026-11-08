extends SceneTree
## Current TPS follow + real physics occluder fade and material restoration.
var world: GateRoom
var player: PlayerController3D
var wall: CSGBox3D
var original: StandardMaterial3D
var ticks: int = 0

func _init() -> void:
	call_deferred("setup")

func setup() -> void:
	world = load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(world)
	player = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "1"
	world.get_node("Players").add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(100, 0, 0)
	wall = CSGBox3D.new()
	wall.name = "FixtureOccluder"
	wall.position = Vector3(100, 1.4, 2)
	wall.size = Vector3(4, 1.2, 0.3)
	wall.use_collision = true
	original = StandardMaterial3D.new()
	wall.material = original
	world.add_child(wall)

func _process(_delta: float) -> bool:
	if player == null:
		return false
	ticks += 1
	if ticks == 3:
		for _step: int in range(60):
			player._update_camera_and_occlusion(1.0 / 60.0)
		assert(player.camera_rig.global_position.distance_to(player.global_position) < 0.01, "TPS rig must track the operative, independent of reticle aim lead")
		assert(player.camera.position.z >= PlayerController3D.TPS_MIN_ZOOM and player.camera.position.z <= PlayerController3D.TPS_MAX_ZOOM, "TPS shoulder distance must stay within zoom bounds")
		print("PASS current TPS follow and shoulder framing")
	elif ticks == 6:
		player.camera_rig.global_position = player.global_position
		player.camera_rig.rotation = Vector3.ZERO
		player.camera.position = Vector3(0, 1.55, 4)
		player._update_wall_occlusion()
		assert(player.occluded_nodes.has(wall), "Real intervening collider must be detected")
		var faded := wall.material as StandardMaterial3D
		assert(faded != original and faded.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Occlusion must clone the material without mutating its source")
		assert(is_equal_approx(faded.albedo_color.a, 0.22), "Intervening wall must fade to 22%")
		assert(is_equal_approx(original.albedo_color.a, 1.0), "Source material must remain opaque")
		print("PASS physical occluder detection and non-destructive fade")
	elif ticks == 9:
		player.global_position.x = 120
		player.camera_rig.global_position = player.global_position
		player._update_wall_occlusion()
		assert(not player.occluded_nodes.has(wall) and wall.material == original, "Leaving the ray must restore the exact source material")
		world.queue_free()
		print("PASS material restoration after leaving occlusion")
		quit(0)
	return false
