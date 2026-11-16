extends SceneTree
## Two Godot processes run production autoload, lobby start and mission host:
## validates multiplayer offworld armoury & resupply (CO-1).
## Exercises:
## 1. Live resupply broadcast while late joiner has not built its station/player (no missing-node errors).
## 2. Late joiner connects and receives coherent snapshots; monotonic cooldown enforcement.
## 3. Server-authoritative depletion: host depletes client operative on the server before interaction.
## 4. Rejection of forged requests for another operative (in-reach client attempting host refill).
## 5. Rejection of out-of-reach client resupply and armor requests.
## 6. Remote client in-reach interaction restores tactical plates (+150 ballistic ammo) and full gear on both server and client.
## 7. Actual coordinated retry resets all stations to initial ready state across host and client.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const PORT := 19880
var child_pid: int = -1
var output_dir: String
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		OS.delay_msec(1)
		await process_frame


func mark(label: String, text: String = "ok") -> void:
	FileAccess.open(output_dir.path_join(label), FileAccess.WRITE).store_string(text)


func marked(label: String, limit: int = 3600) -> bool:
	for _i: int in range(limit):
		if FileAccess.file_exists(output_dir.path_join(label)):
			return true
		await frames(1)
	if not is_child():
		print(FileAccess.get_file_as_string(output_dir.path_join("client.log")))
	return false


func is_child() -> bool:
	return OS.get_cmdline_user_args().has("--resupply-child")


func _finalize() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)


func mission(previous: int = 0) -> ModularMission:
	for _i: int in range(3600):
		var room := main.current_gate_room as ModularMission
		if (
			room != null
			and room.get_instance_id() != previous
			and room.is_started
			and room.players_container.has_node(str(net.local_peer_id))
		):
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var args := OS.get_cmdline_user_args()
	var engine_args := OS.get_cmdline_args()
	var log_index: int = engine_args.find("--log-file")
	var log_dir: String = (
		engine_args[log_index + 1].get_base_dir() if log_index >= 0 else OS.get_user_data_dir()
	)
	output_dir = (
		args[args.find("--result-dir") + 1]
		if is_child()
		else log_dir.path_join("resupply-" + str(OS.get_process_id()))
	)
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)

	if is_child():
		await run_client()
	else:
		await run_host()

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(2)
	net.disconnect_game()
	print(
		"PASS resupply client"
		if is_child()
		else "PASS two-peer offworld resupply: late join snapshot, remote interaction authority, inventory sync and retry"
	)
	quit(0)


