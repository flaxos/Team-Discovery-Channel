extends SceneTree
## Host owns modular NPC decisions, movement and door requests; a client only mirrors them.
const DEMO = "res://scenes/level/ModularNpcDemo.tscn"


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func open_demo(parent: Node) -> ModularNpcDemo:
	var demo := load(DEMO).instantiate() as ModularNpcDemo
	demo.name = "Demo"
	demo.unlock_after = 0.0
	parent.add_child(demo)
	return demo


func run() -> void:
	var host_root := Node3D.new()
	host_root.name = "NpcHost"
	root.add_child(host_root)
	# Separate 3D world: the client's copy of the level must not collide with the host's.
	var replica_root := SubViewport.new()
	replica_root.own_world_3d = true
	replica_root.name = "NpcReplica"
	root.add_child(replica_root)
	var host_api := SceneMultiplayer.new()
	var replica_api := SceneMultiplayer.new()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(replica_api, replica_root.get_path())
	var host_peer := ENetMultiplayerPeer.new()
	assert(host_peer.create_server(19873) == OK)
	host_api.multiplayer_peer = host_peer
	var replica_peer := ENetMultiplayerPeer.new()
	assert(replica_peer.create_client("127.0.0.1", 19873) == OK)
	replica_api.multiplayer_peer = replica_peer
	for i in range(600):
		await process_frame
		if replica_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	assert(replica_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	# The client builds the same level first, so spawned actors and door state have a home.
	var replica := open_demo(replica_root)
	var host := open_demo(host_root)
	while not (host.is_started and replica.is_started):
		assert(host.level.last_errors.is_empty() and replica.level.last_errors.is_empty())
		await process_frame
	assert(host.jaffa != null and replica.jaffa == null, "Only the host spawns and commands NPCs")
	await frames(30)
	assert(replica.hostiles.get_child_count() == 1 and replica.friendlies.get_child_count() == 2)
	var mirror := replica.hostiles.get_child(0) as JaffaAI
	assert(mirror.name == host.jaffa.name and mirror.get_multiplayer_authority() == 1)
	var start := host.jaffa.global_position
	var hub_door := "Level/" + str(door_name(host.level, &"hub", &"width_adapter"))
	var host_door := host.get_node(hub_door) as ModularDoor
	var replica_door := replica.get_node(hub_door) as ModularDoor
	assert(not host_door.is_open and not replica_door.is_open)
	assert(replica.security_door.locked, "Server lock reached the client")
	for i in range(60 * 90):
		await physics_frame
		if host_door.is_open:
			break
	assert(host_door.is_open, "Host Jaffa opened the door on its patrol")
	await frames(30)
	assert(replica_door.is_open and replica_door.collision_layer == 0, "Door state replicated")
	assert(host.jaffa.global_position.distance_to(start) > 12.0)
	assert(
		mirror.global_position.distance_to(host.jaffa.global_position) < 1.0,
		"Replica follows host movement"
	)
	assert(mirror.current_state == host.jaffa.current_state)
	# The client copy made no decisions and cannot use the server-side door interfaces.
	assert(mirror.patrol_points.is_empty() and mirror.navigator.status == "idle")
	assert(mirror.navigator.level_route == null and mirror.velocity == Vector3.ZERO)
	var cargo := "Level/" + str(door_name(host.level, &"stores_approach", &"cargo"))
	var client_cargo := replica.get_node(cargo) as ModularDoor
	var client_sentry := replica.friendlies.get_child(1) as SGCAirmanAI
	var probe := Node3D.new()
	replica.level.add_child(probe)
	probe.global_position = client_cargo.global_position + client_cargo.global_basis.z
	assert(not client_cargo.open_for(probe) and not client_cargo.is_open, "In reach, wrong peer")
	assert(not replica.security_door.set_locked(false) and host.security_door.locked)
	assert(host.sentry.navigator.status == "blocked_door")
	assert(
		client_sentry.global_position.distance_to(host.sentry.global_position) < 0.5,
		"Held actor is consistent on both peers"
	)
	host_api.multiplayer_peer = null
	replica_api.multiplayer_peer = null
	host_peer.close()
	replica_peer.close()
	host_root.queue_free()
	replica_root.queue_free()
	await frames(5)
	print("PASS host-authoritative modular NPC spawn, movement, door and lock replication")
	await preload("res://tests/support/finish.gd").success(self)


func door_name(level: LevelAssembly, a: StringName, b: StringName) -> String:
	for i in range(level.layout.connections.size()):
		var edge := level.layout.connections[i]
		if [edge.from_instance, edge.to_instance] in [[a, b], [b, a]]:
			return "Door_%03d" % i
	return ""
