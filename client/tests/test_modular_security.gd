extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await process_frame


func layout(locked: bool) -> LevelLayout:
	var model := Model.new()
	var corridor := (
		load("res://resources/level_modules/Room01Straight.tres") as LevelModuleDefinition
	)
	model.restore(model.placed(corridor, Vector2.ZERO, 0))
	model.restore(model.placed(corridor, Vector2(0, 8), 0))
	model.layout.connections[0].state = "security_door"
	model.layout.connections[0].security_id = &"sector_alpha"
	model.layout.connections[0].initially_locked = locked
	return model.layout


func build(source: LevelLayout) -> LevelAssembly:
	var level := LevelAssembly.new()
	level.layout = source
	root.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	return level


func run() -> void:
	var closed := await build(layout(true))
	assert(
		(
			"Blocked navigation region: room_002" in str(closed.last_errors)
			and "sector_alpha" in str(closed.last_errors)
		)
	)
	closed.queue_free()
	await process_frame
	var level := await build(layout(false))
	assert(level.last_errors.is_empty())
	var door := level.get_node("Door_000") as ModularDoor
	assert(door.is_security and door.security_id == &"sector_alpha" and not door.locked)
	var player := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "1"
	level.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.position = Vector3(0, .03, 2)
	player.camera.global_position = player.position + Vector3(0, 1.6, 0)
	player.camera.look_at(door.global_position + Vector3(0, 1.2, 0))
	player._try_interact()
	assert(door.is_open)
	player.position = door.position + Vector3(0, .03, 0)
	await physics_frame
	await physics_frame
	assert(
		not door.set_locked(true) and not door.locked and door.is_open,
		"Locking cannot close through a player"
	)
	player.position = Vector3(0, .03, 1)
	await physics_frame
	await physics_frame
	assert(door.set_locked(true) and door.locked and not door.is_open)
	door.interact(player)
	assert(not door.is_open, "Locked door rejects interaction")
	assert(door.set_locked(false))
	door.interact(player)
	assert(door.is_open)
	level.queue_free()
	await process_frame
	await multiplayer_contract()
	print(
		"PASS security lock authority, occupied guard, actual player interaction, blocked-region validation, client requests and joining-client snapshots"
	)
	await preload("res://tests/support/finish.gd").success(self)


func multiplayer_contract() -> void:
	var host_root := Node3D.new()
	host_root.name = "SecurityHost"
	root.add_child(host_root)
	var replica_root := Node3D.new()
	replica_root.name = "SecurityReplica"
	root.add_child(replica_root)
	var host_api := SceneMultiplayer.new()
	var replica_api := SceneMultiplayer.new()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(replica_api, replica_root.get_path())
	var host_peer := ENetMultiplayerPeer.new()
	assert(host_peer.create_server(19859) == OK)
	host_api.multiplayer_peer = host_peer
	var replica_peer := ENetMultiplayerPeer.new()
	assert(replica_peer.create_client("127.0.0.1", 19859) == OK)
	replica_api.multiplayer_peer = replica_peer
	for i in range(600):
		await process_frame
		if replica_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	assert(replica_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	var host_door := load("res://scenes/level/ModularDoor.tscn").instantiate() as ModularDoor
	host_door.name = "AccessDoor"
	host_door.is_security = true
	host_door.security_id = &"sector_alpha"
	host_door.locked = true
	host_root.add_child(host_door)
	var replica := load("res://scenes/level/ModularDoor.tscn").instantiate() as ModularDoor
	replica.name = "AccessDoor"
	replica.is_security = true
	replica.security_id = &"sector_alpha"
	replica_root.add_child(replica)
	await frames(40)
	assert(replica.locked and not replica.is_open, "Joining client gets current lock state")
	assert(
		not replica.set_locked(false) and host_door.locked,
		"Clients cannot invoke the server lock interface"
	)
	var actor := CharacterBody3D.new()
	actor.name = "PeerPawn"
	actor.set_multiplayer_authority(replica_peer.get_unique_id())
	actor.position = Vector3(0, 0, 2)
	host_root.add_child(actor)
	replica.request_toggle.rpc_id(1, NodePath("../PeerPawn"))
	await frames(40)
	assert(not host_door.is_open and not replica.is_open)
	assert(host_door.set_locked(false))
	await frames(40)
	assert(not replica.locked)
	var forged := CharacterBody3D.new()
	forged.name = "Imposter"
	forged.position = Vector3(0, 0, 2)
	host_root.add_child(forged)
	replica.request_toggle.rpc_id(1, NodePath("../Imposter"))
	await frames(40)
	assert(not host_door.is_open, "Client cannot impersonate a server-owned actor")
	replica.request_toggle.rpc_id(1, NodePath("../PeerPawn"))
	await frames(40)
	assert(host_door.is_open and replica.is_open)
	replica.queue_free()
	await frames(5)
	replica = load("res://scenes/level/ModularDoor.tscn").instantiate() as ModularDoor
	replica.name = "AccessDoor"
	replica.is_security = true
	replica_root.add_child(replica)
	await frames(40)
	assert(replica.is_open and not replica.locked, "Reloaded client gets the current open state")
	assert(host_door.set_locked(true))
	await frames(40)
	assert(replica.locked and not replica.is_open)
	host_api.multiplayer_peer = null
	replica_api.multiplayer_peer = null
	host_peer.close()
	replica_peer.close()
	host_root.queue_free()
	replica_root.queue_free()
	await frames(5)
