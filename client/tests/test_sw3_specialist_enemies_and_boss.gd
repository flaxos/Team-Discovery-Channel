extends SceneTree
## Single-process verification for SW-3: Canonical Specialised Enemies & Goa'uld System Lord Boss.
## Verifies:
## 1. First Prime / Jaffa Officer (expanded 30m alert spread, Rally Command clearing suppression +
##    brief resolve, and priority/faster alarm console activation).
## 2. Jaffa Heavy / Staff Cannon Trooper (220 HP, 30% frontal ballistic armor plate bypassed by
##    flanks/plasma/melee, 5-hit suppression resistance, and 3-bolt rapid heavy staff volley).
## 3. Jaffa Shock Grenadier & canonical Goa'uld Shock Grenade (ballistic throw, wall-LOS-blocked
##    blast, concussive damage + 0.55x disorientation slow + HUD flash).
## 4. Goa'uld System Lord Boss (320 HP, 140-energy Personal Shield, stealth-takedown resistance with
##    150 HP flank bypass melee, Kara Kesh telekinetic shockwave push + turret dismount + wall block,
##    Kara Kesh focused energy beam + cover-break & shield-overload cancel, and TacticalHUD Boss Bar).
## 5. Authored mission & SGC wave deployments (Mothership Bridge Boss, Infiltration, Outdoor, Wave 4).

const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
const SHOCK := "res://scenes/entities/JaffaShockGuard.tscn"
const LORD := "res://scenes/entities/GoauldSystemLord.tscn"

var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var serial := 0


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0.0, 0.05, 0.0)
	actor.velocity = Vector3.ZERO


func on_floor(spot: Vector3) -> bool:
	return NavigationServer3D.map_get_closest_point(level.navigation_map, spot).distance_to(spot) < 0.4


func clear_los(from: Vector3, to: Vector3) -> bool:
	var space := room.get_world_3d().direct_space_state
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0.0, eye, 0.0), to + Vector3(0.0, aim, 0.0), 1
			)
			if not space.intersect_ray(query).is_empty():
				return false
	return true


func open_setup() -> Dictionary:
	for item in level.layout.instances:
		var at := level.marker(item.id, &"patrol")
		for facing: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var front := at + facing * 6.0
			var behind := at - facing * 5.0
			if (
				on_floor(at) and on_floor(front) and on_floor(behind)
				and clear_los(at, front) and clear_los(at, behind)
			):
				return {"at": at, "facing": facing, "front": front, "behind": behind}
	return {}


func blocked_pair() -> Dictionary:
	for a in level.layout.instances:
		var pa := level.marker(a.id, &"patrol")
		for b in level.layout.instances:
			if a.id == b.id:
				continue
			var pb := level.marker(b.id, &"patrol")
			var d := pa.distance_to(pb)
			if d >= 2.5 and d <= 9.0 and absf(pa.y - pb.y) < 0.5 and not clear_los(pa, pb):
				return {"a": pa, "b": pb}
	return {}


