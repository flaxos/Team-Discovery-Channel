class_name GateRoom
extends Node3D
## SGC Level 28 Gate Room Arena & Stargate Ramp.
## Coordinates player spawning via MultiplayerSpawner, defensive sandbags, and gate status.

const PLAYER_SCENE_PATH: String = "res://scenes/entities/Player.tscn"

@onready var players_container: Node3D = $Players
@onready var spawns_container: Node3D = $Spawns
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var stargate_mesh: Node3D = $Stargate
@onready var event_horizon: MeshInstance3D = $Stargate/EventHorizon if has_node("Stargate/EventHorizon") else null


func _ready() -> void:
	# Configure spawner
	if spawner != null:
		spawner.spawn_path = NodePath("../Players")
		if spawner.get_spawnable_scene_count() == 0:
			spawner.add_spawnable_scene(PLAYER_SCENE_PATH)

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	# If host / server in an active game session, spawn all registered players
	if net != null and net.is_server:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawn_all_players()


func _spawn_all_players() -> void:
	var spawn_points := spawns_container.get_children()
	var spawn_index: int = 0
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager

	# Spawn host player first
	var host_class: String = SGCNetworkManager.CLASS_SG3_HEAVY
	if net != null and net.peers.has(1):
		host_class = net.peers[1].get("class_id", net.selected_class_id)
	_spawn_player(1, host_class, spawn_points[spawn_index % spawn_points.size()].global_position)
	spawn_index += 1

	# Spawn connected client peers
	if net != null:
		for peer_id: int in net.peers:
			if peer_id == 1:
				continue
			var peer_data: Dictionary = net.peers[peer_id]
			var p_class: String = peer_data.get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY)
			var spawn_pos: Vector3 = spawn_points[spawn_index % spawn_points.size()].global_position
			_spawn_player(peer_id, p_class, spawn_pos)
			spawn_index += 1


func _spawn_player(peer_id: int, p_class_id: String, spawn_pos: Vector3) -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("GateRoom: Failed to load player scene at %s" % PLAYER_SCENE_PATH)
		return

	var player_instance := player_scene.instantiate() as PlayerController3D
	player_instance.name = str(peer_id)
	player_instance.position = spawn_pos
	player_instance.class_id = p_class_id

	players_container.add_child(player_instance, true)
	print("GateRoom: Spawned player %d (%s) at %s" % [peer_id, p_class_id, str(spawn_pos)])


func _on_peer_disconnected(peer_id: int) -> void:
	var player_node := players_container.get_node_or_null(str(peer_id))
	if player_node != null:
		print("GateRoom: Removing disconnected player %d" % peer_id)
		player_node.queue_free()
