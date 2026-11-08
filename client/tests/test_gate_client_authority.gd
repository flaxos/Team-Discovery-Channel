extends SceneTree
var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var host_branch: Node3D
var client_branch: Node3D

func _init() -> void:
	call_deferred("run_test")

func frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame

func make_arena(branch: Node3D, peer_id: int) -> Node3D:
	var arena := Node3D.new()
	arena.name = "GateRoom"
	branch.add_child(arena)
	var players := Node3D.new()
	players.name = "Players"
	arena.add_child(players)
	var player := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = str(peer_id)
	player.position = Vector3(8, 0, 10)
	players.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	arena.add_child(enemies)
	var gate := load("res://scenes/props/Stargate.tscn").instantiate() as StargateRing
	arena.add_child(gate)
	var dialer := load("res://scenes/props/SGCDialingConsole.tscn").instantiate() as SGCDialingConsole
	dialer.stargate_path = NodePath("../Stargate")
	dialer.position = Vector3(8, 0, 10)
	arena.add_child(dialer)
	var waves := WaveManager.new()
	waves.name = "WaveManager"
	arena.add_child(waves)
	waves.set_physics_process(false)
	return arena

func run_test() -> void:
	host_branch = Node3D.new()
	host_branch.name = "Host"
	client_branch = Node3D.new()
	client_branch.name = "Client"
	root.add_child(host_branch)
	root.add_child(client_branch)
	host_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	set_multiplayer(host_api, host_branch.get_path())
	set_multiplayer(client_api, client_branch.get_path())
	server_peer = ENetMultiplayerPeer.new()
	assert(server_peer.create_server(19782) == OK)
	host_api.multiplayer_peer = server_peer
	client_peer = ENetMultiplayerPeer.new()
	assert(client_peer.create_client("127.0.0.1", 19782) == OK)
	client_api.multiplayer_peer = client_peer
	for _i: int in range(600):
		await process_frame
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	assert(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	var id: int = client_api.get_unique_id()
	var host: Node3D = make_arena(host_branch, id)
	var client: Node3D = make_arena(client_branch, id)
	await frames(20)
	var host_waves: WaveManager = host.get_node("WaveManager") as WaveManager
	var host_gate: StargateRing = host.get_node("Stargate") as StargateRing
	var client_gate: StargateRing = client.get_node("Stargate") as StargateRing
	var host_dialer: SGCDialingConsole = host.get_node("SGCDialingConsole") as SGCDialingConsole
	var client_dialer: SGCDialingConsole = client.get_node("SGCDialingConsole") as SGCDialingConsole
	var player: PlayerController3D = client.get_node("Players/" + str(id)) as PlayerController3D
	client_dialer.start_dialing(player)
	await frames(30)
	assert(host_dialer.current_phase == DHDDialer.DialPhase.INACTIVE, "Remote player cannot bypass three-wave objective")
	host_waves.completed_incursions = 3
	client_dialer.start_dialing(player)
	await frames(30)
	assert(host_waves.outbound_reserved and host_dialer.current_phase == DHDDialer.DialPhase.CHEVRONS, "Remote request must reserve gate on server")
	assert(client_dialer.current_phase == host_dialer.current_phase, "Server must replicate dialing phase")
	for _i: int in range(7):
		client_dialer.input_glyph(client_dialer.chevron_sequence[client_dialer.current_chevron_index])
		await frames(8)
	assert(host_gate.direction == StargateRing.GateDirection.OUTBOUND, "Client cannot choose inbound direction")
	host_gate._finish_kawoosh(host_gate.activation_id)
	await frames(90)
	assert(host_gate.event_horizon_mesh.visible and client_gate.event_horizon_mesh.visible, "Stable horizon must persist on both peers")
	for _i: int in range(4):
		client_dialer.input_glyph(client_dialer.gdo_sequence[client_dialer.gdo_index])
		await frames(8)
	assert(host_dialer.current_phase == DHDDialer.DialPhase.COMPLETE and host_gate.extraction_authorized, "Remote GDO must complete on server")
	assert(client_gate.extraction_authorized, "Extraction authorization must replicate")
	# Simulate a late joining/reloaded gate asking for the authoritative lifecycle snapshot.
	client_gate.event_horizon_mesh.hide()
	client_gate.current_state = StargateRing.GateState.INACTIVE
	client_gate.request_gate_snapshot.rpc_id(1)
	await frames(20)
	assert(client_gate.current_state == StargateRing.GateState.ACTIVE and client_gate.event_horizon_mesh.visible, "Snapshot must restore persistent horizon for a late observer")
	host_waves.end_mission()
	await frames(20)
	assert(not client_gate.event_horizon_mesh.visible, "Server closure must hide horizon on client")
	server_peer.close()
	client_peer.close()
	host_branch.queue_free()
	client_branch.queue_free()
	await process_frame
	print("PASS client dialing authority, minimum-wave enforcement, replicated horizon/GDO and late observer snapshot")
	quit(0)