func run_host() -> void:
	assert(net.host_game(PORT) == OK, "Host server on port %d must succeed" % PORT)
	assert(net.set_mission(MISSION), "Select mission %s must succeed" % MISSION)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var room := await mission()
	var me := room.players_container.get_node("1") as PlayerController3D
	me.health_component.current_health = 1000000.0

	var armoury_module := room.level.get_node_or_null("armoury") as LevelModule
	assert(armoury_module != null, "Armoury module must exist")
	var armor_station := armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	var resupply_station := armoury_module.get_node_or_null("Attachments/RoomContent/inventory") as ArmoryResupplyStation
	assert(armor_station != null and resupply_station != null, "Stations must be instanced in armoury under stable IDs")

	# Launch late-joining client process
	child_pid = OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join("client.log"),
			"--script", "res://tests/test_offworld_resupply_multiplayer.gd",
			"--", "--resupply-child", "--result-dir", output_dir
		]
	)
	assert(child_pid > 0, "Client process must start")

	# Wait for client to connect to peer network
	assert(await marked("client_network_connected"), "Client must connect to network")
	var child_id: int = 0
	for _i: int in range(600):
		await frames(1)
		for p in net.multiplayer.get_peers():
			if p != 1:
				child_id = p
				break
		if child_id != 0:
			break
	assert(child_id != 0, "Client must connect as multiplayer peer")

	# LIVE RESUPPLY TEST WHILE LATE JOINER HAS NOT BUILT STATION/PLAYER:
	# Host interacts with both stations using actual station.interact with host in range.
	# Demonstrably runs while client has not built its station or player.
	# Any raw RPC would emit an error on the unready client; mission_rpc protects it.
	place(me, resupply_station.global_position + Vector3(0.5, 0.0, 0.5))
	resupply_station.interact(me)
	place(me, armor_station.global_position + Vector3(0.5, 0.0, 0.5))
	armor_station.interact(me)
	assert(armor_station.current_cooldown > 0.0 and resupply_station.current_cooldown > 0.0, "Host live interaction must put stations on cooldown")
	mark("host_interacted_live")

	# Wait for late-joining client to load mission and verify snapshots
	assert(await marked("snapshot_verified"), "Late join client must verify cooldown snapshots")

	# Wait for cooldowns to finish
	for _i: int in range(240):
		await frames(1)
		if armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0:
			break
	mark("cooldown_expired")

	# Wait for client operative to be registered in room on server
	var client_op_on_server: PlayerController3D = null
	for _i: int in range(300):
		await frames(1)
		client_op_on_server = room.players_container.get_node_or_null(str(child_id)) as PlayerController3D
		if client_op_on_server != null and client_op_on_server.current_weapon != null:
			break
	assert(client_op_on_server != null, "Client operative must exist in server room")

	# AUTHORITATIVE SERVER DEPLETION:
	# Deplete client operative's authoritative state on the SERVER
	client_op_on_server.health_component.current_health = 35.0
	var wb_server := client_op_on_server.current_weapon as WeaponBase
	wb_server.reserve_ammo = 10
	client_op_on_server.claymore_charges = 0
	client_op_on_server.c4_charges_remaining = 0
	client_op_on_server.deployable_shields_count = 0
	client_op_on_server.smoke_grenades_count = 0
	if client_op_on_server.has_method("_broadcast_weapon_state"):
		client_op_on_server.call("_broadcast_weapon_state")

	# Deplete host health & gear to verify forged peer interaction rejection
	me.health_component.current_health = 45.0
	me.claymore_charges = 0

	mark("server_depleted")

	# Verify negative interaction tests from server perspective:
	assert(await marked("out_of_reach_tested"), "Client must execute out-of-reach tests")
	assert(client_op_on_server.health_component.current_health == 35.0, "Server must not heal out-of-reach client")
	assert(wb_server.reserve_ammo == 10, "Server must not refill out-of-reach client ammo")
	assert(client_op_on_server.claymore_charges == 0, "Server must not restock out-of-reach gear")

	assert(await marked("forged_peer_tested"), "Client must execute forged peer tests")
	assert(me.health_component.current_health == 45.0, "Server must reject forged interaction for host")
	assert(me.claymore_charges == 0, "Server must reject forged resupply for host")
	me.health_component.current_health = 1000000.0

	# Wait for client in-reach interactions
	assert(await marked("client_interacted"), "Client must complete in-reach interactions")

	# AUTHORITATIVE SERVER VERIFICATION:
	# Verify server state was refilled by authoritative server resolution
	assert(client_op_on_server.health_component.current_health == client_op_on_server.health_component.max_health, "Server authoritative health refilled to 100%")
	assert(wb_server.reserve_ammo == wb_server.reserve_capacity, "Server authoritative reserve ammo refilled to capacity (%d)" % wb_server.reserve_capacity)
	assert(client_op_on_server.claymore_charges == client_op_on_server.MAX_CLAYMORE_CHARGES, "Server authoritative claymores refilled to %d" % client_op_on_server.MAX_CLAYMORE_CHARGES)
	assert(client_op_on_server.c4_charges_remaining == client_op_on_server.MAX_C4_CHARGES, "Server authoritative C4 refilled to %d" % client_op_on_server.MAX_C4_CHARGES)
	assert(client_op_on_server.deployable_shields_count == client_op_on_server.MAX_DEPLOYABLE_SHIELDS, "Server authoritative shields refilled to %d" % client_op_on_server.MAX_DEPLOYABLE_SHIELDS)
	assert(client_op_on_server.smoke_grenades_count == client_op_on_server.MAX_SMOKE_GRENADES, "Server authoritative smoke refilled to %d" % client_op_on_server.MAX_SMOKE_GRENADES)
	assert(armor_station.current_cooldown > 0.0, "Armor station must be on cooldown on server")
	assert(resupply_station.current_cooldown > 0.0, "Resupply station must be on cooldown on server")

	# COORDINATED RETRY
	var old_room := room.get_instance_id()
	assert(net.request_restart_game(), "Host requests retry")
	room = await mission(old_room)
	armoury_module = room.level.get_node_or_null("armoury") as LevelModule
	armor_station = armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	resupply_station = armoury_module.get_node_or_null("Attachments/RoomContent/inventory") as ArmoryResupplyStation
	assert(armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0, "Stations reset on retry")
	assert(armor_station.station_light.light_color == Color(0.2, 0.9, 0.4, 1.0), "Armor light reset to green on host")
	assert(resupply_station.status_light.light_color == Color(0.2, 0.9, 0.3), "Resupply light reset to green on host")

	assert(await marked("retried"), "Client must confirm retry reset")
	await frames(30)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text and not "Node not found" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Guest Operative"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK, "Join game must succeed")
	mark("client_network_connected")
	assert(await marked("host_interacted_live"), "Wait for host to interact while client is unready")
	var room := await mission()
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	me.health_component.current_health = 1000000.0

	var armoury_module := room.level.get_node_or_null("armoury") as LevelModule
	assert(armoury_module != null, "Armoury module must exist on client")
	var armor_station := armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	var resupply_station := armoury_module.get_node_or_null("Attachments/RoomContent/inventory") as ArmoryResupplyStation
	assert(armor_station != null and resupply_station != null, "Stations must exist on client under stable IDs")

	# Wait for snapshots to arrive from server
	for _i: int in range(120):
		await frames(1)
		if armor_station.current_cooldown > 0.0 and resupply_station.current_cooldown > 0.0:
			break

	assert(armor_station.current_cooldown > 0.0, "Late joiner must receive armor cooldown snapshot")
	assert(armor_station.station_light.light_color == Color(0.9, 0.6, 0.1, 1.0), "Armor light must be orange on late join")
	assert(resupply_station.current_cooldown > 0.0, "Late joiner must receive resupply cooldown snapshot")
	assert(resupply_station.status_light.light_color == Color(0.9, 0.6, 0.1), "Resupply light must be orange on late join")

	# Test snapshot cooldown monotonicity (cannot undo a newer cooldown)
	resupply_station.current_cooldown = 10.0
	resupply_station.sync_snapshot(2.0, 0)
	assert(resupply_station.current_cooldown == 10.0, "Snapshot with older cooldown must not undo newer cooldown")
	resupply_station.sync_snapshot(12.0, 0)
	assert(resupply_station.current_cooldown == 12.0, "Snapshot with newer cooldown must advance cooldown")
	resupply_station.current_cooldown = 1.0

	mark("snapshot_verified")

	assert(await marked("cooldown_expired"), "Wait for server cooldown to expire")
	for _i: int in range(240):
		await frames(1)
		if armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0:
			break

	assert(await marked("server_depleted"), "Wait for authoritative server depletion")
	await frames(20)

	# 1. Out of reach interaction attempts while at gate spawn:
	# A. Out of reach armor request
	armor_station.request_interact.rpc_id(1, armor_station.get_path_to(me))
	await frames(20)
	# B. Out of reach resupply request
	resupply_station.request_interact.rpc_id(1, resupply_station.get_path_to(me))
	await frames(20)
	mark("out_of_reach_tested")

	# 2. Move into armoury room in reach of stations
	place(me, armor_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(20)

	# 3. Forged other-operative interaction request in reach:
	# Client attempts to request armor/resupply on behalf of host operative ("1")
	var host_player := room.players_container.get_node("1") as PlayerController3D
	armor_station.request_interact.rpc_id(1, armor_station.get_path_to(host_player))
	await frames(20)
	resupply_station.request_interact.rpc_id(1, resupply_station.get_path_to(host_player))
	await frames(20)
	mark("forged_peer_tested")

	# 4. In-reach interaction with armor station:
	var wb := me.current_weapon as WeaponBase
	armor_station.interact(me)
	await frames(20)
	assert(me.health_component.current_health == me.health_component.max_health, "In-reach armor request must heal client to full")
	assert(wb.reserve_ammo == 160, "Ballistic ammo replenished (10 depleted + 150 = 160)")
	assert(armor_station.current_cooldown > 0.0, "Armor station cooldown synced to client")

	# 5. In-reach interaction with resupply station:
	place(me, resupply_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(20)
	resupply_station.interact(me)
	await frames(20)
	assert(wb.reserve_ammo == wb.reserve_capacity, "Reserve ammo must be replenished to capacity (%d)" % wb.reserve_capacity)
	assert(me.claymore_charges == me.MAX_CLAYMORE_CHARGES, "Claymores replenished on client (%d)" % me.MAX_CLAYMORE_CHARGES)
	assert(me.c4_charges_remaining == me.MAX_C4_CHARGES, "C4 replenished on client (%d)" % me.MAX_C4_CHARGES)
	assert(me.deployable_shields_count == me.MAX_DEPLOYABLE_SHIELDS, "Shields replenished on client (%d)" % me.MAX_DEPLOYABLE_SHIELDS)
	assert(me.smoke_grenades_count == me.MAX_SMOKE_GRENADES, "Smoke replenished on client (%d)" % me.MAX_SMOKE_GRENADES)
	assert(resupply_station.current_cooldown > 0.0, "Resupply station cooldown synced to client")

	mark("client_interacted")

	# Coordinated retry
	var old_room := room.get_instance_id()
	room = await mission(old_room)
	armoury_module = room.level.get_node_or_null("armoury") as LevelModule
	armor_station = armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	resupply_station = armoury_module.get_node_or_null("Attachments/RoomContent/inventory") as ArmoryResupplyStation
	assert(armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0, "Stations reset on retry for client")
	assert(armor_station.station_light.light_color == Color(0.2, 0.9, 0.4, 1.0), "Armor light reset to green on client")
	assert(resupply_station.status_light.light_color == Color(0.2, 0.9, 0.3), "Resupply light reset to green on client")
	mark("retried")
