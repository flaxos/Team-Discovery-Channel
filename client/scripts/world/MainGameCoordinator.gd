class_name MainGameCoordinator
extends Node
## Main game coordinator.
## Manages transitions between SGC Lobby UI and the GateRoom mission scene.

const LOBBY_SCENE_PATH: String = "res://scenes/main/Lobby.tscn"
const GATE_ROOM_SCENE_PATH: String = "res://scenes/main/GateRoom.tscn"

@onready var world_container: Node3D = $WorldContainer
@onready var ui_container: CanvasLayer = $UIContainer

var current_lobby: Control = null
var current_gate_room: Node3D = null


func _ready() -> void:
	_load_lobby()
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.game_started.connect(_on_game_started)


func _load_lobby() -> void:
	if current_lobby != null:
		current_lobby.queue_free()
	var lobby_scene := load(LOBBY_SCENE_PATH) as PackedScene
	if lobby_scene != null:
		current_lobby = lobby_scene.instantiate() as Control
		ui_container.add_child(current_lobby)


func _on_game_started() -> void:
	print("MainGameCoordinator: Gate dialed! Launching GateRoom mission...")
	if current_lobby != null:
		current_lobby.queue_free()
		current_lobby = null

	var gate_scene := load(GATE_ROOM_SCENE_PATH) as PackedScene
	if gate_scene != null:
		current_gate_room = gate_scene.instantiate() as Node3D
		world_container.add_child(current_gate_room)
