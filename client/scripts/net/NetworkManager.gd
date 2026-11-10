class_name SGCNetworkManager
extends Node
## Core networking manager using Godot 4 native ENetMultiplayerPeer.
## Manages 4-player co-op lobby, dedicated server hosting, CLI flags, peer registration,
## authority assignment, auto-reconnection, and game start.

signal server_started()
signal peer_connected_event(peer_id: int)
signal peer_disconnected_event(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal reconnecting_tick(attempt: int, max_attempts: int)
signal auto_reconnect_failed()
signal player_list_updated()
signal game_started()
signal mission_peer_ready(peer_id: int)
signal mission_settings_changed(difficulty: int)
signal mission_restart_preparing()
signal mission_restart_released()
signal mission_selection_changed(mission_id: String)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const DIFFICULTY_EASY: int = 0
const DIFFICULTY_MEDIUM: int = 1
const DIFFICULTY_HARD: int = 2
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard"]
const DIFFICULTY_DESCRIPTIONS: Array[String] = [
	"Survive at least 3 incoming waves, then dial out and extract. No computer upgrade or Iris repair required.",
	"Survive at least 3 incoming waves and upgrade the dialing computer with the clean Lab ROM, then dial out.",
	"Survive at least 3 incoming waves, upgrade the dialing computer and repair the Iris under fire, then dial out."
]

const MISSION_SGC_DEFENSE: String = "sgc_defense"
const MISSION_SGC_UAT: String = "sgc_uat"
const MISSION_MODULAR_EXTRACTION: String = "modular_extraction_uat"
const MISSIONS: Dictionary = {
	MISSION_SGC_DEFENSE: {"name": "SGC Defense — Levels 28/27/26", "description": "Refactored three-level SGC. Defend against incoming Jaffa, complete objectives and extract.", "scene": "res://scenes/main/GateRoom.tscn"},
	MISSION_SGC_UAT: {"name": "SGC UAT Base — No Hostile Activation", "description": "Explore the same three-level SGC with lifts, stairs, props and friendly personnel. No automatic hostile gate activations or enemy waves.", "scene": "res://scenes/main/SGCUATBase.tscn"},
	MISSION_MODULAR_EXTRACTION: {"name": "Modular Extraction UAT — Development", "description": "Development slice on the modular test facility: reach the command room, download data from the main console and return to the insertion point. Jaffa patrols are active.", "scene": "res://scenes/mission/ModularExtractionMission.tscn"}
}

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
var is_dedicated_server: bool = false
var is_auto_connect: bool = false
var auto_connect_address: String = "127.0.0.1"
var server_port: int = DEFAULT_PORT
var auto_start_mission: bool = false
var auto_reconnect: bool = false
var reconnect_attempts: int = 0
const MAX_RECONNECT_ATTEMPTS: int = 5

var local_peer_id: int = 1
var selected_class_id: String = CLASS_SG3_HEAVY
var player_name: String = "O'Neill"
var selected_mission_id: String = MISSION_SGC_DEFENSE
var mission_difficulty: int = DIFFICULTY_EASY
var mission_started: bool = false
var restart_pending: bool = false

## peer_id -> Dictionary { name: String, class_id: String, node: Node3D }
var peers: Dictionary = {}

var mission_ready_peers: Dictionary = {}
var _restart_acks: Dictionary = {}

var _peer: ENetMultiplayerPeer


func is_in_active_session() -> bool:
	return _peer != null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Parse launch arguments if any
	var parsed: Dictionary = parse_cli_arguments()
	if parsed.get("dedicated", false) or parsed.get("server", false):
		is_dedicated_server = true
		start_dedicated_server(server_port)


## Retrieves combined list of OS command-line arguments and user arguments.
func get_all_cli_args() -> PackedStringArray:
	var combined: Array[String] = []
	for arg: String in OS.get_cmdline_args():
		combined.append(arg)
	for uarg: String in OS.get_cmdline_user_args():
		if not combined.has(uarg):
			combined.append(uarg)
	return PackedStringArray(combined)


## Parses command line launch arguments for dedicated server, auto-connect, and loadout overrides.
func parse_cli_arguments(custom_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var args: PackedStringArray = custom_args if not custom_args.is_empty() else get_all_cli_args()
	var result: Dictionary = {}

	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		match a:
			"--server", "--dedicated":
				result["dedicated"] = true
				is_dedicated_server = true
				is_server = true
			"--listen", "--host":
				result["listen"] = true
				is_dedicated_server = false
				is_server = true
			"--connect", "--client":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					auto_connect_address = args[i]
				result["connect"] = auto_connect_address
				is_auto_connect = true
				is_server = false
			"--port":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					server_port = args[i].to_int()
					result["port"] = server_port
			"--name", "--callsign":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					player_name = args[i]
					result["name"] = player_name
			"--class":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					var c_candidate: String = args[i]
					if CLASS_PROFILES.has(c_candidate):
						selected_class_id = c_candidate
						result["class"] = selected_class_id
			"--mission":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					if MISSIONS.has(args[i]):
						selected_mission_id = args[i]
						result["mission"] = selected_mission_id
			"--difficulty":
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					i += 1
					var tier_name: String = args[i].to_lower()
					var tiers: Dictionary = {"easy": DIFFICULTY_EASY, "medium": DIFFICULTY_MEDIUM, "mid": DIFFICULTY_MEDIUM, "hard": DIFFICULTY_HARD}
					if tiers.has(tier_name):
						mission_difficulty = tiers[tier_name]
						result["difficulty"] = mission_difficulty
			"--auto-start":
				result["auto_start"] = true
				auto_start_mission = true
			"--reconnect":
				result["reconnect"] = true
				auto_reconnect = true
		i += 1

	return result


## Starts dedicated server mode on port, without physical host player controller pawn.
func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	is_dedicated_server = true
	var err := host_game(port)
	if err == OK:
		print("NetworkManager: SGC Dedicated Server initialized on port %d." % port)
	return err


## Hosts a 4-player SGC mission server on the specified port.
func host_game(port: int = DEFAULT_PORT) -> Error:
	disconnect_game(false)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Failed to create server on port %d (Error %d)" % [port, err])
		return err
	if is_inside_tree() and multiplayer != null:
		multiplayer.multiplayer_peer = _peer
	is_server = true
	server_port = port
	local_peer_id = 1

	if is_dedicated_server:
		peers[1] = {
			"name": "SGC COMMAND (DEDICATED)",
			"class_id": "dedicated_server",
			"node": null
		}
	else:
		peers[1] = {
			"name": player_name,
			"class_id": selected_class_id,
			"node": null
		}

	server_started.emit()
	player_list_updated.emit()
	print("NetworkManager: Server started on port %d (Dedicated=%s). Peer ID: 1" % [port, str(is_dedicated_server)])
	return OK


## Joins a remote SGC mission server as a client.
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Failed to create client to %s:%d (Error %d)" % [address, port, err])
		return err
	if is_inside_tree() and multiplayer != null:
		multiplayer.multiplayer_peer = _peer
	is_server = false
	auto_connect_address = address
	server_port = port
	print("NetworkManager: Connecting to %s:%d..." % [address, port])
	return OK


## Closes existing connection or server.
func disconnect_game(reset_settings: bool = true) -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if is_inside_tree() and multiplayer != null:
		multiplayer.multiplayer_peer = null
	peers.clear()
	mission_ready_peers.clear()
	is_server = false
	local_peer_id = 1
	mission_started = false
	restart_pending = false
	if reset_settings:
		mission_difficulty = DIFFICULTY_EASY
		selected_mission_id = MISSION_SGC_DEFENSE
		mission_selection_changed.emit(selected_mission_id)
	mission_settings_changed.emit(mission_difficulty)


## Offline operatives and the host can select a mode; connected clients follow the host.
func set_mission_difficulty(tier: int) -> bool:
	if tier < DIFFICULTY_EASY or tier > DIFFICULTY_HARD or mission_started:
		return false
	if is_in_active_session() and not is_server:
		return false
	mission_difficulty = tier
	mission_settings_changed.emit(mission_difficulty)
	if is_in_active_session() and is_server:
		sync_mission_settings.rpc(mission_difficulty)
	return true


@rpc("authority", "call_remote", "reliable")
func sync_mission_settings(tier: int) -> void:
	if tier < DIFFICULTY_EASY or tier > DIFFICULTY_HARD or mission_started:
		return
	mission_difficulty = tier
	mission_settings_changed.emit(mission_difficulty)


## Include the selected mode in the transition RPC: every peer applies it before loading gameplay.
func request_start_game() -> void:
	if is_server and not mission_started:
		start_game.rpc(mission_difficulty, selected_mission_id)


@rpc("authority", "call_local", "reliable")
func start_game(tier: int = -1, mission_id: String = "") -> void:
	if mission_id != "" and not MISSIONS.has(mission_id): return
	if mission_started:
		return
	if tier != -1:
		if tier < DIFFICULTY_EASY or tier > DIFFICULTY_HARD:
			return
		mission_difficulty = tier
	if mission_id != "": selected_mission_id = mission_id
	mission_started = true
	mission_selection_changed.emit(selected_mission_id)
	mission_settings_changed.emit(mission_difficulty)
	game_started.emit()


## Retry the selected mission on every peer; clients wait for the host's decision.
func request_restart_game() -> bool:
	if not is_server or not mission_started or restart_pending:
		return false
	restart_pending = true
	_complete_mission_restart.call_deferred()
	return true


func _complete_mission_restart() -> void:
	var session: ENetMultiplayerPeer = _peer
	var tier: int = mission_difficulty
	# The host despawns replicated operatives before any peer replaces the spawner.
	# Reliable despawns must be queued ahead of the reliable world-transition RPC.
	var waiting: Array = mission_ready_peers.keys()
	_restart_acks.clear()
	if is_in_active_session():
		prepare_mission_restart.rpc()
	else:
		prepare_mission_restart()
	# Clients stop sending operative state and acknowledge before the host despawns them;
	# freeing first would leave their in-flight packets addressed to a missing node.
	var deadline: int = Time.get_ticks_msec() + 1500
	while session == _peer and Time.get_ticks_msec() < deadline:
		var pending: bool = false
		for id: int in waiting:
			if peers.has(id) and not _restart_acks.has(id):
				pending = true
		if not pending:
			break
		await get_tree().process_frame
	mission_restart_released.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not restart_pending or not mission_started or not is_server or session != _peer:
		return
	if is_in_active_session():
		restart_game.rpc(tier, selected_mission_id)
	else:
		restart_game(tier, selected_mission_id)


@rpc("authority", "call_local", "reliable")
func prepare_mission_restart() -> void:
	mission_ready_peers.clear()
	mission_restart_preparing.emit()
	if is_in_active_session() and not is_server:
		acknowledge_mission_restart.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_mission_restart() -> void:
	if is_server and restart_pending:
		_restart_acks[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_local", "reliable")
func restart_game(tier: int, mission_id: String = "") -> void:
	if mission_id != "" and not MISSIONS.has(mission_id): return
	restart_pending = false
	if not mission_started or tier < DIFFICULTY_EASY or tier > DIFFICULTY_HARD:
		return
	if mission_id != "": selected_mission_id = mission_id
	mission_selection_changed.emit(selected_mission_id)
	mission_difficulty = tier
	mission_settings_changed.emit(tier)
	game_started.emit()


@rpc("any_peer", "call_local", "reliable")
func register_player(p_name: String, p_class_id: String) -> void:
	if not CLASS_PROFILES.has(p_class_id):
		return
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
		if multiplayer.has_multiplayer_peer() and sender_id != multiplayer.get_unique_id():
			sync_mission_settings.rpc_id(sender_id, mission_difficulty)
			sync_mission_selection.rpc_id(sender_id, selected_mission_id)
		for id: int in peers:
			if id != sender_id:
				sync_peer_info.rpc_id(sender_id, id, peers[id]["name"], peers[id]["class_id"])
		if mission_started and sender_id != 1:
			start_game.rpc_id(sender_id, mission_difficulty, selected_mission_id)


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
	mission_ready_peers.erase(id)
	player_list_updated.emit()
	peer_disconnected_event.emit(id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	reconnect_attempts = 0
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

	if auto_reconnect and not is_server:
		if reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
			reconnect_attempts += 1
			print("NetworkManager: Auto-reconnecting attempt %d/%d to %s:%d..." % [
				reconnect_attempts, MAX_RECONNECT_ATTEMPTS, auto_connect_address, server_port
			])
			reconnecting_tick.emit(reconnect_attempts, MAX_RECONNECT_ATTEMPTS)
			var tree := get_tree()
			if tree != null:
				var timer := tree.create_timer(1.5)
				timer.timeout.connect(func() -> void:
					if not is_in_active_session():
						join_game(auto_connect_address, server_port)
				)
		else:
			print("NetworkManager: Auto-reconnect aborted after reaching maximum attempts.")
			auto_reconnect_failed.emit()


@rpc("any_peer", "call_remote", "reliable")
func report_mission_ready() -> void:
	if not is_server or not mission_started:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender in multiplayer.get_peers() and peers.has(sender) and not mission_ready_peers.has(sender):
		mission_ready_peers[sender] = true
		sync_mission_readiness.rpc(mission_ready_peers.keys())
		mission_peer_ready.emit(sender)


@rpc("authority", "call_remote", "reliable")
func sync_mission_readiness(ready: Array) -> void:
	mission_ready_peers.clear()
	for id: int in ready:
		mission_ready_peers[id] = true


func configure_mission_sync(sync: MultiplayerSynchronizer) -> void:
	if not is_in_active_session() or sync.get_parent().multiplayer != multiplayer:
		return
	# The filter alone gates unready peers. Turning public visibility off as well would hide
	# server-owned actors from every client, because no per-peer visibility is ever granted.
	sync.add_visibility_filter(_mission_peer_visible)
	sync.update_visibility()


func _mission_peer_visible(id: int) -> bool:
	return id == 1 or mission_ready_peers.has(id)


func set_mission(mission_id: String) -> bool:
	if not MISSIONS.has(mission_id) or mission_started: return false
	if is_in_active_session() and not is_server: return false
	selected_mission_id = mission_id
	mission_selection_changed.emit(mission_id)
	if is_in_active_session() and is_server: sync_mission_selection.rpc(mission_id)
	return true

@rpc("authority", "call_remote", "reliable")
func sync_mission_selection(mission_id: String) -> void:
	if not MISSIONS.has(mission_id) or mission_started: return
	selected_mission_id = mission_id
	mission_selection_changed.emit(mission_id)
