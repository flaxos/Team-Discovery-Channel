class_name LabDataPatchDrive
extends Node3D
## SGC Level 28 Optical ROM Data Patch Drive.
## Hard Mode Climax Objective: Contains clean dialing software to purge Goa'uld buffer lockout.
## An operative interacts to retrieve the ROM and escorts it back to the Control Room Mezzanine.

signal patch_retrieved(carrier: PlayerController3D)
signal patch_dropped(carrier: PlayerController3D)

@export var is_retrieved: bool = false
var carrier_player: PlayerController3D = null

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var rom_mesh: MeshInstance3D = $ROMMesh if has_node("ROMMesh") else null
@onready var glow_light: OmniLight3D = $GlowLight if has_node("GlowLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func pickup_patch(player: PlayerController3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_pickup.rpc_id(1, _room().get_path_to(player))
		return
	_apply_pickup(player)


func _room() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.get_node_or_null("WaveManager") != null:
			return node
		node = node.get_parent()
	return get_parent()


@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var player: PlayerController3D = _room().get_node_or_null(player_path) as PlayerController3D
	var sender: int = multiplayer.get_remote_sender_id()
	if player != null and (sender == 0 or player.get_multiplayer_authority() == sender):
		_apply_pickup(player)


func _apply_pickup(player: PlayerController3D) -> void:
	if is_retrieved:
		return

	is_retrieved = true
	carrier_player = player
	player.is_carrying_patch_rom = true
	if rom_mesh != null:
		rom_mesh.visible = false
	if glow_light != null:
		glow_light.visible = false
	if prompt_label != null:
		prompt_label.visible = false

	print("LabDataPatchDrive: Clean dialing ROM retrieved by %s! ESCORT TO CONTROL ROOM MAINFRAME!" % player.name)
	patch_retrieved.emit(player)
	_play_sfx("res://audio/sfx_gdo_beep.wav", 25.0)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_pickup.rpc(_room().get_path_to(player))


@rpc("authority", "call_remote", "reliable")
func sync_pickup(player_path: NodePath) -> void:
	var player: PlayerController3D = _room().get_node_or_null(player_path) as PlayerController3D
	if player != null:
		_apply_pickup(player)


func reset_patch() -> void:
	is_retrieved = false
	carrier_player = null
	if rom_mesh != null:
		rom_mesh.visible = true
	if glow_light != null:
		glow_light.visible = true
	if prompt_label != null:
		prompt_label.visible = true


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_retrieved and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = _bindings().format_prompt("[E] RETRIEVE CLEAN DIALING ROM")


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_retrieved and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "SGC OPTICAL ROM DRIVE"


func _play_sfx(path: String, max_dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