func spawn_unit(scene_path: String, role_id: String, at: Vector3, facing: Vector3, shielded: bool = false) -> JaffaAI:
	serial += 1
	var jaffa := (load(scene_path) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "SW3Unit_%s_%d" % [role_id, serial]
	jaffa.combat_role = role_id
	if shielded:
		jaffa.has_personal_shield = true
	jaffa.position = room.enemies.to_local(at + Vector3(0.0, 0.05, 0.0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var route: Array[Vector3] = [at]
	jaffa.start_patrol(route)
	return jaffa


func reset_arena() -> void:
	for enemy: Node in room.enemies.get_children():
		enemy.queue_free()
	var deployments := room.get_node_or_null("FieldKitDeployments")
	if deployments != null:
		for item: Node in deployments.get_children():
			item.queue_free()
	if room.allies_container != null:
		for ally: Node in room.allies_container.get_children():
			ally.queue_free()
	await frames(4)
	room.alert.alert_level = MissionAlert.Level.CALM
	room.alert.spotted = false
	room.alert.runner = null
	room.alert.runner_name = ""
	player.disorientation_timer = 0.0
	player.disorientation_speed_scale = 1.0
	player.external_impulse_velocity = Vector3.ZERO
	player.last_external_impulse = Vector3.ZERO
	player.health_component.max_health = 1000000.0
	player.health_component.current_health = 1000000.0


func face_toward(actor: Node3D, target: Node3D) -> void:
	var dir := target.global_position - actor.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		actor.rotation.y = atan2(-dir.x, -dir.z)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await frames(3)
	room = main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	await reset_arena()

	var open := open_setup()
	assert(not open.is_empty(), "Fixture provides an open test lane")
	var open_at: Vector3 = open.at as Vector3
	var open_facing: Vector3 = open.facing as Vector3
	var open_front: Vector3 = open.front as Vector3
	var open_behind: Vector3 = open.behind as Vector3
	var walled := blocked_pair()
	assert(not walled.is_empty(), "Fixture provides a wall-separated pair")
	var wall_a: Vector3 = walled.a as Vector3
	var wall_b: Vector3 = walled.b as Vector3

	# ==========================================================================
	# 1. First Prime / Jaffa Officer: stats, Rally Command, 30m alert spread
	# ==========================================================================
	var officer := spawn_unit(JAFFA, JaffaAI.ROLE_OFFICER, open_at, open_facing)
	var trooper := spawn_unit(JAFFA, JaffaAI.ROLE_TROOPER, open_at + open_facing * 3.0, open_facing)
	var distant_spot: Vector3 = open_at + open_facing * 25.0
	var distant := spawn_unit(JAFFA, JaffaAI.ROLE_TROOPER, distant_spot, open_facing)
	distant.global_position = open_at + Vector3(25.0, 0.05, 0.0)
	await frames(4)
	assert(officer.is_officer() and officer.role_label() == "FIRST PRIME", "Officer role & badge active")
	assert(is_equal_approx(officer.health_component.max_health, 135.0), "Serpent Officer has 135 HP")
	assert(is_equal_approx(officer.alarm_raise_speed_multiplier(), 0.75), "Officer raises alarm 25% faster")

	# Suppress the trooper, then trigger Officer Rally Command
	trooper.register_incoming_fire(open.behind)
	trooper.register_incoming_fire(open.behind)
	assert(trooper.is_suppressed, "Standard trooper suppresses on 2 nearby rounds")
	place(player, open.behind)
	var rally_events := [0]
	officer.rally_command_issued.connect(func(cnt: int) -> void: rally_events[0] += cnt)
	officer.current_target = player
	var rallied := officer.issue_rally_command()
	assert(rallied >= 1 and rally_events[0] >= 1, "Officer Rally Command rallies nearby ally")
	assert(not trooper.is_suppressed, "Rally Command clears gunfire suppression on nearby Jaffa")
	assert(not trooper.can_be_suppressed(), "Rallied Jaffa has brief rally resolve against immediate re-suppression")
	assert(trooper.awareness_level == JaffaPerception.Level.ALERTED, "Rally shares hostile alert with nearby comrade")

	# Expanded 30m alert spread from Officer reaches 25m comrade (beyond standard 22m radius)
	officer._alert_nearby_formation_jaffa()
	assert(distant.awareness_level == JaffaPerception.Level.ALERTED, "Officer 30m alert spread alerts sentry at 25m")

	await reset_arena()

	# ==========================================================================
	# 2. Jaffa Heavy / Staff Cannon Trooper: 220 HP, frontal plate, 5-hit suppression, 3-bolt burst
	# ==========================================================================
	var heavy := spawn_unit(JAFFA, JaffaAI.ROLE_HEAVY, open.at, open.facing)
	await frames(4)
	assert(heavy.is_heavy() and heavy.role_label() == "HEAVY CANNON")
	assert(is_equal_approx(heavy.health_component.max_health, 220.0), "Heavy starts with 220 HP")

	# Frontal ballistic hit takes 30% reduced damage (40 -> 28); rear flank hit takes full 40
	place(player, open.front)
	heavy.rotation.y = atan2(-open.facing.x, -open.facing.z)
	heavy.health_component.take_damage(40.0, player, "bullet")
	assert(is_equal_approx(heavy.health_component.current_health, 192.0), "Heavy frontal plate mitigates 30%% ballistic fire (got %.1f)" % heavy.health_component.current_health)

	place(player, open.behind)
	heavy.rotation.y = atan2(-open.facing.x, -open.facing.z)
	heavy.health_component.take_damage(40.0, player, "bullet")
	assert(is_equal_approx(heavy.health_component.current_health, 152.0), "Flanking ballistic fire bypasses Heavy frontal plate (got %.1f)" % heavy.health_component.current_health)

	# Plasma bypasses frontal plate even from front
	place(player, open.front)
	heavy.rotation.y = atan2(-open.facing.x, -open.facing.z)
	heavy.health_component.take_damage(50.0, player, "plasma")
	assert(is_equal_approx(heavy.health_component.current_health, 102.0), "Staff plasma bypasses Heavy frontal ballistic plate")

	# 5-hit suppression resistance (4 rounds do NOT suppress; 5th round suppresses)
	for i: int in range(4):
		heavy.register_incoming_fire(open.front)
	assert(not heavy.is_suppressed, "Heavy resists suppression through 4 incoming ballistic rounds")
	heavy.register_incoming_fire(open.front)
	assert(heavy.is_suppressed, "5th incoming ballistic round suppresses Heavy")
	assert(heavy._suppression_hold <= JaffaAI.HEAVY_SUPPRESSION_HOLD + 0.01)

	# 3-bolt Heavy Staff Cannon volley
	heavy._clear_suppression()
	heavy._set_crouching(false)
	heavy.current_target = player
	heavy.perception.alert(player, player.global_position)
	heavy.fire_timer = 10.0
	var heavy_shots := [0]
	heavy.staff_fired.connect(func(_o: Vector3, _d: Vector3) -> void: heavy_shots[0] += 1)
	heavy._fire_staff_blast()
	await frames(28)
	assert(heavy_shots[0] == 3, "Heavy Staff Cannon fires a 3-bolt rapid volley (got %d)" % heavy_shots[0])
	room._stop_world_combat()
	await frames(12)

	# Restore physics on room after stop test? Easier: keep player/enemies active without calling _stop_world_combat mid-test.
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.health_component.frozen = false
	await reset_arena()

	# ==========================================================================
	# 3. Jaffa Shock Grenadier & Goa'uld Shock Grenade
	# ==========================================================================
	var grenadier := spawn_unit(JAFFA, JaffaAI.ROLE_GRENADIER, open.at, open.facing)
	await frames(4)
	assert(grenadier.is_grenadier() and grenadier.role_label() == "SHOCK GRENADIER")
	assert(is_equal_approx(grenadier.health_component.max_health, 115.0))
	assert(grenadier.shock_grenades_remaining == JaffaAI.MAX_SHOCK_GRENADES)

	place(player, open.front)
	grenadier._shock_grenade_cooldown = 0.0
	var hp_before_grenade := player.health_component.current_health
	var grenade := grenadier.try_throw_shock_grenade(player.global_position) as GoauldShockGrenade
	assert(grenade != null, "Shock Grenadier throws canonical Goa'uld Shock Grenade")
	assert(grenadier.shock_grenades_remaining == JaffaAI.MAX_SHOCK_GRENADES - 1)
	assert(grenadier.try_throw_shock_grenade(player.global_position) == null, "Cooldown blocks immediate repeat throw")

	# Wait for arc + 1.45s fuse detonation
	var detonated_info := [false, 0]
	grenade.detonated.connect(func(_pos: Vector3, cnt: int) -> void:
		detonated_info[0] = true
		detonated_info[1] = cnt
	)
	for _f: int in range(130):
		await physics_frame
		if detonated_info[0]:
			break
	assert(detonated_info[0] and detonated_info[1] >= 1, "Shock Grenade detonated and affected exposed operative")
	assert(player.health_component.current_health < hp_before_grenade, "Shock Grenade dealt concussive damage")
	assert(player.disorientation_timer > 0.5 and is_equal_approx(player.disorientation_speed_scale, 0.55), "Shock Grenade applied disorientation slow")
	assert(room.hud.shock_flash_alpha > 0.05, "HUD received shock flash overlay")

	# Wall-LOS protection: grenade on opposite side of solid wall must NOT damage/disorient operative
	await frames(35)
	player.disorientation_timer = 0.0
	player.disorientation_speed_scale = 1.0
	place(player, walled.b)
	var hp_wall := player.health_component.current_health
	var wall_grenade := (load("res://scenes/weapons/GoauldShockGrenade.tscn") as PackedScene).instantiate() as GoauldShockGrenade
	wall_grenade.fuse_time_s = 0.08
	var deployments := room.get_node("FieldKitDeployments") as Node3D
	wall_grenade.position = MissionWorld.local(deployments, (walled.a as Vector3) + Vector3.UP * 0.2)
	deployments.add_child(wall_grenade, true)
	wall_grenade.launch(Vector3.ZERO, grenadier)
	await frames(25)
	assert(is_equal_approx(player.health_component.current_health, hp_wall), "Solid wall blocks Shock Grenade concussive damage")
	assert(player.disorientation_timer <= 0.0, "Solid wall blocks Shock Grenade disorientation")

	await reset_arena()

	# ==========================================================================
	# 4. Goa'uld System Lord Boss: Personal Shield + Kara Kesh Push & Beam + HUD Boss Bar
	# ==========================================================================
	var boss := spawn_unit(LORD, JaffaAI.ROLE_GOAULD_LORD, open.at, open.facing, true)
	await frames(4)
	assert(boss.is_boss() and boss.is_shock_guard and boss.has_personal_shield and boss.has_active_shield())
	assert(is_equal_approx(boss.health_component.max_health, 320.0), "Goa'uld Boss starts with 320 HP")
	assert(is_equal_approx(boss.personal_shield.max_energy, 140.0), "Goa'uld Boss Personal Shield has 140 energy")
	assert(boss.staff_mount.get_node_or_null("StaffVisual") == null, "Goa'uld Boss wields Kara Kesh, not a Jaffa staff")

	# Boss resists instant 1-hit rear stealth takedown, but allows 150 HP slow flank melee bypass!
	place(player, open.at - open.facing * 1.4)
	face_toward(player, boss)
	boss.rotation.y = atan2(-open.facing.x, -open.facing.z)
	await frames(2)
	assert(not boss.can_be_taken_down_by(player), "Goa'uld Boss cannot be 1-shot by rear stealth takedown")
	assert(player.is_flanking_target(boss), "Rear approach still qualifies as slow flank melee bypass")
	player.melee_cooldown = 0.0
	player._server_melee_cooldown = 0.0
	assert(player.try_melee_strike(), "Flank slow melee strikes through System Lord shield")
	await frames(2)
	assert(is_equal_approx(boss.health_component.current_health, 170.0), "Flank melee deals 150 HP bypass ambush (320 -> 170, got %.1f)" % boss.health_component.current_health)
	assert(boss.has_active_shield(), "Boss Personal Shield remains active after slow melee bypass")

	# Ballistic fire still deflected by Boss Personal Shield
	boss.health_component.take_damage(45.0, player, "bullet")
	assert(is_equal_approx(boss.health_component.current_health, 170.0), "Bullets deflected by Boss Personal Shield")

	# HUD Boss Bar displays boss health & active personal shield
	await frames(2)
	assert(room.hud.boss_panel != null and room.hud.boss_panel.visible, "TacticalHUD displays Boss Health & Shield Bar when engaged")
	assert("PERSONAL SHIELD ACTIVE" in room.hud.boss_shield_label.text)

	# Kara Kesh Telekinetic Shockwave Push (in-cone knockback + damage + turret dismount)
	place(player, open.at + open.facing * 5.0)
	boss.rotation.y = atan2(-open.facing.x, -open.facing.z)
	boss.current_target = player
	boss._kara_kesh_push_cd = 0.0
	var hp_before_push := player.health_component.current_health
	var push_hits := [0]
	boss.kara_kesh_push_fired.connect(func(cnt: int) -> void: push_hits[0] += cnt)
	assert(boss.trigger_kara_kesh_push(), "Boss initiates Kara Kesh Shockwave Push telegraph")
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.CHARGING_PUSH)
	await frames(45)
	assert(push_hits[0] >= 1, "Kara Kesh Shockwave Push hit operative in front cone")
	assert(is_equal_approx(player.health_component.current_health, hp_before_push - JaffaAI.KARA_KESH_PUSH_DAMAGE), "Kara Kesh Push dealt 32 HP kinetic damage")
	assert(player.last_external_impulse.length() > 10.0, "Kara Kesh Push delivered strong horizontal knockback impulse")
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.IDLE)

	# Kara Kesh Focused Energy Beam: ticks damage + slow, then cancels when operative breaks LOS behind wall
	place(player, open.at + open.facing * 6.0)
	boss.rotation.y = atan2(-open.facing.x, -open.facing.z)
	boss._kara_kesh_beam_cd = 0.0
	var beam_events := {"started": 0, "ticks": 0, "end_reason": ""}
	boss.kara_kesh_beam_started.connect(func(_t: Node3D) -> void: beam_events["started"] += 1)
	boss.kara_kesh_beam_ticked.connect(func(_t: Node3D, _d: float) -> void: beam_events["ticks"] += 1)
	boss.kara_kesh_beam_ended.connect(func(reason: String) -> void: beam_events["end_reason"] = reason)
	var hp_before_beam := player.health_component.current_health
	assert(boss.trigger_kara_kesh_beam(player), "Boss initiates Kara Kesh Focused Beam")
	await frames(70)
	assert(beam_events["started"] == 1 and beam_events["ticks"] >= 1, "Kara Kesh Beam started and ticked damage")
	assert(player.health_component.current_health < hp_before_beam, "Kara Kesh Beam damaged target")
	assert(player.disorientation_timer > 0.0, "Kara Kesh Beam applied neural slow")
	# Move player behind solid wall to break LOS and verify immediate beam cancel
	place(player, walled.b)
	boss.global_position = (walled.a as Vector3) + Vector3.UP * 0.05
	await frames(6)
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.IDLE and beam_events["end_reason"] == "los_blocked",
		"Ducking behind solid cover cancels Kara Kesh beam (reason=%s)" % beam_events["end_reason"])

	# Shield overload with Zat cancels an active Kara Kesh beam and flips HUD to VULNERABLE
	place(player, open.at + open.facing * 6.0)
	boss.global_position = (open.at as Vector3) + Vector3.UP * 0.05
	boss.rotation.y = atan2(-open.facing.x, -open.facing.z)
	boss._kara_kesh_beam_cd = 0.0
	beam_events["end_reason"] = ""
	assert(boss.trigger_kara_kesh_beam(player))
	await frames(48)
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.CHANNELING_BEAM)
	boss.health_component.apply_zat_shot(player)
	await frames(3)
	assert(boss.personal_shield.is_overloaded and not boss.has_active_shield(), "Zat overloads System Lord Personal Shield")
	assert(boss.kara_kesh_state == JaffaAI.KaraKeshState.IDLE and beam_events["end_reason"] == "shield_overloaded",
		"Shield overload immediately interrupts Kara Kesh channel (reason=%s)" % beam_events["end_reason"])
	assert("SHIELD DOWN" in room.hud.boss_shield_label.text, "Boss HUD reflects overloaded shield vulnerability")

	# While overloaded, ballistic damage kills the boss and hides the Boss Bar
	boss.health_component.take_damage(200.0, player, "bullet")
	await frames(3)
	assert(boss.health_component.is_dead, "Ballistic fire eliminates overloaded System Lord")
	assert(not room.hud.boss_panel.visible, "Boss Bar hides cleanly after System Lord is eliminated")

	# Clean up Extraction fixture before checking authored missions
	room._stop_world_combat()
	await frames(8)
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(4)
	net.disconnect_game()

	# ==========================================================================
	# 5. Authored Mission & Wave Deployments
	# ==========================================================================
	# 5a. Ha'tak Mothership Objective: Bridge Boss + Engineering Heavy + Upper Officer
	var ms_room := (load("res://scenes/mission/GoauldMothershipObjectiveMission.tscn") as PackedScene).instantiate() as ModularMission
	root.add_child(ms_room)
	if not ms_room.is_started:
		await ms_room.started
	assert(ms_room.setup_errors.is_empty(), str(ms_room.setup_errors))
	var ms_roles := {"goauld_lord": 0, "heavy": 0, "officer": 0}
	for enemy: Node in ms_room.enemies.get_children():
		var j := enemy as JaffaAI
		if j != null and ms_roles.has(j.combat_role):
			ms_roles[j.combat_role] += 1
	assert(ms_roles["goauld_lord"] == 1 and ms_roles["heavy"] == 1 and ms_roles["officer"] == 1,
		"Mothership Objective deploys Boss, Heavy, and Officer: %s" % str(ms_roles))
	ms_room._stop_world_combat()
	ms_room.queue_free()
	await frames(5)

	# 5b. Goa'uld Infiltration: Officer priority alarm runner + Grenadier in command + 6 sentries
	var inf_room := (load("res://scenes/mission/GoauldInfiltrationMission.tscn") as PackedScene).instantiate() as ModularMission
	root.add_child(inf_room)
	if not inf_room.is_started:
		await inf_room.started
	assert(inf_room.setup_errors.is_empty(), str(inf_room.setup_errors))
	var inf_officer: JaffaAI = null
	var inf_trooper: JaffaAI = null
	var inf_grenadiers := 0
	for enemy: Node in inf_room.enemies.get_children():
		var j := enemy as JaffaAI
		if j == null:
			continue
		if j.is_officer():
			inf_officer = j
		elif j.is_grenadier():
			inf_grenadiers += 1
		elif j.combat_role == JaffaAI.ROLE_TROOPER and inf_trooper == null:
			inf_trooper = j
	assert(inf_officer != null and inf_grenadiers == 1 and inf_room.enemies.get_child_count() == 6,
		"Goa'uld Infiltration preserves 6 sentries with Officer and Shock Grenadier")
	# Priority alarm runner test: alert both Officer and Trooper; Officer takes priority!
	inf_officer.perception.alert(null, inf_officer.global_position)
	inf_trooper.perception.alert(null, inf_trooper.global_position)
	inf_room.alert._pick_runner([inf_trooper, inf_officer])
	assert(inf_room.alert.runner == inf_officer, "MissionAlert prioritizes alerted Officer as alarm runner")
	inf_room._stop_world_combat()
	inf_room.queue_free()
	await frames(5)

	# 5c. Outdoor Gate Site: bunker command patrol has Officer + Grenadier
	var ow_room := (load("res://scenes/mission/OutdoorGateSiteMission.tscn") as PackedScene).instantiate() as ModularMission
	root.add_child(ow_room)
	if not ow_room.is_started:
		await ow_room.started
	assert(ow_room.setup_errors.is_empty(), str(ow_room.setup_errors))
	var ow_officer := 0
	var ow_grenadier := 0
	for enemy: Node in ow_room.enemies.get_children():
		var j := enemy as JaffaAI
		if j != null:
			if j.is_officer(): ow_officer += 1
			if j.is_grenadier(): ow_grenadier += 1
	assert(ow_officer == 1 and ow_grenadier == 1, "Outdoor Gate Site deploys bunker Officer & Grenadier")
	ow_room._stop_world_combat()
	ow_room.queue_free()
	await frames(5)

	# 5d. SGC Defense Wave 4 Climax spawns a Goa'uld System Lord Boss at the Gate Room
	var sgc := (load("res://scenes/main/GateRoom.tscn") as PackedScene).instantiate() as GateRoom
	root.add_child(sgc)
	await frames(4)
	sgc.wave_manager.trigger_climax_incursion()
	await frames(3)
	var sgc_bosses := 0
	for enemy: Node in sgc.get_node("Enemies").get_children():
		var j := enemy as JaffaAI
		if j != null and j.is_boss() and j.has_active_shield():
			sgc_bosses += 1
	assert(sgc_bosses == 1, "SGC Defense Wave 4 Climax spawns shielded Goa'uld System Lord Boss")
	sgc._stop_world_combat()
	sgc.queue_free()
	await frames(6)

	print("PASS SW-3 Specialist Enemies & Goa'uld Boss: Officer rally/alarm, Heavy plate/burst/suppression, Shock Grenadier, System Lord shield + Kara Kesh push/beam + HUD bar, and authored placements")
	await preload("res://tests/support/finish.gd").success(self)
