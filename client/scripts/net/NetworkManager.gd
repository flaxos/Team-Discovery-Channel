class_name SGCNetworkManager
extends Node
## Core networking manager using Godot 4 native ENetMultiplayerPeer.
## Manages 4-player co-op lobby, peer registration, authority assignment, and game start.

signal server_started()
signal peer_connected_event(peer_id: int)
signal peer_disconnected_event(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal player_list_updated()
signal game_started()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

const CLASS_SG3_HEAVY: String = "sg3_heavy"
const CLASS_CARTER_TECH: String = "carter_tech"
const CLASS_ONEILL_RECON: String = "oneill_recon"
const CLASS_TEALC_JAFFA: String = "tealc_jaffa"

const CLASS_PROFILES: Dictionary = {
	CLASS_SG3_HEAVY: {
		"name": "SG-3 Heavy Support Marine",
		"desc": "M249 SAW, claymore mines, deployable .50 cal tripod, rocket launcher.",
		"primary": "m249",
		"secondary": "m9",
		"health": 150.0,
		"speed": 6.0
	},
	CLASS_CARTER_TECH: {
		"name": "Tech Specialist & Archaeologist",
		"desc": "MP5, Zat'nik'tel, 2x fast DHD dialer, GDO Iris override, MALP scout.",
		"primary": "mp5",
		"secondary": "zat",
		"health": 100.0,
		"speed": 6.8
	},
	CLASS_ONEILL_RECON: {
		"name": "Pointman / Recon Leader",
		"desc": "Suppressed P90, tactical C4 satchel charges, flashbangs, sprint dodge.",
		"primary": "p90",
		"secondary": "m9",
		"health": 120.0,
		"speed": 7.2
	},
	CLASS_TEALC_JAFFA: {
		"name": "Allied Jaffa / Tok'ra Infiltrator",
		"desc": "Ma'Tok Staff weapon, Zat'nik'tel, melee parry strike, symbiote regeneration.",
		"primary": "staff_weapon",
		"secondary": "zat",
		"health": 160.0,
		"speed": 6.5
	}
}

var is_server: bool = false
var local_peer_id: int = 1
var selected_class_id: String = CLASS_SG3_HEAVY
var player_name: String = "O'Neill"

## peer_id -> Dictionary { name: String, class_id: String, node: Node3D }
var peers: Dictionary = {}

var _peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Hosts a 4-player SGC mission server on the specified port.
func host_game(port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Failed to create server on port %d (Error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = _peer
	is_server = true
	local_peer_id = 1
	peers[1] = {
		"name": player_name,
		"class_id": selected_class_id,
		"node": null
	}
	server_started.emit()
	player_list_updated.emit()
	print("NetworkManager: Server started on port %d. Peer ID: 1" % port)
	return OK


## Joins a remote SGC mission server as a client.
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Failed to create client to %s:%d (Error %d)" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = _peer
	is_server = false
	print("NetworkManager: Connecting to %s:%d..." % [address, port])
	return OK


## Closes existing connection or server.
func disconnect_game() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	peers.clear()
	is_server = false
	local_peer_id = 1


## Starts the mission across all connected peers.
func request_start_game() -> void:
	if is_server:
		start_game.rpc()


@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	game_started.emit()


@rpc("any_peer", "call_local", "reliable")
func register_player(p_name: String, p_class_id: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = local_peer_id
	peers[sender_id] = {
		"name": p_name,
		"class_id": p_class_id,
		"node": null
	}
	print("NetworkManager: Registered player '%s' (%s) with Peer ID %d" % [p_name, p_class_id, sender_id])
	player_list_updated.emit()
	# If server, sync full roster to new peer
	if is_server:
		for id: int in peers:
			if id != sender_id:
				sync_peer_info.rpc_id(sender_id, id, peers[id]["name"], peers[id]["class_id"])


@rpc("authority", "call_remote", "reliable")
func sync_peer_info(peer_id: int, p_name: String, p_class_id: String) -> void:
	peers[peer_id] = {
		"name": p_name,
		"class_id": p_class_id,
		"node": null
	}
	player_list_updated.emit()


func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected with ID: %d" % id)
	peer_connected_event.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected with ID: %d" % id)
	peers.erase(id)
	player_list_updated.emit()
	peer_disconnected_event.emit(id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("NetworkManager: Successfully connected to server. Local Peer ID: %d" % local_peer_id)
	connection_succeeded.emit()
	# Register self with server
	register_player.rpc(player_name, selected_class_id)


func _on_connection_failed() -> void:
	push_warning("NetworkManager: Connection failed")
	disconnect_game()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("NetworkManager: Server disconnected")
	disconnect_game()
	server_disconnected.emit()
