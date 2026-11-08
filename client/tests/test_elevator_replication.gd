extends SceneTree
var host_root: Node3D
var client_root: Node3D
var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var client_peer: ENetMultiplayerPeer

func _init() -> void:
	call_deferred("run_test")

func wait_frames(count: int) -> void:
	for i: int in range(count):
		await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func run_test() -> void:
	host_root = Node3D.new()
	host_root.name = "Host"
	client_root = Node3D.new()
	client_root.name = "Client"
	root.add_child(host_root)
	root.add_child(client_root)
	host_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())
	var server_peer := ENetMultiplayerPeer.new()
	check(server_peer.create_server(19779) == OK, "Server must bind test port")
	host_api.multiplayer_peer = server_peer
	client_peer = ENetMultiplayerPeer.new()
	check(client_peer.create_client("127.0.0.1", 19779) == OK, "Client must connect")
	client_api.multiplayer_peer = client_peer
	var scene := load("res://scenes/props/SGCElevator.tscn") as PackedScene
	var host := scene.instantiate() as SGCElevator
	var client := scene.instantiate() as SGCElevator
	host_root.add_child(host)
	client_root.add_child(client)
	for i: int in range(600):
		await process_frame
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	check(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Connection timed out")
	await wait_frames(10)
	host.call_elevator(28)
	await wait_frames(30)
	check(host.is_doors_open and client.is_doors_open, "Host same-floor door opening must replicate")
	client.call_elevator(28)
	await wait_frames(30)
	check(host.is_moving and client.is_moving, "Client dispatch must move both peers")
	await wait_frames(260)
	check(host.current_floor == 27 and client.current_floor == 27, "Both peers must arrive at L27")
	host.toggle_elevator()
	await wait_frames(30)
	check(host.is_moving and client.is_moving, "Host dispatch must move both peers")
	await wait_frames(260)
	check(host.current_floor == 28 and client.current_floor == 28, "Both peers must return to L28")
	host._close_doors(func() -> void: pass)
	client._close_doors(func() -> void: pass)
	await wait_frames(60)
	client.call_elevator(28)
	await wait_frames(30)
	check(host.is_doors_open and client.is_doors_open, "Client same-floor door opening must replicate")
	server_peer.close()
	client_peer.close()
	host_root.queue_free()
	client_root.queue_free()
	await process_frame
	print("PASS host/client elevator door, dispatch and arrival replication")
	quit(0)
