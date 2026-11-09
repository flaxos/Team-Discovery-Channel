class_name ModularDoor
extends StaticBody3D
@export var width: float = 3.0
@export var height: float = 2.8
var is_open := false
var prompt: Label3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("modular_door")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.08, height - 0.05, 0.16)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height / 2
	add_child(collision)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	visual.mesh = box
	visual.position = collision.position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.32, 0.35)
	material.metallic = 0.4
	visual.material_override = material
	visual.name = "Panel"
	add_child(visual)
	prompt = Label3D.new()
	prompt.position = Vector3(0, height + 0.25, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 20
	add_child(prompt)
	sync_open(false)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func interact(player: Node = null) -> void:
	if (
		player == null
		or not player is Node3D
		or global_position.distance_to(player.global_position) > 3.2
	):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_toggle.rpc_id(1, player.get_path())
	else:
		_toggle()


func _toggle() -> void:
	if not multiplayer.is_server():
		return
	if is_open:
		var shape := BoxShape3D.new()
		shape.size = Vector3(width - 0.08, height - 0.05, 0.3)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, height / 2, 0))
		query.collision_mask = 6
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			return
	if multiplayer.has_multiplayer_peer():
		sync_open.rpc(not is_open)
	else:
		sync_open(not is_open)


@rpc("any_peer", "call_remote", "reliable")
func request_toggle(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var player := get_node_or_null(player_path) as CharacterBody3D
	if (
		player == null
		or player.get_multiplayer_authority() != multiplayer.get_remote_sender_id()
		or player.global_position.distance_to(global_position) > 3.2
	):
		return
	_toggle()


@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.is_server():
		sync_open.rpc_id(multiplayer.get_remote_sender_id(), is_open)


@rpc("authority", "call_local", "reliable")
func sync_open(open: bool) -> void:
	is_open = open
	collision_layer = 0 if open else 1
	if has_node("Panel"):
		get_node("Panel").visible = not open
	if prompt != null:
		var label := "[E] Close door" if open else "[E] Open door"
		var bindings := get_node_or_null("/root/KeybindingManager")
		prompt.text = bindings.format_prompt(label) if bindings != null else label
