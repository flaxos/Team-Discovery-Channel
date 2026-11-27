extends SceneTree
## TA-2 chunk 3: Modular Airman tactical anchors from room markers, squad orders behind
## DeployableShield & bare-room doorway jambs, modular bounding leapfrog, coordinated rescue
## cover fire, and Airman suppressive fire against modular Jaffa sentries.

const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const Wheel := preload("res://scripts/ui/RadialCommandWheel.gd")
const JAFFA_SCENE := "res://scenes/entities/JaffaGuard.tscn"


func frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func _init() -> void:
	call_deferred("run")


func _find_bare_room(level: LevelAssembly) -> StringName:
	for item in level.layout.instances:
		if item.id in [&"gate", &"checkpoint"]:
			continue
		var has_prop_cover := false
		for a in LevelNavigator.room_tactical_anchors(level, item.id):
			if str(a.type) == "cover":
				has_prop_cover = true
				break
		if not has_prop_cover:
			return item.id
	return &""


func run() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await frames(3)
	var room := main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	for enemy in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)

	var player := room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 10000.0
	var reyes := room.allies_container.get_node("Support1") as SGCAirmanAI
	var chen := room.allies_container.get_node("Support2") as SGCAirmanAI
	assert(reyes != null and chen != null)
	assert(reyes._get_sector_for_pos(reyes.global_position) == "GATE", "_get_sector_for_pos resolves modular room names")

	# 1. Room anchor extraction: authored cover props + doorway jambs + bare rally + live DeployableShield
	var cp_anchors := LevelNavigator.room_tactical_anchors(room.level, &"checkpoint")
	assert(cp_anchors.any(func(a: Dictionary) -> bool: return str(a.type) == "cover"), "Checkpoint yields cover prop anchors")
	assert(cp_anchors.any(func(a: Dictionary) -> bool: return str(a.type) == "doorway_jamb"), "Checkpoint yields doorway jamb anchors")
	assert(cp_anchors.any(func(a: Dictionary) -> bool: return str(a.type) == "rally"), "Checkpoint yields rally marker anchors")

	var bare_room := _find_bare_room(room.level)
	assert(bare_room != &"", "Compound has a bare room without cover attachments")
	var bare_anchors := LevelNavigator.room_tactical_anchors(room.level, bare_room)
	assert(bare_anchors.any(func(a: Dictionary) -> bool: return str(a.type) == "doorway_jamb" or str(a.type) == "rally"), "Bare room derives doorway_jamb/rally anchors")

	# Doorway jamb anchors stay laterally clear of the centerline
	for edge in room.level.layout.connections:
		if edge.from_instance == bare_room:
			var mod := room.level.get_node(str(bare_room)) as Node3D
			var sock := room.level.layout.instance(bare_room).module.socket(edge.from_socket)
			var center_w := mod.to_global(sock.approach)
			for a: Dictionary in bare_anchors:
				if str(a.type) == "doorway_jamb":
					assert((a.pos as Vector3).distance_to(center_w) >= 0.55, "Jamb anchor stays offset from doorway centerline")

	# Live DeployableShield registers as priority-0 anchor and lets Hold Corner take cover behind it
	var gate_entry := room.level.marker(&"gate", &"entry")
	player.global_position = gate_entry + Vector3(0.0, 0.05, 1.5)
	player.rotation.y = 0.0
	await frames(2)
	player.deploy_shield()
	await frames(2)
	var gate_anchors := LevelNavigator.room_tactical_anchors(room.level, &"gate")
	var shield_anchor := {}
	for a: Dictionary in gate_anchors:
		if str(a.type) == "deployable_shield":
			shield_anchor = a
			break
	assert(not shield_anchor.is_empty(), "Deployed offworld shield registers in room_tactical_anchors")

	var shield_node := room.get_node("FieldKitDeployments").get_child(0) as DeployableShield
	player.global_position = gate_entry + Vector3(2.2, 0.05, 1.5)
	player.execute_squad_radial_command(Wheel.CMD_HOLD_CORNER, shield_node.global_position)
	for _i: int in range(180):
		await physics_frame
		if reyes.is_in_cover and reyes.current_state == SGCAirmanAI.State.HOLD_CORNER:
			break
		if chen.is_in_cover and chen.current_state == SGCAirmanAI.State.HOLD_CORNER:
			break
	var shield_holder := reyes if (reyes.is_in_cover and reyes.current_state == SGCAirmanAI.State.HOLD_CORNER) else chen
	assert(shield_holder.is_in_cover and shield_holder.global_position.distance_to(shield_anchor.pos) < 1.0,
		"Airman takes cover at live DeployableShield anchor")
	shield_node.health_component.take_damage(800.0)
	await frames(28)

	# 2. Bare room Hold Corner routes Airman to doorway jamb / cover marker and pins explicit order
	var bare_pos := NavigationServer3D.map_get_closest_point(room.level.navigation_map, room.level.marker(bare_room, &"entry"))
	var other_airman := chen if shield_holder == reyes else reyes
	player.global_position = bare_pos + Vector3(0.0, 0.05, 0.0)
	other_airman.global_position = bare_pos + Vector3(0.0, 0.05, 0.4)
	await frames(2)
	player.execute_squad_radial_command(Wheel.CMD_HOLD_CORNER, bare_pos)
	for _i: int in range(240):
		await physics_frame
		if other_airman.current_state == SGCAirmanAI.State.HOLD_CORNER and other_airman._explicit_hold_order and other_airman.global_position.distance_to(other_airman.current_anchor_position) <= 0.75:
			break
	assert(other_airman._explicit_hold_order and other_airman.current_state == SGCAirmanAI.State.HOLD_CORNER,
		"Expected HOLD_CORNER with _explicit_hold_order, got state=%d explicit=%s type=%s" % [other_airman.current_state, str(other_airman._explicit_hold_order), other_airman.current_anchor_type])
	assert(other_airman.current_anchor_type in ["doorway_jamb", "cover_marker", "rally"], "Bare room anchor selected: " + other_airman.current_anchor_type)
	var pinned_pos := other_airman.current_anchor_position
	other_airman._check_player_led_progression()
	assert(other_airman.current_state == SGCAirmanAI.State.HOLD_CORNER and other_airman.current_anchor_position.is_equal_approx(pinned_pos),
		"Explicit Hold Corner stays pinned during autonomous progression checks")

	# 3. Modular bounding leapfrog when player advances to cleared forward room
	reyes._explicit_hold_order = false
	chen._explicit_hold_order = false
	var a2_entry := room.level.marker(&"approach2", &"entry")
	var cp_entry := room.level.marker(&"checkpoint", &"entry")
	reyes.global_position = gate_entry + Vector3(-1.2, 0.05, 0.0)
	chen.global_position = gate_entry + Vector3(1.2, 0.05, 0.0)
	reyes.hold_corner(reyes.global_position, Vector3.FORWARD, "doorway_jamb")
	chen.hold_corner(chen.global_position, Vector3.FORWARD, "doorway_jamb")
	player.global_position = NavigationServer3D.map_get_closest_point(room.level.navigation_map, a2_entry) + Vector3(0.0, 0.05, 0.0)
	await frames(4)
	reyes._check_player_led_progression()
	assert(reyes.current_state == SGCAirmanAI.State.LEAPFROG_ADVANCE or chen.current_state == SGCAirmanAI.State.LEAPFROG_ADVANCE,
		"Modular pointman advance starts bounding leapfrog")
	var bounder := reyes if reyes.is_leapfrogging_advancing else chen
	var coverer := chen if bounder == reyes else reyes
	assert(coverer.current_state == SGCAirmanAI.State.COVER_FIRE and coverer.is_providing_cover_fire,
		"Partner provides covering fire while bounder advances")
	for _i: int in range(900):
		await physics_frame
		if reyes.current_state == SGCAirmanAI.State.HOLD_CORNER and chen.current_state == SGCAirmanAI.State.HOLD_CORNER \
			and room.get_current_sector(reyes.global_position) == "APPROACH2" \
			and room.get_current_sector(chen.global_position) == "APPROACH2":
			break
	assert(room.get_current_sector(reyes.global_position) == "APPROACH2" and room.get_current_sector(chen.global_position) == "APPROACH2",
		"Both Airmen complete modular bounding leapfrog into forward room")

	# 4. Coordinated downed-operative rescue: nearest revives, partner enters COVER_FIRE and clears cleanly after revive
	room._spawn_player(2, SGCNetworkManager.CLASS_CARTER_TECH, gate_entry + Vector3(0.0, 0.05, 0.0))
	reyes.global_position = cp_entry + Vector3(-0.6, 0.05, 0.0)
	chen.global_position = cp_entry + Vector3(-2.4, 0.05, 0.0)
	reyes.hold_corner(reyes.global_position, Vector3.FORWARD, "cover")
	chen.hold_corner(chen.global_position, Vector3.FORWARD, "cover")
	player.global_position = cp_entry + Vector3(0.5, 0.05, 0.0)
	await frames(2)
	player.health_component.take_damage(99999.0, null, "bullet")
	assert(player.health_component.is_downed)
	await frames(5)
	assert((reyes.current_state == SGCAirmanAI.State.REVIVE_PLAYER and chen.current_state == SGCAirmanAI.State.COVER_FIRE)
		or (chen.current_state == SGCAirmanAI.State.REVIVE_PLAYER and reyes.current_state == SGCAirmanAI.State.COVER_FIRE),
		"Nearest Airman rescues downed operative while partner covers (reyes=%d/%s chen=%d/%s)" % [reyes.current_state, str(reyes.is_providing_cover_fire), chen.current_state, str(chen.is_providing_cover_fire)])
	for _i: int in range(360):
		await physics_frame
		if not player.health_component.is_downed and reyes.current_state != SGCAirmanAI.State.COVER_FIRE and chen.current_state != SGCAirmanAI.State.COVER_FIRE:
			break
	assert(not player.health_component.is_downed, "Airman completes coordinated revive")
	assert(reyes.current_state != SGCAirmanAI.State.COVER_FIRE and chen.current_state != SGCAirmanAI.State.COVER_FIRE,
		"Covering Airman exits COVER_FIRE cleanly once teammate is revived")

	# 5. Friendly MP5 suppressive fire triggers TA-2 Jaffa suppression on modular levels
	var guard := (load(JAFFA_SCENE) as PackedScene).instantiate() as JaffaAI
	guard.position = room.enemies.to_local(cp_entry + Vector3(0.0, 0.05, 4.0))
	room.enemies.add_child(guard, true)
	guard.start_patrol([guard.global_position])
	reyes.global_position = cp_entry + Vector3(0.0, 0.05, 0.0)
	reyes.hold_corner(reyes.global_position, Vector3.BACK, "position")
	reyes.suppress_hallway((guard.global_position - reyes.global_position).normalized(), 2.0)
	for _i: int in range(180):
		await physics_frame
		if guard.is_suppressed:
			break
	assert(guard.is_suppressed, "Airman MP5 suppressive bursts suppress modular Jaffa sentry")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS TA-2 chunk 3 friendly squad tactics & modular Airman anchors")
	await preload("res://tests/support/finish.gd").success(self)
