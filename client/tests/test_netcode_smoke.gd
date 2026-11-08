extends SceneTree
## Headless Netcode Smoke Test for Project SGC.
## Tests Bidirectional 4-Player Co-op synchronization over port 7777:
## 1. Host (Peer 1) moving right (WASD emulation).
## 2. Client (Peer 2) moving forward (WASD emulation).
## 3. MultiplayerSpawner auto-replication across network.
## 4. MultiplayerSynchronizer continuous state sync over 60 physics ticks.
## 5. Strict assert: Distance delta between peers < 0.2 meters.

const TEST_PORT: int = 7780
const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var host_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer

var host_gateroom: Node3D
var client_gateroom: Node3D

var step: int = 0
var ticks: int = 0
var client_id: int = 0
var client_connected: bool = false
var test_passed: bool = false


func _init() -> void:
	print("==================================================")
	print("  PROJECT SGC: HEADLESS BIDIRECTIONAL NETCODE TEST")
	print("==================================================")
	call_deferred("_start_test")


func _start_test() -> void:
	# 1. Dual isolated SceneMultiplayer interfaces
	host_api = MultiplayerAPI.create_default_interface()
	client_api = MultiplayerAPI.create_default_interface()

	var host_root := Node3D.new()
	host_root.name = "HostRoot"
	root.add_child(host_root)

	var client_root := Node3D.new()
	client_root.name = "ClientRoot"
	root.add_child(client_root)

	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())

	# 2. Instantiate GateRoom on Host and Client
	var gr_scene := load(GATE_ROOM_SCENE) as PackedScene
	host_gateroom = gr_scene.instantiate() as Node3D
	host_root.add_child(host_gateroom)

	client_gateroom = gr_scene.instantiate() as Node3D
	client_root.add_child(client_gateroom)

	print("[TEST] GateRoom instantiated under HostRoot and ClientRoot.")

	# 3. Create ENet host server
	host_peer = ENetMultiplayerPeer.new()
	var err := host_peer.create_server(TEST_PORT, 4)
	if err != OK:
		_fail("Failed to create host server on port %d (Error %d)" % [TEST_PORT, err])
		return
	host_api.multiplayer_peer = host_peer
	print("[TEST] Host server started on port %d." % TEST_PORT)

	# 4. Create ENet client
	client_peer = ENetMultiplayerPeer.new()
	err = client_peer.create_client("127.0.0.1", TEST_PORT)
	if err != OK:
		_fail("Failed to connect client to port %d (Error %d)" % [TEST_PORT, err])
		return
	client_api.multiplayer_peer = client_peer
	print("[TEST] Client connecting to 127.0.0.1:%d..." % TEST_PORT)

	client_api.connected_to_server.connect(_on_client_connected)
	host_api.peer_connected.connect(_on_host_peer_connected)


func _on_client_connected() -> void:
	client_id = client_api.get_unique_id()
	print("[TEST] Client connected to server! Unique ID: %d" % client_id)
	client_connected = true


func _on_host_peer_connected(id: int) -> void:
	print("[TEST] Host received peer connection from ID: %d" % id)
	# Server spawns player for host (1) and client (id)
	_spawn_player_on_host(1, SGCNetworkManager.CLASS_SG3_HEAVY, Vector3(-3, 0.1, 7.5))
	_spawn_player_on_host(id, SGCNetworkManager.CLASS_CARTER_TECH, Vector3(3, 0.1, 7.5))


func _spawn_player_on_host(p_id: int, p_class: String, p_pos: Vector3) -> void:
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var player := player_scene.instantiate() as PlayerController3D
	player.name = str(p_id)
	player.position = p_pos
	player.class_id = p_class

	var host_players: Node3D = host_gateroom.get_node("Players") as Node3D
	host_players.add_child(player, true)
	print("[TEST] Spawned Player %d (%s) on Host at %s" % [p_id, p_class, str(p_pos)])


func _process(delta: float) -> bool:
	ticks += 1

	if ticks > 240 and not test_passed:
		_fail("Smoke test timed out after %d ticks." % ticks)
		return true

	if not client_connected or client_id == 0:
		return false

	var host_players: Node3D = host_gateroom.get_node("Players") as Node3D
	var client_players: Node3D = client_gateroom.get_node("Players") as Node3D

	var host_p1 := host_players.get_node_or_null("1") as PlayerController3D
	var client_p1 := client_players.get_node_or_null("1") as PlayerController3D
	var host_p2 := host_players.get_node_or_null(str(client_id)) as PlayerController3D
	var client_p2 := client_players.get_node_or_null(str(client_id)) as PlayerController3D

	# Wait until MultiplayerSpawner replicates both players
	if host_p1 == null or client_p1 == null or host_p2 == null or client_p2 == null:
		return false

	step += 1
	if step <= 60:
		# Host moves Player 1 right (+X)
		host_p1.velocity = Vector3(4.0, 0.0, 0.0)
		host_p1.move_and_slide()

		# Client moves Player 2 forward (-Z)
		client_p2.velocity = Vector3(0.0, 0.0, -3.5)
		client_p2.move_and_slide()

	# At frame 70, assert zero desync for both operatives
	if step == 70:
		var p1_host_pos := host_p1.global_position
		var p1_client_pos := client_p1.global_position
		var p1_delta := (p1_host_pos - p1_client_pos).length()

		var p2_host_pos := host_p2.global_position
		var p2_client_pos := client_p2.global_position
		var p2_delta := (p2_host_pos - p2_client_pos).length()

		print("[TEST] Frame 70 Synchronization Audit:")
		print("       Operative 1 (Host -> Client): Host: %s | Client: %s | Delta: %.4f m" % [str(p1_host_pos), str(p1_client_pos), p1_delta])
		print("       Operative 2 (Client -> Host): Host: %s | Client: %s | Delta: %.4f m" % [str(p2_host_pos), str(p2_client_pos), p2_delta])

		if p1_delta < 0.2 and p2_delta < 0.2:
			print("==================================================")
			print("  BIDIRECTIONAL NETCODE TEST PASSED!")
			print("  Operative 1 Delta: %.4f m < 0.20m" % p1_delta)
			print("  Operative 2 Delta: %.4f m < 0.20m" % p2_delta)
			print("==================================================")
			test_passed = true
			_cleanup()
			preload("res://tests/support/finish.gd").success(self)
			return false
		else:
			_fail("Desync detected! P1 Delta: %.4f m, P2 Delta: %.4f m" % [p1_delta, p2_delta])
			return true

	return false


func _cleanup() -> void:
	if host_api != null:
		host_api.multiplayer_peer = null
	if client_api != null:
		client_api.multiplayer_peer = null
	if host_peer != null:
		host_peer.close()
	if client_peer != null:
		client_peer.close()


func _fail(reason: String) -> void:
	push_error("[TEST FAILURE] " + reason)
	print("==================================================")
	print("  NETCODE SMOKE TEST FAILED: " + reason)
	print("==================================================")
	_cleanup()
	quit(1)
