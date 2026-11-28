extends SceneTree
## Headless verification for Stealth Follow-ups (body discovery + combat knife / thrown knife CQC):
## 1. Dead body discovery escalates patrolling sentry to ALERTED + MissionAlert SEARCHING + HUD toast
##    without re-triggering endlessly on the same corpse.
## 2. Dragging a dead body behind solid cover or Zat-vaporizing it prevents discovery.
## 3. Spotting a Zat-stunned comrade turns a sentry SUSPICIOUS to investigate without full alarm;
##    stun recovery resets the discovery flag.
## 4. Thrown combat knife [V] silently kills an unalerted unshielded sentry ("thrown_knife_stealth"),
##    decrements knife count, leaves nearby witness UNAWARE, and is recoverable back to max count.
## 5. Thrown combat knife hitting a wall emits an 8 m quiet acoustic distraction lure (LevelAcoustics)
##    that draws a nearby sentry to investigate while blocked by solid walls.
## 6. Thrown knife is deflected by an active Goa'uld Personal Shield (fast projectile), whereas
##    slow [F] combat knife melee bypasses the shield and shows proper CQC prompts.
## 7. KeybindingManager ("throw_knife"), HUD kit bar, and ArmoryResupplyStation integrate cleanly.

const INFILTRATION_SCENE := "res://scenes/mission/GoauldInfiltrationMission.tscn"
const JAFFA_SCENE := "res://scenes/entities/JaffaGuard.tscn"
const SHOCK_SCENE := "res://scenes/entities/JaffaShockGuard.tscn"

var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var player: PlayerController3D
var open_lane: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _place(node: CharacterBody3D, pos: Vector3) -> void:
	node.global_position = pos + Vector3(0.0, 0.05, 0.0)
	node.velocity = Vector3.ZERO


