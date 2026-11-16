class_name ModularDoor
extends StaticBody3D
signal access_changed(access_id: StringName, is_locked: bool)
@export var security_id: StringName
@export var is_security := false
@export var locked := false
@export var width: float = 3.0
@export var height: float = 2.8
## Seconds after an AI clears the door; zero leaves AI-opened doors open.
@export var auto_close_delay: float = 2.5
var is_open := false
var prompt: Label3D
var _ai_auto_close_timer: float = 0.0
var _last_ai_actor: Node3D = null
var _waiting_navigation := false
var _pending_open := false
var _pending_locked := false


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
	material.albedo_color = Color(0.45, 0.32, 0.2) if is_security else Color(0.23, 0.32, 0.35)
	material.metallic = 0.4
	visual.material_override = material
	visual.name = "Panel"
	add_child(visual)
	prompt = Label3D.new()
	prompt.position = Vector3(0, height + 0.25, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 20
	add_child(prompt)
	_apply_open(false)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if _ai_auto_close_timer <= 0.0:
		return
	if not is_open or locked or auto_close_delay <= 0.0:
		_ai_auto_close_timer = 0.0
		return
	if _has_nearby_npc(2.5):
		_ai_auto_close_timer = auto_close_delay
		return
	_ai_auto_close_timer -= delta
	if _ai_auto_close_timer <= 0.0:
		if _can_close():
			_toggle()
			_ai_auto_close_timer = 0.0
		else:
			_ai_auto_close_timer = 0.2


func _has_nearby_npc(radius: float) -> bool:
	if (
		is_instance_valid(_last_ai_actor)
		and _last_ai_actor.is_inside_tree()
		and global_position.distance_to(_last_ai_actor.global_position) <= radius
	):
		return true
	for group_name: String in ["Enemies", "Allies"]:
		var container := MissionWorld.find(self, group_name)
		if container == null:
			continue
		for child in container.get_children():
			var npc := child as CharacterBody3D
			if npc != null and npc.collision_layer != 0 and global_position.distance_to(npc.global_position) <= radius:
				return true
	return false


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
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if locked or (is_open and not _can_close()):
		return
	var open := not is_open
	sync_open(open)
	SGCNetworkManager.mission_rpc(self, &"sync_open", [open])


## Authorised opening for server-owned AI: same reach and lock rules as a player request.
## Never unlocks. Doors opened by AI close later when clear; manually opened doors stay open.
func open_for(actor: Node3D) -> bool:
	if (
		multiplayer.multiplayer_peer == null
		or not multiplayer.is_server()
		or actor == null
		or actor.get_multiplayer_authority() != 1
		or global_position.distance_to(actor.global_position) > 3.2
	):
		return false
	var opened_by_ai := not is_open or _ai_auto_close_timer > 0.0
	if not is_open:
		_toggle()
	if is_open and opened_by_ai and auto_close_delay > 0.0:
		_last_ai_actor = actor
		_ai_auto_close_timer = auto_close_delay
	return is_open


func _can_close() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.08, height - 0.05, 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, height / 2, 0))
	query.collision_mask = 6
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()


func set_locked(value: bool) -> bool:
	if not multiplayer.is_server() or not is_security or (value and is_open and not _can_close()):
		return false
	var open := is_open and not value
	sync_security_state(open, value)
	SGCNetworkManager.mission_rpc(self, &"sync_security_state", [open, value])
	return true


@rpc("authority", "call_local", "reliable")
func sync_security_state(open: bool, value: bool) -> void:
	if _defer_security_state(open, value):
		return
	var changed := locked != value
	locked = value
	_apply_open(open)
	if changed:
		access_changed.emit(security_id, locked)


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
		sync_security_state.rpc_id(multiplayer.get_remote_sender_id(), is_open, locked)


@rpc("authority", "call_local", "reliable")
func sync_open(open: bool) -> void:
	if _defer_security_state(open, _pending_locked if _waiting_navigation else locked):
		return
	_apply_open(open)


## A late peer validates the authored layout before adopting live mission locks. Keep
## only the newest authoritative state until its LevelAssembly finishes the bake.
## Use the assembly's signal protocol here to avoid a circular script dependency.
func _defer_security_state(open: bool, value: bool) -> bool:
	if not is_inside_tree() or multiplayer.is_server():
		return false
	var assembly := get_parent()
	if not assembly.has_signal("navigation_ready") or bool(assembly.get("ready_for_navigation")):
		return false
	_pending_open = open
	_pending_locked = value
	if not _waiting_navigation:
		_waiting_navigation = true
		assembly.connect("navigation_ready", _apply_pending_security, CONNECT_ONE_SHOT)
	return true


func _apply_pending_security() -> void:
	_waiting_navigation = false
	sync_security_state(_pending_open, _pending_locked)


func _apply_open(open: bool) -> void:
	if locked and open:
		return
	is_open = open
	if not open:
		_ai_auto_close_timer = 0.0
		_last_ai_actor = null
	collision_layer = 0 if open else 1
	if has_node("Panel"):
		get_node("Panel").visible = not open
	if prompt != null:
		var label := (
			"Locked security door" if locked else ("[E] Close door" if open else "[E] Open door")
		)
		var bindings := get_node_or_null("/root/KeybindingManager")
		prompt.text = bindings.format_prompt(label) if bindings != null else label
