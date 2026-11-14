class_name MainGameCoordinator
extends Node
## Main game coordinator.
## Manages transitions between SGC Lobby UI and the GateRoom mission scene.
## Supports dedicated server direct initialization and auto-connect launch flags.

const LOBBY_SCENE_PATH: String = "res://scenes/main/Lobby.tscn"
const GATE_ROOM_SCENE_PATH: String = "res://scenes/main/GateRoom.tscn"

@onready var world_container: Node3D = $WorldContainer
@onready var ui_container: CanvasLayer = $UIContainer

## The second world of a two-world mission stands this far from the first, in the same
## space. Nothing with a range reaches across (docs/plans/gate-travel-split-worlds.md).
const SITE_OFFSET := Vector3(2000.0, 0.0, 0.0)

var current_lobby: Control = null
## The mission's world; the home world when there are two.
var current_gate_room: Node3D = null
## Two-world missions only: the offworld site, and the session above both worlds.
var current_site: Node3D = null
var session: MissionSession = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		if not net.game_started.is_connected(_on_game_started):
			net.game_started.connect(_on_game_started)
		if not net.mission_restart_preparing.is_connected(_on_mission_restart_preparing):
			net.mission_restart_preparing.connect(_on_mission_restart_preparing)
		if not net.mission_restart_released.is_connected(_on_mission_restart_released):
			net.mission_restart_released.connect(_on_mission_restart_released)
		if not net.server_disconnected.is_connected(_on_server_disconnected):
			net.server_disconnected.connect(_on_server_disconnected)

		# Dedicated server mode bypasses lobby UI and initializes GateRoom arena immediately
		if net.is_dedicated_server:
			net.mission_started = true
			print("MainGameCoordinator: Dedicated server active. Initializing GateRoom directly...")
			_load_gate_room()
			return

		# Auto-connect flag automatically establishes connection to target server
		if net.is_auto_connect:
			print("MainGameCoordinator: Auto-connecting to %s:%d..." % [net.auto_connect_address, net.server_port])
			_load_lobby()
			net.join_game(net.auto_connect_address, net.server_port)
			return

	_load_lobby()


func _load_lobby() -> void:
	_clear_gate_room()
	if current_lobby != null:
		current_lobby.queue_free()
		current_lobby = null
	var lobby_scene := load(LOBBY_SCENE_PATH) as PackedScene
	if lobby_scene != null:
		current_lobby = lobby_scene.instantiate() as Control
		ui_container.add_child(current_lobby)


func _load_gate_room() -> void:
	_clear_gate_room()
	if current_lobby != null:
		current_lobby.queue_free()
		current_lobby = null

	var mission_net := get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var mission_id := mission_net.selected_mission_id if mission_net != null else SGCNetworkManager.MISSION_SGC_DEFENSE
	var entry: Dictionary = SGCNetworkManager.MISSIONS[mission_id]
	var gate_scene := load(entry["scene"]) as PackedScene
	if gate_scene != null:
		current_gate_room = gate_scene.instantiate() as Node3D
		var site_scene := load(entry["site"]) as PackedScene if entry.has("site") else null
		if site_scene == null:
			current_gate_room.set("mission_id", mission_id)
			world_container.add_child(current_gate_room)
		else:
			_add_two_worlds(site_scene)
		var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
		if net != null and net.is_in_active_session() and not net.is_server:
			net.report_mission_ready.rpc_id(1)


## Home keeps the path a single world has; the site goes in a holder beside it, far away.
## Each scene keeps its own mission id, which is what selects its rules. Every peer loads
## both worlds, so one readiness report covers them.
func _add_two_worlds(site_scene: PackedScene) -> void:
	session = MissionSession.new()
	session.name = "MissionSession"
	add_child(session)
	current_site = site_scene.instantiate() as Node3D
	session.add_world(current_gate_room)
	session.add_world(current_site)
	var holder := Node3D.new()
	holder.name = "Site"
	holder.position = SITE_OFFSET
	holder.add_child(current_site)
	world_container.add_child(current_gate_room)
	world_container.add_child(holder)
	session.present(current_gate_room)


func worlds() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for world: Node3D in [current_gate_room, current_site]:
		if is_instance_valid(world):
			found.append(world)
	return found


func _on_game_started() -> void:
	print("MainGameCoordinator: Gate dialed! Launching GateRoom mission...")
	_load_gate_room()


func _clear_gate_room() -> void:
	for world in worlds():
		var manager: Node = world.get_node_or_null("WaveManager")
		if manager != null and manager.has_method("end_mission"):
			manager.end_mission()
	# Detach immediately so the replacement owns the canonical multiplayer paths.
	for child in world_container.get_children():
		world_container.remove_child(child)
		child.queue_free()
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
	current_gate_room = null
	current_site = null
	session = null


## The server has gone: leave the dead world for the lobby instead of running it without a peer.
func _on_server_disconnected() -> void:
	if is_instance_valid(current_gate_room):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_load_lobby()


func _on_mission_restart_preparing() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	for world in worlds():
		var manager: Node = world.get_node_or_null("WaveManager")
		if manager != null and manager.has_method("end_mission"):
			manager.end_mission()
		var hud: Node = world.get_node_or_null("TacticalHUD")
		if hud != null:
			hud.set("is_mission_ended", true)
			hud.set_process(false)
		# Clients retain their old spawner and replicas until the authoritative despawns arrive,
		# but stop publishing their own operative so nothing is in flight when the host frees it.
		if net == null or net.is_server:
			continue
		var mine: Node = world.get_node_or_null("Players/" + str(net.local_peer_id))
		if mine != null and mine.has_node("MultiplayerSynchronizer"):
			(mine.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer).public_visibility = false


func _on_mission_restart_released() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null or not net.is_server:
		return
	for world in worlds():
		var players: Node = world.get_node_or_null("Players")
		if players != null:
			for player: Node in players.get_children():
				player.queue_free()
