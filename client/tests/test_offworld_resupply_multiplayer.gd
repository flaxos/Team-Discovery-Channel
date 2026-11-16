extends SceneTree
## Two Godot processes run production autoload, lobby start and mission host:
## validates multiplayer offworld armoury & resupply (CO-1).
## Exercises:
## 1. Host interacts with offworld armoury stations; cooldowns and visual feedback engage.
## 2. Late joiner connects while stations are on cooldown and receives coherent snapshots.
## 3. Remote client moves into armoury: server validates sender authority & reach.
## 4. Remote client cannot forge interactions from out of reach (server rejects).
## 5. Remote client interaction heals tactical plates, restocks ammo and gear, and syncs inventory.
## 6. Coordinated retry resets station states to initial readiness on all peers.
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
	print("PASS resupply client" if is_child() else "PASS two-peer offworld resupply: late join snapshot, remote interaction authority, inventory sync and retry")
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
	var resupply_station := armoury_module.get_node_or_null("Attachments/RoomContent/resupply_station") as ArmoryResupplyStation
	assert(armor_station != null and resupply_station != null, "Stations must be instanced in armoury")

	# Put stations on cooldown before late join
	armor_station.sync_feedback()
	resupply_station.sync_feedback(3.0)
	assert(armor_station.current_cooldown > 0.0 and resupply_station.current_cooldown > 0.0)

	# Launch late-joining client
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
	assert(await marked("snapshot_verified"), "Late join client must verify cooldown snapshots")

	# Wait for cooldowns to finish
	for _i: int in range(240):
		await frames(1)
		if armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0:
			break
	mark("cooldown_expired")

	assert(await marked("client_interacted"), "Client must complete interaction and inventory sync")

	# Verify server state was updated by client interaction
	assert(armor_station.current_cooldown > 0.0, "Armor station must be on cooldown on server after client used it")
	assert(resupply_station.current_cooldown > 0.0, "Resupply station must be on cooldown on server after client used it")

	# Coordinated retry
	var old_room := room.get_instance_id()
	assert(net.request_restart_game(), "Host requests retry")
	room = await mission(old_room)
	armoury_module = room.level.get_node_or_null("armoury") as LevelModule
	armor_station = armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	resupply_station = armoury_module.get_node_or_null("Attachments/RoomContent/resupply_station") as ArmoryResupplyStation
	assert(armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0, "Stations reset on retry")

	assert(await marked("retried"), "Client must confirm retry reset")
	await frames(30)
	var log_text := FileAccess.get_file_as_string(output_dir.path_join("client.log"))
	assert(not "ERROR:" in log_text and not "ObjectDB" in log_text, log_text)


func run_client() -> void:
	net.player_name = "Guest Operative"
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.join_game("127.0.0.1", PORT) == OK, "Join game must succeed")
	var room := await mission()
	var me := room.players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	me.health_component.current_health = 1000000.0

	var armoury_module := room.level.get_node_or_null("armoury") as LevelModule
	assert(armoury_module != null, "Armoury module must exist on client")
	var armor_station := armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	var resupply_station := armoury_module.get_node_or_null("Attachments/RoomContent/resupply_station") as ArmoryResupplyStation
	assert(armor_station != null and resupply_station != null, "Stations must exist on client")

	# Wait for snapshots to arrive
	for _i: int in range(120):
		await frames(1)
		if armor_station.current_cooldown > 0.0 and resupply_station.current_cooldown > 0.0:
			break

	assert(armor_station.current_cooldown > 0.0, "Late joiner must receive armor cooldown snapshot")
	assert(armor_station.station_light.light_color == Color(0.9, 0.6, 0.1, 1.0), "Armor light must be orange on late join")
	assert(resupply_station.current_cooldown > 0.0, "Late joiner must receive resupply cooldown snapshot")
	assert(resupply_station.status_light.light_color == Color(0.9, 0.6, 0.1), "Resupply light must be orange on late join")
	mark("snapshot_verified")

	assert(await marked("cooldown_expired"), "Wait for server cooldown to expire")
	for _i: int in range(240):
		await frames(1)
		if armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0:
			break

	# 1. Out of reach interaction attempt: client at gate room tries to interact directly with armor station
	me.health_component.current_health = 40.0
	armor_station.request_interact.rpc_id(1, armor_station.get_path_to(me))
	await frames(20)
	assert(me.health_component.current_health == 40.0, "Server must reject out-of-reach armor request")

	# 2. In reach interaction with armor station:
	place(me, armor_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(20)
	var wb := me.current_weapon as WeaponBase
	armor_station.interact(me)
	await frames(20)
	assert(me.health_component.current_health == me.health_component.max_health, "In-reach armor request must heal on server and client")
	assert(wb.reserve_ammo == 300, "Ballistic ammo replenished (150 initial + 150 = 300 cap)")
	assert(armor_station.current_cooldown > 0.0, "Armor station cooldown synced to client")

	# 3. In reach interaction with resupply station:
	place(me, resupply_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(20)
	wb.current_ammo = 5
	wb.reserve_ammo = 20
	me.claymore_charges = 0
	me.c4_charges_remaining = 0
	me.deployable_shields_count = 0
	me.smoke_grenades_count = 0

	resupply_station.interact(me)
	await frames(20)
	assert(wb.reserve_ammo == wb.reserve_capacity, "Reserve ammo must be replenished to capacity (%d)" % wb.reserve_capacity)
	assert(me.claymore_charges == me.MAX_CLAYMORE_CHARGES, "Claymores replenished")
	assert(me.c4_charges_remaining == me.MAX_C4_CHARGES, "C4 replenished")
	assert(me.deployable_shields_count == me.MAX_DEPLOYABLE_SHIELDS, "Shields replenished")
	assert(me.smoke_grenades_count == me.MAX_SMOKE_GRENADES, "Smoke replenished")
	assert(resupply_station.current_cooldown > 0.0, "Resupply station cooldown synced to client")

	mark("client_interacted")

	# Coordinated retry
	var old_room := room.get_instance_id()
	room = await mission(old_room)
	armoury_module = room.level.get_node_or_null("armoury") as LevelModule
	armor_station = armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	resupply_station = armoury_module.get_node_or_null("Attachments/RoomContent/resupply_station") as ArmoryResupplyStation
	assert(armor_station.current_cooldown == 0.0 and resupply_station.current_cooldown == 0.0, "Stations reset on retry for client")
	mark("retried")
