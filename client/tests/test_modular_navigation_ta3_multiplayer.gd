extends SceneTree
## An AI-opened door's late-join snapshot and automatic closure are server-owned.


func _init() -> void:
	call_deferred("run")


func until(condition: Callable, seconds: float, description: String) -> void:
	for _i in range(int(seconds * 60.0)):
		if condition.call():
			return
		await physics_frame
	assert(false, "Timed out: " + description)


func run() -> void:
	var host := Node3D.new()
	host.name = "DoorHost"
	root.add_child(host)
	var replica := SubViewport.new()
	replica.name = "DoorReplica"
	replica.own_world_3d = true
	root.add_child(replica)
	var host_api := SceneMultiplayer.new()
	var replica_api := SceneMultiplayer.new()
	set_multiplayer(host_api, host.get_path())
	set_multiplayer(replica_api, replica.get_path())
	var server := ENetMultiplayerPeer.new()
	assert(server.create_server(19921) == OK)
	host_api.multiplayer_peer = server
	var door := ModularDoor.new()
	door.name = "Door"
	door.auto_close_delay = 0.25
	host.add_child(door)
	var actor := Node3D.new()
	host.add_child(actor)
	actor.position.z = 1.0
	assert(door.open_for(actor))
	# Connect after opening: the new client must learn the current open state by snapshot.
	var client := ENetMultiplayerPeer.new()
	assert(client.create_client("127.0.0.1", 19921) == OK)
	replica_api.multiplayer_peer = client
	await until(
		func() -> bool: return client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		10.0, "client connects"
	)
	var mirror := ModularDoor.new()
	mirror.name = "Door"
	replica.add_child(mirror)
	await until(func() -> bool: return mirror.is_open, 5.0, "late-join open snapshot")
	assert(mirror.collision_layer == 0)
	var probe := Node3D.new()
	replica.add_child(probe)
	probe.position.z = 1.0
	assert(not mirror.open_for(probe), "A client cannot operate the AI interface")
	# Even a pending client timer cannot change replicated collision or visuals.
	mirror._ai_auto_close_timer = 0.01
	for _i in range(30):
		await physics_frame
	assert(door.is_open and mirror.is_open, "Only the server runs auto-close decisions")
	actor.position.z = 4.0
	await until(func() -> bool: return not door.is_open and not mirror.is_open, 5.0, "automatic closure replicated")
	assert(door.collision_layer == 1 and mirror.collision_layer == 1)
	assert(door.get_node("Panel").visible and mirror.get_node("Panel").visible)
	host_api.multiplayer_peer = null
	replica_api.multiplayer_peer = null
	client.close()
	server.close()
	host.queue_free()
	replica.queue_free()
	for _i in range(5):
		await physics_frame
	print("PASS TA-3 late-join door snapshot and server-authoritative auto-close replication")
	await preload("res://tests/support/finish.gd").success(self)
