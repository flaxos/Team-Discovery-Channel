extends SceneTree
## Native server/client contexts: existing NPC spawners, snapshots, doors and stations.
var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var host_root: Node3D
var client_root: Node3D
var host: GateRoom
var client: GateRoom

func _init() -> void:
	call_deferred("run_test")

func frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame

func run_test() -> void:
	host_root = Node3D.new()
	host_root.name = "StateHost"
	client_root = Node3D.new()
	client_root.name = "StateClient"
	root.add_child(host_root)
	root.add_child(client_root)
	var host_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())
	server_peer = ENetMultiplayerPeer.new()
	assert(server_peer.create_server(19843) == OK)
	host_api.multiplayer_peer = server_peer
	client_peer = ENetMultiplayerPeer.new()
	assert(client_peer.create_client("127.0.0.1", 19843) == OK)
	client_api.multiplayer_peer = client_peer
	for _i: int in range(600):
		await process_frame
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	assert(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	var scene := load("res://scenes/main/GateRoom.tscn") as PackedScene
	host = scene.instantiate() as GateRoom
	client = scene.instantiate() as GateRoom
	host_root.add_child(host)
	client_root.add_child(client)
	host.wave_manager.set_physics_process(false)
	client.wave_manager.set_physics_process(false)
	for body: Node in host.allies_container.get_children():
		body.set_physics_process(false)
	await frames(30)
	var airman: SGCAirmanAI = host.allies_container.get_child(0) as SGCAirmanAI
	var replica: SGCAirmanAI = client.allies_container.get_child(0) as SGCAirmanAI
	airman.position = Vector3(4, 0, 3)
	airman.current_state = SGCAirmanAI.State.HOLD_CORNER
	airman.body_mesh.scale.y = 0.65
	await frames(40)
	assert(replica.position.distance_to(airman.position) < 0.05, "Airman replicas must follow authoritative movement")
	assert(replica.current_state == airman.current_state and is_equal_approx(replica.body_mesh.scale.y, 0.65), "Airman visual posture and tactical state replicate")

	var enemy := load("res://scenes/entities/JaffaGuard.tscn").instantiate() as JaffaAI
	enemy.name = "ReplicationJaffa"
	enemy.position = Vector3(0, 1, -8)
	host.get_node("Enemies").add_child(enemy)
	enemy.set_physics_process(false)
	await frames(40)
	var enemy_replica: JaffaAI = client.get_node_or_null("Enemies/ReplicationJaffa") as JaffaAI
	assert(enemy_replica != null, "Existing EnemySpawner must instantiate remote Jaffa")
	enemy.position.x = 2.0
	enemy._set_crouching(true)
	await frames(40)
	assert(enemy_replica.position.distance_to(enemy.position) < 0.05 and enemy_replica.is_crouching, "Jaffa transform/posture sync without client physics drift")
	var replica_deaths: Array[int] = [0]
	enemy_replica.jaffa_died.connect(func(_node: Node) -> void: replica_deaths[0] += 1)
	enemy_replica._on_died()
	assert(replica_deaths[0] == 0, "Replica death cosmetics cannot award/count kills")
	host.wave_manager.enemies_alive = 2
	host.wave_manager._on_jaffa_killed(null, enemy)
	host.wave_manager._on_jaffa_killed(null, enemy)
	assert(host.wave_manager.enemies_alive == 1, "Repeated death notification cannot decrement twice")
	enemy.queue_free()
	await frames(30)
	assert(client.get_node_or_null("Enemies/ReplicationJaffa") == null, "Authoritative NPC removal must despawn its replica")

	host.wave_manager.completed_incursions = 3
	host.wave_manager.current_wave = 3
	host.wave_manager.computer_upgraded = true
	host.wave_manager.iris_repaired_under_fire = true
	host.wave_manager.enemies_alive = 7
	host.wave_manager.is_intermission = true
	host.wave_manager.intermission_timer = 11.5
	var notifications: Array[int] = [0]
	client.wave_manager.jaffa_count_changed.connect(func(_remaining: int, _wave: int) -> void: notifications[0] += 1)
	host.wave_manager._broadcast_mission_snapshot()
	await frames(20)
	assert(client.wave_manager.completed_incursions == 3 and client.wave_manager.computer_upgraded and client.wave_manager.iris_repaired_under_fire, "Objective progress must arrive in current snapshot")
	var previous: int = notifications[0]
	host.wave_manager._broadcast_mission_snapshot()
	await frames(20)
	assert(notifications[0] == previous, "Unchanged snapshots must not emit fake count-change events")
	host.toggle_blast_doors()
	await frames(90)
	assert(host.is_blast_doors_closed and client.is_blast_doors_closed, "Server door operations replicate")
	client.toggle_blast_doors()
	assert(client.is_blast_doors_closed, "Client cannot directly mutate mission doors")
	client.is_blast_doors_closed = false
	client.request_room_snapshot.rpc_id(1)
	await frames(90)
	assert(client.is_blast_doors_closed, "Late/reloaded room receives current door snapshot")

	var host_lift: SGCElevator = host.get_node("SGCElevator") as SGCElevator
	var client_lift: SGCElevator = client.get_node("SGCElevator") as SGCElevator
	host_lift.current_floor = 27
	host_lift.cabin.position.y = 5.5
	host_lift.is_doors_open = true
	await physics_frame
	await physics_frame
	client_lift.request_elevator_snapshot.rpc_id(1)
	await frames(20)
	assert(client_lift.current_floor == 27 and client_lift.is_doors_open and is_equal_approx(client_lift.cabin.position.y, 5.5), "Late join lift snapshot includes floor, doors and cabin position")

	var id: int = client_api.get_unique_id()
	var player := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = str(id)
	player.position = Vector3(0, 0.1, 4)
	host.players_container.add_child(player)
	await frames(40)
	var local: PlayerController3D = client.players_container.get_node(str(id)) as PlayerController3D
	local.set_physics_process(false)
	var armor: ArmoryArmorStation = host.find_child("ArmoryArmorStation", true, false) as ArmoryArmorStation
	var local_armor: ArmoryArmorStation = client.find_child("ArmoryArmorStation", true, false) as ArmoryArmorStation
	assert(armor != null and local_armor != null)
	player.health_component.current_health = 30
	local_armor.interact(local)
	await frames(20)
	assert(player.health_component.current_health == 30, "Remote armor request outside station range must fail")
	local.global_position = armor.global_position
	await frames(40)
	local_armor.interact(local)
	await frames(20)
	assert(player.health_component.current_health == player.health_component.max_health, "Nearby remote armor request heals on server")

	host.wave_manager.end_mission()
	await frames(5)
	host_api.multiplayer_peer = null
	client_api.multiplayer_peer = null
	host_root.queue_free()
	client_root.queue_free()
	await frames(2)
	server_peer.close()
	client_peer.close()
	print("PASS native NPC spawn/transform/despawn, mission snapshots, doors, lift and validated station requests")
	quit(0)
