extends SceneTree
const Validator = preload("res://scripts/map/SGCEnclosureValidator.gd")
var map: SGCMap
var validator := Validator.new()


func _init() -> void:
	call_deferred("run")


func verify_closed() -> void:
	var errors := validator.validate(map)
	assert(errors.is_empty(), "Indoor map exposes void: " + str(errors))


func removed_surface_fails(node_name: String, expected: String) -> void:
	var surface := map.get_node(node_name) as Node3D
	map.remove_child(surface)
	await physics_frame
	var errors := validator.validate(map)
	map.add_child(surface)
	await physics_frame
	assert(
		not errors.is_empty() and expected in str(errors),
		"Missing " + node_name + " must fail enclosure validation: " + str(errors)
	)


func run() -> void:
	var room := load("res://scenes/main/SGCUATBase.tscn").instantiate() as GateRoom
	root.add_child(room)
	map = room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	verify_closed()
	var access := map.definition.region(&"GATE_EAST_ACCESS")
	var original_footprint := access.footprint
	access.footprint.position.x += 0.2
	assert(
		not map.definition.validate().is_empty(),
		"Even a short gap between connected rooms must fail topology validation"
	)
	access.footprint = original_footprint
	access.floor_number = 99
	assert(not map.definition.validate().is_empty(), "Unsupported floors must be rejected without crashing validation")
	access.floor_number = 28
	# A narrow crack at a portal must fail even while graph connectivity still passes.
	var wall: Node3D
	for node in map.get_children():
		if str(node.name).begins_with("WEST_SERVICEWall3_") and node.position.z < 30:
			wall = node
	assert(wall != null)
	var original := wall.position
	wall.position.z -= 0.5
	await physics_frame
	assert(map.definition.validate().is_empty(), "Connectivity alone cannot detect a wall crack")
	assert(
		"WEST_SERVICE" in str(validator.validate(map)),
		"Portal-edge crack must fail physical enclosure validation"
	)
	wall.position = original
	await physics_frame
	await removed_surface_fails("LABORATORYFloor", "LABORATORY")
	await removed_surface_fails("LABORATORYCeiling", "LABORATORY")
	# Test an opening in the connecting shaft, rather than only a room's outer wall.
	var casing: Node3D
	for node in map.get_children():
		if str(node.name).begins_with("ROUND_HALLWAY__UPPER_CORRIDOREnclosure0_"):
			casing = node
	assert(casing != null)
	await removed_surface_fails(str(casing.name), "ROUND_HALLWAY__UPPER_CORRIDOR")
	verify_closed()
	# Closure cannot depend on a moving cabin plugging the shaft at a specific level.
	var lift := room.get_node("SGCElevator") as SGCElevator
	lift.select_floor(26)
	for i in range(480):
		await physics_frame
	verify_closed()
	print(
		"PASS complete indoor shell, portal cracks, missing floors/ceilings, stair casing and lift-independent closure"
	)
	await preload("res://tests/support/finish.gd").success(self)
