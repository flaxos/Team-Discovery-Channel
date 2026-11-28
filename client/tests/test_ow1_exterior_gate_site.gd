extends SceneTree
## Headless integration test for OW-1 (Exterior Gate Site playable vertical slice):
## 1. Standalone arrival outdoors at Stargate + DHD with Airman support, outdoor cover, and patrols.
## 2. Seamless traversal outdoors -> doorway -> modular bunker -> console download -> outdoor Stargate extraction.
## 3. Two-world SGC gate travel into the exterior gate site and return home to SGC debrief.

const OUTDOOR_SCENE := "res://scenes/mission/OutdoorGateSiteMission.tscn"
const SGC_UAT_SCENE := "res://scenes/main/SGCUATBase.tscn"


func _init() -> void:
	call_deferred(&"_run")


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _move_player(player: PlayerController3D, target: Vector3) -> void:
	player.global_position = target + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO


func _run() -> void:
	await _test_standalone_outdoor_mission()
	await _test_two_world_gate_travel()
	print("PASS test_ow1_exterior_gate_site")
	quit(0)


func _test_standalone_outdoor_mission() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	net.player_name = "Colonel"
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await _frames(3)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_OUTDOOR_GATE_SITE))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var mission: ModularMission = null
	for _i in range(900):
		if main.current_gate_room is ModularMission:
			mission = main.current_gate_room as ModularMission
			break
		await _frames(1)
	assert(mission != null, "Standalone OutdoorGateSiteMission launched")
	if not mission.is_started:
		await mission.started
	await _frames(4)

	assert(mission.setup_errors.is_empty(), "Zero setup errors: %s" % [mission.setup_errors])
	assert(mission.stargate_mesh != null, "Exterior Stargate wired into ModularMission")
	assert(mission.dhd_console != null, "Exterior DHD wired into ModularMission")
	assert(mission.dhd_console.target_stargate == mission.stargate_mesh, "Exterior DHD targets exterior Stargate")
	assert(mission.allies_container != null and mission.allies_container.get_child_count() == 2, "Airman fireteam spawned outdoors")
	assert(mission.hostiles_alive() == 5, "Outdoor + cross-boundary + interior patrols spawned (%d)" % mission.hostiles_alive())

	var cover_list := LevelNavigator.cover_props(mission.level)
	assert(cover_list.size() >= 4, "Outdoor natural cover props registered for AI (%d)" % cover_list.size())

	var player := mission.players_container.get_node_or_null("1") as PlayerController3D
	assert(player != null, "Host operative spawned")
	player.health_component.current_health = 1000000.0
	var arrival := mission.outdoor.marker_position(&"gate_arrival")
	assert(player.global_position.distance_to(arrival) < 2.5, "Operative spawned outdoors at gate_arrival")
	assert(mission.get_current_sector(player.global_position) == "EXTERIOR_GATE_SITE", "Sector reports EXTERIOR_GATE_SITE outdoors")

	# Objective 1: Cross clearing and enter bunker_entry
	assert(mission.objectives.current().id == &"breach_bunker")
	_move_player(player, mission.level.marker(&"bunker_entry", &"entry"))
	await _frames(6)
	assert(mission.get_current_sector(player.global_position) == "BUNKER_ENTRY", "Sector updates indoors to BUNKER_ENTRY")
	assert(mission.objectives.current().id == &"download_bunker_intel", "Entering bunker advances to console download")

	# Objective 2: Download telemetry from bunker_command main_console
	var console_pos := mission.objectives.position_of(mission.objectives.current())
	_move_player(player, console_pos + Vector3(0.0, 0.0, -1.2))
	await _frames(3)
	var station := mission.level.find_child("MissionInteract", true, false) as MissionInteractable
	assert(station != null, "Bunker command console interactable exists")
	station.interact(player)
	await _frames(4)
	assert(mission.objectives.current().id == &"extract_gate", "Downloading advances to outdoor Stargate extraction")

	# Objective 3: Return outside to exterior Stargate pad to extract
	_move_player(player, arrival)
	await _frames(6)
	assert(mission.objectives.is_complete(), "Returning to exterior gate completes all objectives")
	assert(mission.mission_result == 1, "Standalone outdoor gate site concludes with victory")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await _frames(5)
	net.disconnect_game()


func _test_two_world_gate_travel() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	net.player_name = "Major"
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await _frames(3)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_TRAVEL_OUTDOOR_SITE))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	var sgc: GateRoom = null
	for _i in range(900):
		if main.current_gate_room != null and main.current_site != null:
			sgc = main.current_gate_room as GateRoom
			break
		await _frames(1)
	assert(sgc != null, "SGC world loaded for outdoor travel mission")
	var site := main.current_site as ModularMission
	var session := main.session
	assert(site != null and session != null, "Outdoor site and MissionSession loaded")
	if not site.is_started:
		await site.started
	await _frames(5)

	assert(site.setup_errors.is_empty(), "Two-world outdoor site starts cleanly: %s" % [site.setup_errors])
	var home_player := sgc.players_container.get_node_or_null("1") as PlayerController3D
	assert(home_player != null, "Operative starts at SGC")

	# Travel outbound from SGC to the exterior gate site
	await session.travel_player(home_player, sgc)
	await _frames(4)
	var offworld_player := site.players_container.get_node_or_null("1") as PlayerController3D
	assert(offworld_player != null, "Operative arrived at exterior gate site")
	assert(session.presented == site, "Presentation switched to exterior site")
	assert(offworld_player.global_position.distance_to(site.outdoor.marker_position(&"gate_arrival")) < 2.5, "Arrived at outdoor Stargate pad")

	# Complete objectives offworld -> return gate opens automatically on exterior Stargate
	_move_player(offworld_player, site.level.marker(&"bunker_entry", &"entry"))
	await _frames(5)
	var station := site.level.find_child("MissionInteract", true, false) as MissionInteractable
	_move_player(offworld_player, site.objectives.position_of(site.objectives.current()) + Vector3(0.0, 0.0, -1.2))
	await _frames(3)
	station.interact(offworld_player)
	await _frames(4)
	assert(site.objectives.current().id == &"extract_gate", "Telemetry downloaded in two-world mode")
	_move_player(offworld_player, site.outdoor.marker_position(&"gate_arrival"))
	await _frames(6)
	assert(site.objectives.is_complete(), "Offworld objectives completed")
	assert(
		site.stargate_mesh.current_state in [StargateRing.GateState.KAWOOSH, StargateRing.GateState.ACTIVE],
		"Exterior Stargate opened for return home (state=%d)" % site.stargate_mesh.current_state
	)

	# Return home through the exterior Stargate -> mission victory
	await session.travel_player(offworld_player, site)
	await _frames(5)
	assert(session.result == 1, "Returning home from exterior gate site finishes mission with victory")
	assert(session.presented == sgc, "Presentation returned to SGC debrief")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await _frames(5)
	net.disconnect_game()
