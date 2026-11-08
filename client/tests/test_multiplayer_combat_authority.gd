extends SceneTree
## Two native multiplayer contexts and two isolated physics worlds; hits resolve on the host world.
var host_view: SubViewport
var client_view: SubViewport
var host_arena: Node3D
var client_arena: Node3D
var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var host_player: PlayerController3D
var server_remote: PlayerController3D
var client_host: PlayerController3D
var client_player: PlayerController3D
var server_target: CharacterBody3D
var client_target: CharacterBody3D
var deaths: Array[int] = [0]

func _init() -> void:
	call_deferred("run_test")

func frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame

func view(name_text: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = name_text
	viewport.size = Vector2i(320, 180)
	viewport.own_world_3d = true
	root.add_child(viewport)
	return viewport

func operative(arena: Node3D, id: int, position: Vector3, profile: String = "oneill_recon", node_name: String = "") -> PlayerController3D:
	var actor := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	actor.name = str(id) if node_name.is_empty() else node_name
	actor.peer_id = id
	actor.class_id = profile
	actor.position = position
	arena.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	return actor

func target(arena: Node3D, label: String, hp: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = label
	body.position = Vector3(0, 0, -10)
	body.collision_layer = 4
	body.collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.7
	capsule.height = 2.0
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 1.0
	body.add_child(collision)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = hp
	body.add_child(health)
	arena.add_child(body)
	return body

func health(body: Node) -> HealthComponent:
	return body.get_node("HealthComponent") as HealthComponent

func shoot(actor: PlayerController3D) -> bool:
	actor.current_aim_target = Vector3(0, 1.1, -10)
	actor.is_aiming_down_sights = true
	return actor.current_weapon.try_fire(0.0)

func run_test() -> void:
	host_view = view("CombatHost")
	client_view = view("CombatClient")
	host_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	set_multiplayer(host_api, host_view.get_path())
	set_multiplayer(client_api, client_view.get_path())
	server_peer = ENetMultiplayerPeer.new()
	assert(server_peer.create_server(19842) == OK)
	host_api.multiplayer_peer = server_peer
	client_peer = ENetMultiplayerPeer.new()
	assert(client_peer.create_client("127.0.0.1", 19842) == OK)
	client_api.multiplayer_peer = client_peer
	for _i: int in range(300):
		await process_frame
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	assert(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	host_arena = Node3D.new()
	host_arena.name = "Arena"
	host_view.add_child(host_arena)
	client_arena = Node3D.new()
	client_arena.name = "Arena"
	client_view.add_child(client_arena)
	assert(host_arena.get_world_3d() != client_arena.get_world_3d(), "Server raycasts must use an isolated physics world")
	var id: int = client_api.get_unique_id()
	host_player = operative(host_arena, 1, Vector3.ZERO)
	server_remote = operative(host_arena, id, Vector3(3, 0, 0))
	client_host = operative(client_arena, 1, Vector3.ZERO)
	client_player = operative(client_arena, id, Vector3(3, 0, 0))
	server_target = target(host_arena, "Target", 88)
	client_target = target(client_arena, "Target", 88)
	health(server_target).died.connect(func() -> void: deaths[0] += 1)
	await frames(10)
	assert(health(client_player).get_multiplayer_authority() == 1, "Client movement ownership must not include health authority")
	assert(shoot(host_player))
	await frames(10)
	assert(health(server_target).current_health == 66 and health(client_target).current_health == 66, "Host damage must replicate")
	assert(shoot(client_player))
	await frames(10)
	assert(health(server_target).current_health == 44 and health(client_target).current_health == 44, "Remote shot must raycast/apply damage on server")
	assert(shoot(host_player) and shoot(client_player))
	await frames(12)
	assert(health(server_target).is_dead and health(client_target).is_dead and deaths[0] == 1, "Concurrent shots must kill once consistently")
	health(server_target).take_damage(999, host_player)
	assert(deaths[0] == 1, "Dead targets cannot reward a second death")
	server_target.collision_layer = 0
	client_target.collision_layer = 0
	print("PASS host/client/concurrent server hits and exactly-once death")

	var durable_host: CharacterBody3D = target(host_arena, "Durable", 1000)
	var durable_client: CharacterBody3D = target(client_arena, "Durable", 1000)
	await frames(10)
	var origin: Vector3 = client_player.current_weapon.muzzle_point.global_position
	var direction: Vector3 = (Vector3(0, 1.1, -10) - origin).normalized()
	# Requests cannot select a target or damage value; invalid origin/weapon/sender are rejected.
	client_host.server_request_fire.rpc_id(1, 99, 1, "p90", origin, direction, true)
	client_player.server_request_fire.rpc_id(1, 100, 1, "p90", origin + Vector3(100, 0, 0), direction, true)
	client_player.server_request_fire.rpc_id(1, 101, 1, "staff_weapon", origin, direction, true)
	client_player.server_request_fire.rpc_id(1, 102, 1, "p90", origin, Vector3(NAN, 0, 0), true)
	health(durable_client).take_damage(999, client_player)
	await frames(10)
	assert(health(durable_host).current_health == 1000 and health(durable_client).current_health == 1000, "Forged and local damage must have no effect")
	client_player._shot_request_id = 103
	client_player.current_weapon.fire_cooldown = 0
	assert(shoot(client_player))
	# Bypass the local limiter to prove the host independently limits requests.
	client_player.server_request_fire.rpc_id(1, 105, 1, "p90", origin, direction, true)
	await frames(10)
	assert(health(durable_host).current_health == 978, "Server independently enforces rate of fire")
	var remaining: int = server_remote.current_weapon.current_ammo
	server_remote.switch_slot(2)
	server_remote.switch_slot(1)
	assert(server_remote.current_weapon.current_ammo == remaining, "Switching slots cannot refill ammunition")
	server_remote.current_weapon.current_ammo = 0
	server_remote.current_weapon.reserve_ammo = 0
	client_player.current_weapon.current_ammo = 50
	client_player.current_weapon.fire_cooldown = 0
	assert(shoot(client_player))
	await frames(10)
	assert(health(durable_host).current_health == 978, "Client cannot invent ammunition")
	# A reload keeps its own inventory state when the operative changes slots.
	var primary: WeaponBase = server_remote.current_weapon
	primary.current_ammo = 0
	primary.reserve_ammo = 10
	primary.reload_time_s = 0.1
	primary.reload()
	server_remote.switch_slot(2)
	var hud_ammo: Array[int] = [-1]
	server_remote.weapon_ammo_changed.connect(func(value: int, _reserve: int) -> void: hud_ammo[0] = value)
	await frames(15)
	assert(primary.current_ammo == 10 and primary.reserve_ammo == 0 and not primary.is_reloading, "Holstered reload must complete without replacing inventory")
	assert(hud_ammo[0] == -1, "Holstered reload cannot overwrite active weapon HUD")
	server_remote.switch_slot(1)
	assert(server_remote.current_weapon == primary and hud_ammo[0] == 10, "Re-equipping shows the completed reload")

	durable_host.collision_layer = 0
	durable_client.collision_layer = 0
	print("PASS sender/class/origin/direction/rate/ammo validation and inventory persistence")

	var server_zat: PlayerController3D = operative(host_arena, id, Vector3(3, 0, 0), "carter_tech", "ZatOperator")
	var client_zat: PlayerController3D = operative(client_arena, id, Vector3(3, 0, 0), "carter_tech", "ZatOperator")
	server_zat.switch_slot(2)
	client_zat.switch_slot(2)
	var zhost: CharacterBody3D = target(host_arena, "ZatTarget", 90)
	var zclient: CharacterBody3D = target(client_arena, "ZatTarget", 90)
	var vapor_events: Array[int] = [0, 0]
	health(zhost).vaporized.connect(func() -> void: vapor_events[0] += 1)
	health(zclient).vaporized.connect(func() -> void: vapor_events[1] += 1)
	await frames(10)
	assert(shoot(client_zat))
	await frames(22)
	assert(health(zhost).is_stunned and health(zclient).is_stunned, "Zat stun must agree")
	assert(shoot(client_zat))
	await frames(22)
	assert(health(zhost).is_dead and health(zclient).is_dead, "Second Zat shot must kill")
	# The NPC state workstream uses this nonblocking corpse layer for third-shot targeting.
	zhost.collision_layer = 64
	zclient.collision_layer = 64
	assert(shoot(client_zat))
	await frames(22)
	assert(health(zhost).is_vaporized and health(zclient).is_vaporized and vapor_events == [1, 1], "Third Zat shot vaporizes once on both peers")
	health(zhost).apply_zat_shot(server_zat)
	await frames(5)
	assert(vapor_events == [1, 1], "Repeated corpse hits cannot repeat vaporization")
	print("PASS authoritative Zat stun/kill/vaporization")

	health(server_remote).take_damage(999, host_player)
	await frames(10)
	assert(health(server_remote).is_downed and health(client_player).is_downed, "Remote player downing must replicate")
	host_player.position = server_remote.position + Vector3(1, 0, 0)
	for _i: int in range(30):
		host_player.server_revive_hold(host_arena.get_path_to(server_remote))
		host_player._server_revive_tick(0.1)
	await frames(10)
	assert(not health(client_player).is_downed and health(client_player).current_health == health(server_remote).max_health * 0.4, "Server timed revive must replicate")
	# Disconnect removes the remote sender's authority even if its actor remains during teardown.
	client_peer.close()
	client_api.multiplayer_peer = null
	await frames(20)
	var before_ammo: int = server_remote.current_weapon.current_ammo
	assert(not id in host_api.get_peers() and not server_remote._combat_peer_allowed(id), "Disconnected sender must no longer be accepted")
	assert(server_remote.current_weapon.current_ammo == before_ammo)
	server_peer.close()
	host_api.multiplayer_peer = null
	host_view.queue_free()
	client_view.queue_free()
	await frames(2)
	print("PASS downing, timed revive, disconnect and combat authority integration")
	quit(0)