func _face_dir(node: Node3D, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		node.rotation.y = atan2(-flat.x, -flat.z)


func _face_toward(node: Node3D, target: Node3D) -> void:
	_face_dir(node, target.global_position - node.global_position)


var _jaffa_seq: int = 0


func _spawn_sentry(pos: Vector3, facing: Vector3, shielded: bool = false) -> JaffaAI:
	_jaffa_seq += 1
	var jaffa := (load(SHOCK_SCENE if shielded else JAFFA_SCENE) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "StealthSentry_%d" % _jaffa_seq
	jaffa.profile = JaffaAI.Profile.SENTRY
	jaffa.has_personal_shield = shielded
	jaffa.position = room.enemies.to_local(pos + Vector3(0.0, 0.05, 0.0))
	room.enemies.add_child(jaffa, true)
	jaffa.start_patrol([pos])
	_face_dir(jaffa, facing)
	return jaffa


func _clear_enemies_and_knives() -> void:
	for child in room.enemies.get_children():
		child.queue_free()
	if room.allies_container != null:
		for ally in room.allies_container.get_children():
			ally.queue_free()
	var fk := room.get_node_or_null("FieldKitDeployments")
	if fk != null:
		for child in fk.get_children():
			child.queue_free()
	await _frames(3)
	room.alert.alert_level = MissionAlert.Level.CALM
	room.alert.spotted = false
	room.alert.last_known = Vector3.INF
	room.alert.runner = null
	room.alert.runner_console = -1
	room.alert.runner_name = ""


func _find_open_lane() -> Dictionary:
	# Find a clear ~7 m lane inside the gate/hangar chamber on walkable navmesh.
	var base := room.level.marker(&"gate", &"entry")
	var space := room.get_world_3d().direct_space_state
	for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var a := NavigationServer3D.map_get_closest_point(room.level.navigation_map, base)
		var b := NavigationServer3D.map_get_closest_point(room.level.navigation_map, base + dir * 6.5)
		if a.distance_to(b) < 5.5:
			continue
		var ray := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 1.1, b + Vector3.UP * 1.1, 1 | 128)
		if space.intersect_ray(ray).is_empty():
			return {"a": a, "b": b, "dir": (b - a).normalized()}
	assert(false, "Could not find clear 6m lane in gate room")
	return {}


func _run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var kb := root.get_node("KeybindingManager")
	assert(kb.ACTIONS.has("throw_knife"), "KeybindingManager registers throw_knife action")
	assert(not kb.binding_text("throw_knife").is_empty(), "throw_knife has default binding")

	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await _frames(3)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	for _i in range(900):
		if main.current_gate_room is ModularMission:
			room = main.current_gate_room as ModularMission
			break
		await _frames(1)
	assert(room != null)
	if not room.is_started:
		await room.started
	await _frames(4)

	player = room.players_container.get_node("1") as PlayerController3D
	player.health_component.current_health = 1000000.0
	player.current_aim_target = Vector3.ZERO
	open_lane = _find_open_lane()
	var lane_a: Vector3 = open_lane["a"]
	var lane_b: Vector3 = open_lane["b"]
	var lane_dir: Vector3 = open_lane["dir"]
	var parked_pos := room.level.marker(&"cmd_command", &"entry")

	assert(player.throwing_knives_count == player.MAX_THROWING_KNIVES, "Operative starts with full throwing knives")
	await _frames(3)
	assert(room.hud != null and room.hud.gadget_label.text.contains("KNIFE (2/2)"), "HUD displays throwing knife count: %s" % room.hud.gadget_label.text)

	# ------------------------------------------------------------------
	# 1. Dead body discovery -> ALERTED + MissionAlert SEARCHING + toast
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	_place(player, parked_pos)
	var victim := _spawn_sentry(lane_a, lane_dir)
	var discoverer := _spawn_sentry(lane_b, -lane_dir)  # facing straight at victim
	var discovered_events: Array[Dictionary] = []
	discoverer.body_discovered.connect(func(corpse: Node3D, lethal: bool) -> void:
		discovered_events.append({"corpse": corpse, "lethal": lethal})
	)
	var alert_body_events: Array[Vector3] = []
	var saw_discovery_toast: Array[bool] = [false]
	room.alert.body_discovered.connect(func(at: Vector3) -> void:
		alert_body_events.append(at)
		if "FALLEN JAFFA DISCOVERED" in room.hud.squad_toast_label.text:
			saw_discovery_toast[0] = true
	)
	await _frames(4)

	# Kill victim silently (simulating stealth takedown) while discoverer faces it.
	victim.health_component.take_damage(200.0, player, "stealth_takedown")
	for _step in range(30):
		await _frames(1)
		if "FALLEN JAFFA DISCOVERED" in room.hud.squad_toast_label.text:
			saw_discovery_toast[0] = true
		if not alert_body_events.is_empty():
			break
	await _frames(15)
	assert(discovered_events.size() == 1 and discovered_events[0]["lethal"] == true, "Discoverer spotted dead comrade once (%d)" % discovered_events.size())
	assert(victim.body_discovered_flag, "Dead body marked discovered")
	assert(discoverer.awareness_level == JaffaPerception.Level.ALERTED, "Discovering dead comrade alerts sentry")
	assert(room.alert.alert_level == MissionAlert.Level.SEARCHING, "Dead body discovery escalates MissionAlert to SEARCHING")
	assert(alert_body_events.size() == 1, "MissionAlert emitted body_discovered signal")
	assert(saw_discovery_toast[0], "HUD surfaced fallen Jaffa discovery toast (latest=%s)" % room.hud.squad_toast_label.text)

	# Wait more frames: must not re-discover the same body repeatedly.
	await _frames(20)
	assert(discovered_events.size() == 1, "Same corpse is never rediscovered twice")

	# ------------------------------------------------------------------
	# 2. Hiding corpses (behind wall/out of sight & Zat vaporize) prevents discovery
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	_place(player, parked_pos)
	var hidden_corpse := _spawn_sentry(room.level.marker(&"stores", &"entry"), lane_dir)
	var sentry_far := _spawn_sentry(lane_b, -lane_dir)
	await _frames(3)
	hidden_corpse.health_component.take_damage(200.0, player, "stealth_takedown")
	await _frames(20)
	assert(not hidden_corpse.body_discovered_flag and sentry_far.awareness_level == JaffaPerception.Level.UNAWARE, "Hidden corpse behind walls stays undiscovered")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound stays CALM when corpse is out of sight")

	# Zat-vaporized body inside view cone is never discovered.
	var vap_victim := _spawn_sentry(lane_a, lane_dir)
	await _frames(2)
	vap_victim.health_component.apply_zat_shot(player)
	vap_victim.health_component.apply_zat_shot(player)
	vap_victim.health_component.apply_zat_shot(player)  # 3rd shot vaporizes immediately
	assert(vap_victim.health_component.is_vaporized, "3rd Zat shot vaporizes body")
	await _frames(25)
	assert(sentry_far.awareness_level == JaffaPerception.Level.UNAWARE, "Vaporized body cannot be discovered even in view cone")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound stays CALM after Zat vaporization")

	# ------------------------------------------------------------------
	# 3. Zat-stunned body discovery -> SUSPICIOUS investigation (no immediate alarm)
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	_place(player, parked_pos)
	var stunned_victim := _spawn_sentry(lane_a, lane_dir)
	var checker := _spawn_sentry(lane_b, -lane_dir)
	var stun_discovered: Array[bool] = []
	checker.body_discovered.connect(func(_c: Node3D, lethal: bool) -> void: stun_discovered.append(lethal))
	await _frames(3)
	stunned_victim.health_component.apply_zat_shot(player)
	assert(stunned_victim.health_component.is_stunned)
	await _frames(25)
	assert(stun_discovered.size() == 1 and stun_discovered[0] == false, "Checker spotted stunned comrade as non-lethal")
	assert(checker.awareness_level == JaffaPerception.Level.SUSPICIOUS and checker.investigating, "Spotting stunned comrade triggers SUSPICIOUS investigation")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Spotting stunned comrade alone does not immediately trigger full compound alarm")
	stunned_victim._on_recovered_from_stun()
	assert(not stunned_victim.body_discovered_flag, "Stun recovery clears body_discovered_flag")

	# ------------------------------------------------------------------
	# 4. Thrown combat knife [V]: silent stealth kill + knife recovery
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	var target_guard := _spawn_sentry(lane_b, lane_dir)  # facing AWAY from lane_a
	var witness := _spawn_sentry(lane_b + lane_dir * 4.0, lane_dir)  # ahead facing away
	_place(player, lane_a)
	_face_toward(player, target_guard)
	player.current_aim_target = Vector3.ZERO
	player.throwing_knives_count = player.MAX_THROWING_KNIVES
	player.knife_throw_cooldown = 0.0
	await _frames(4)

	assert(player.try_throw_knife(), "Operative throws combat knife")
	assert(player.throwing_knives_count == 1, "Throwing knife decrements count to 1")
	for _step in range(90):
		await _frames(1)
		if target_guard.health_component.is_dead:
			break
	assert(target_guard.health_component.is_dead, "Thrown knife kills unalerted unshielded sentry")
	assert(witness.awareness_level == JaffaPerception.Level.UNAWARE, "Nearby witness stays UNAWARE on silent thrown knife kill")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound stays CALM on silent thrown knife kill")

	# Recover the lodged knife via prompt / interact
	var knives := MissionWorld.in_group(room, &"thrown_knife")
	assert(knives.size() == 1, "Thrown knife remains lodged in world for recovery")
	var lodged_knife := knives[0] as ThrownKnife
	assert(lodged_knife.lodged, "Thrown knife is lodged")
	_place(player, lodged_knife.global_position + Vector3(1.6, 0.0, 0.0))
	await _frames(2)
	assert("RECOVER KNIFE" in player.close_quarters_prompt(), "Prompt offers knife recovery: %s" % player.close_quarters_prompt())
	lodged_knife.interact(player)
	await _frames(3)
	assert(player.throwing_knives_count == 2, "Recovering lodged knife restores count to 2")

	# ------------------------------------------------------------------
	# 5. Thrown combat knife wall-impact distraction lure (LevelAcoustics)
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	var lure_sentry := _spawn_sentry(lane_b, lane_dir)  # facing away from lane_a
	var far_walled_sentry := _spawn_sentry(room.level.marker(&"stores", &"entry"), lane_dir)
	var side_vec := lane_dir.cross(Vector3.UP).normalized()
	_place(player, lane_a)
	player.knife_throw_cooldown = 0.0
	await _frames(3)
	# Aim straight at the floor ~2.5 m ahead and 1.5 m beside lure_sentry (no await before throw
	# so headless mouse-ray aiming cannot overwrite current_aim_target).
	var lure_spot := lane_a + lane_dir * 3.5 + side_vec * 1.5
	_face_dir(player, lure_spot - lane_a)
	player.current_aim_target = lure_spot + Vector3(0.0, -2.6, 0.0)
	assert(player.try_throw_knife(), "Operative throws distraction knife at floor")
	for _step in range(90):
		await _frames(1)
		if lure_sentry.investigating:
			break
	assert(lure_sentry.investigating and lure_sentry.awareness_level == JaffaPerception.Level.SUSPICIOUS, "Wall/floor knife clink draws nearby sentry to investigate")
	assert(not far_walled_sentry.investigating and far_walled_sentry.awareness_level == JaffaPerception.Level.UNAWARE, "Walled-off distant sentry does not hear quiet knife clink")
	player.current_aim_target = Vector3.ZERO

	# ------------------------------------------------------------------
	# 6. Thrown knife deflected by Goa'uld Personal Shield vs slow [F] knife melee
	# ------------------------------------------------------------------
	await _clear_enemies_and_knives()
	var shielded := _spawn_sentry(lane_b, -lane_dir, true)  # active personal shield
	_place(player, lane_a)
	player.throwing_knives_count = 2
	player.knife_throw_cooldown = 0.0
	await _frames(4)
	_face_toward(player, shielded)
	player.current_aim_target = shielded.global_position
	var hp_before := shielded.health_component.current_health
	assert(player.try_throw_knife(), "Operative throws knife at shielded officer")
	for _step in range(90):
		await _frames(1)
		if shielded.personal_shield.deflect_count > 0:
			break
	assert(shielded.personal_shield.deflect_count >= 1, "Personal shield deflects fast thrown knife")
	assert(shielded.health_component.current_health == hp_before, "Deflected thrown knife deals 0 damage through active shield")
	assert(shielded.awareness_level == JaffaPerception.Level.ALERTED, "Shield deflection alerts officer")

	# Close-quarters slow [F] knife melee still bypasses the shield and shows proper prompts.
	_place(player, lane_b + lane_dir * 1.4)  # behind shielded officer
	_face_toward(player, shielded)
	player.melee_cooldown = 0.0
	player._server_melee_cooldown = 0.0
	await _frames(2)
	assert("FLANK MELEE (BYPASS SHIELD)" in player.close_quarters_prompt(), "Shielded target keeps bypass prompt")
	assert(player.try_melee_strike(), "Slow close-quarters knife strike bypasses personal shield")
	await _frames(3)
	assert(shielded.health_component.is_dead, "Slow flank combat knife kills shielded officer")

	# Unshielded target in melee range shows COMBAT KNIFE / FLANK KNIFE prompt.
	await _clear_enemies_and_knives()
	var unshielded := _spawn_sentry(lane_b, -lane_dir, false)
	unshielded.perception.alert(player, lane_a)
	unshielded._publish_awareness()
	_place(player, lane_b - lane_dir * 1.5)
	_face_toward(player, unshielded)
	await _frames(2)
	assert("COMBAT KNIFE" in player.close_quarters_prompt(), "Unshielded front target shows COMBAT KNIFE prompt: %s" % player.close_quarters_prompt())

	# ------------------------------------------------------------------
	# 7. Armory resupply restores throwing knives
	# ------------------------------------------------------------------
	player.throwing_knives_count = 0
	var station := room.level.find_child("ArmoryResupplyStation", true, false) as ArmoryResupplyStation
	if station == null:
		for node in MissionWorld.in_group(room, &"interactable"):
			if node is ArmoryResupplyStation and (node as ArmoryResupplyStation).station_type == ArmoryResupplyStation.StationType.AMMO_CRATE:
				station = node as ArmoryResupplyStation
				break
	assert(station != null, "ArmoryResupplyStation exists in compound armoury")
	_place(player, station.global_position + Vector3(0.0, 0.0, 1.2))
	await _frames(2)
	station.interact(player)
	await _frames(3)
	assert(player.throwing_knives_count == player.MAX_THROWING_KNIVES, "Armory resupply restores throwing knives to max")

	room._stop_world_combat()
	await _frames(20)
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await _frames(10)
	net.disconnect_game()
	print("PASS test_stealth_body_discovery_and_cqc")
	await preload("res://tests/support/finish.gd").success(self)
