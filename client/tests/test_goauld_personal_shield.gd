extends SceneTree
## Single-process verification for SW-2: Goa'uld Personal Shield & Countermeasures.
## Covers velocity-gated ballistic deflection, suppression immunity, perception/alert
## escalation, operative slow/flank melee ([F]), silent rear takedown, Zat/plasma/explosive
## overload & recharge, kawoosh bypass, authored mission deployment, and stand-down cleanup.

const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const SHOCK := "res://scenes/entities/JaffaShockGuard.tscn"

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


func rays_clear(from: Vector3, to: Vector3) -> int:
	var space := room.get_world_3d().direct_space_state
	var count := 0
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0.0, eye, 0.0), to + Vector3(0.0, aim, 0.0), 1
			)
			if space.intersect_ray(query).is_empty():
				count += 1
	return count


func clear(from: Vector3, to: Vector3) -> bool:
	return rays_clear(from, to) == 4


func open_setup() -> Dictionary:
	for item in level.layout.instances:
		var at := level.marker(item.id, &"patrol")
		for facing: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var front := at + facing * 6.0
			var behind := at - facing * 5.0
			if (
				on_floor(at) and on_floor(front) and on_floor(behind)
				and clear(at, front) and clear(at, behind)
			):
				return {"at": at, "facing": facing, "front": front, "behind": behind}
	return {}


func shielded_sentry(at: Vector3, facing: Vector3, shielded: bool = true) -> JaffaAI:
	serial += 1
	var jaffa := (load(SHOCK) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "ShieldSentry%d" % serial
	jaffa.has_personal_shield = shielded
	jaffa.position = room.enemies.to_local(at + Vector3(0.0, 0.05, 0.0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var points: Array[Vector3] = [at]
	jaffa.start_patrol(points)
	return jaffa


func reset_calm_compound() -> void:
	for enemy: Node in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)
	room.alert.alert_level = MissionAlert.Level.CALM
	room.alert.spotted = false
	room.alert.runner = null
	room.alert.runner_name = ""


func face_toward(actor: Node3D, target: Node3D) -> void:
	var dir := target.global_position - actor.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		actor.rotation.y = atan2(-dir.x, -dir.z)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	var bindings := root.get_node("KeybindingManager")
	assert(bindings.ACTIONS.has("melee"), "KeybindingManager must register canonical melee action")
	assert(InputMap.has_action("melee"), "InputMap must have melee action")

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
	player.health_component.current_health = 1000000.0
	await reset_calm_compound()

	var open := open_setup()
	assert(not open.is_empty(), "Fixture has an open setup for SW-2 shield tests")

	# --- 1. Ballistic & .50 cal deflection + suppression immunity + alert escalation ---
	var guard := shielded_sentry(open.at, open.facing, true)
	var witness := shielded_sentry(open.front, open.facing, false)
	await frames(4)
	assert(guard.has_active_shield(), "Shielded officer starts with active personal shield")
	assert(guard.personal_shield != null and guard.personal_shield.aura_mesh.visible, "Shield aura visible while active")
	assert(not guard.can_be_suppressed(), "Actively shielded Jaffa resists gunfire suppression")
	guard.register_incoming_fire(player.global_position)
	guard.register_incoming_fire(player.global_position)
	guard.register_incoming_fire(player.global_position)
	assert(not guard.is_suppressed, "Incoming ballistic pressure does not suppress shielded Jaffa")

	place(player, open.behind)
	face_toward(player, guard)
	var p90 := WeaponP90.new()
	p90.position = Vector3(0.0, 1.25, 0.0)
	player.add_child(p90)
	await frames(1)
	var p90_dir := ((guard.global_position + Vector3(0.0, 1.0, 0.0)) - p90.muzzle_point.global_position).normalized()
	assert(p90.try_fire(0.0, p90_dir), "P90 shot fired at shielded officer")
	await frames(15)
	assert(guard.health_component.current_health == 140.0, "P90 bullet deflected by personal shield")
	assert(guard.has_active_shield() and guard.personal_shield.deflect_count >= 1, "Shield remains intact and logs deflection")
	assert(guard.awareness_level == JaffaPerception.Level.ALERTED, "Ballistic deflection immediately alerts shielded sentry")
	assert(guard.perception.target == player, "Shielded sentry locks onto shooter after deflection")
	assert(witness.awareness_level == JaffaPerception.Level.ALERTED, "Shielded sentry spreads 1-hop alert on deflection")
	assert(room.alert.alert_level == MissionAlert.Level.SEARCHING, "MissionAlert escalates to SEARCHING on shield deflection")

	guard.health_component.take_damage(52.0, player, "50cal_heavy")
	assert(guard.health_component.current_health == 140.0, ".50 cal kinetic round is deflected by personal shield")
	assert(guard.personal_shield.deflect_count >= 2)

	# --- 2. Frontal slow melee bypasses shield + cooldown + flank melee lethal bypass ---
	place(player, open.at + open.facing * 1.4)
	face_toward(player, guard)
	guard.rotation.y = atan2(-open.facing.x, -open.facing.z)
	await frames(2)
	assert(not player.is_flanking_target(guard), "Standing directly in front is not flanking")
	var front_prompt := player.close_quarters_prompt()
	assert("SLOW MELEE (BYPASS SHIELD)" in front_prompt, "Prompt offers slow melee bypass: %s" % front_prompt)
	player.melee_cooldown = 0.0
	player._server_melee_cooldown = 0.0
	assert(player.try_melee_strike(), "Frontal slow melee strike hits shielded officer")
	await frames(2)
	assert(guard.health_component.current_health == 75.0, "Frontal slow melee deals 65 HP through active shield")
	assert(guard.has_active_shield(), "Slow melee penetrates without popping shield")
	assert(not player.try_melee_strike(), "Melee cooldown blocks immediate repeat strike")

	# Move behind/side flank to deliver high-damage flank strike through shield
	player.melee_cooldown = 0.0
	player._server_melee_cooldown = 0.0
	place(player, open.at - open.facing * 1.4)
	face_toward(player, guard)
	guard.rotation.y = atan2(-open.facing.x, -open.facing.z)
	await frames(2)
	assert(player.is_flanking_target(guard), "Rear/side approach counts as flanking")
	var flank_prompt := player.close_quarters_prompt()
	assert("FLANK MELEE (BYPASS SHIELD)" in flank_prompt, "Prompt offers flank melee bypass: %s" % flank_prompt)
	assert(player.try_melee_strike(), "Flank slow melee strikes shielded officer")
	await frames(3)
	assert(guard.health_component.is_dead, "150 HP flank melee finishes wounded shielded officer")
	assert(not guard.has_active_shield() and not guard.personal_shield.aura_mesh.visible, "Shield visual turns off on death")

	p90.queue_free()
	await reset_calm_compound()

	# --- 3. Silent rear stealth takedown & unalerted flank kill bypass shield silently ---
	var silent_guard := shielded_sentry(open.at, open.facing, true)
	var silent_witness := shielded_sentry(open.front, open.facing, false)
	await frames(4)
	place(player, open.at - open.facing * 1.5)
	face_toward(player, silent_guard)
	await frames(2)
	assert(silent_guard.can_be_taken_down_by(player), "Unalerted shielded sentry allows rear takedown")
	assert("STEALTH TAKEDOWN" in player.close_quarters_prompt())
	player._try_interact()
	await frames(3)
	assert(silent_guard.health_component.is_dead, "Stealth takedown eliminates shielded sentry")
	assert(silent_witness.awareness_level == JaffaPerception.Level.UNAWARE, "Nearby sentry stays UNAWARE after shielded takedown")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound stays CALM after shielded takedown")

	# Side flank melee on an unalerted 140 HP shielded sentry (outside rear stealth_takedown dot)
	var flank_guard := shielded_sentry(open.at, open.facing, true)
	var side_dir: Vector3 = (open.facing as Vector3).cross(Vector3.UP).normalized()
	await frames(3)
	player.melee_cooldown = 0.0
	player._server_melee_cooldown = 0.0
	place(player, open.at + side_dir * 1.5)
	face_toward(player, flank_guard)
	await frames(2)
	assert(not flank_guard.can_be_taken_down_by(player), "True 90-degree flank is outside rear stealth cone")
	assert(player.is_flanking_target(flank_guard), "True 90-degree side approach qualifies as flank")
	assert(player.try_melee_strike(), "150 HP flank strike lands on unalerted shielded sentry")
	await frames(15)
	assert(flank_guard.health_component.is_dead, "150 HP flank melee is lethal on full-HP 140 HP Horus officer")
	assert(silent_witness.awareness_level == JaffaPerception.Level.UNAWARE, "Silent flank kill does not alert nearby witness")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound stays CALM on silent flank kill")

	await reset_calm_compound()

	# --- 4. Zat overload (1st shot collapses shield & alerts; 2nd stuns) + recharge ---
	var zat := WeaponZat.new()
	zat.position = Vector3(0.0, 1.25, 0.0)
	player.add_child(zat)
	var gun := WeaponP90.new()
	gun.position = Vector3(0.0, 1.25, 0.0)
	player.add_child(gun)

	var zat_guard := shielded_sentry(open.at, open.facing, true)
	place(player, open.at - open.facing * 4.5)
	face_toward(player, zat_guard)
	await frames(4)
	var zat_dir := ((zat_guard.global_position + Vector3(0.0, 1.0, 0.0)) - zat.muzzle_point.global_position).normalized()
	assert(zat.try_fire(0.0, zat_dir), "1st Zat shot hits shielded sentry")
	await frames(3)
	assert(zat_guard.personal_shield.is_overloaded and not zat_guard.has_active_shield(), "1st Zat shot overloads personal shield")
	assert(not zat_guard.personal_shield.aura_mesh.visible, "Shield aura hides when overloaded")
	assert(not zat_guard.health_component.is_stunned, "1st Zat shot is absorbed by shield without stunning")
	assert(zat_guard.awareness_level == JaffaPerception.Level.ALERTED, "Overloading personal shield with Zat alerts sentry")
	assert(zat_guard.can_be_suppressed(), "Overloaded sentry becomes suppressible by gunfire")

	var gun_dir := ((zat_guard.global_position + Vector3(0.0, 1.0, 0.0)) - gun.muzzle_point.global_position).normalized()
	assert(gun.try_fire(0.0, gun_dir), "Bullet hits overloaded sentry")
	await frames(2)
	assert(zat_guard.health_component.current_health == 118.0, "Bullets damage HP while shield is overloaded")

	zat.fire_cooldown = 0.0
	zat.current_heat = 0.0
	assert(zat.try_fire(0.0, zat_dir), "2nd Zat shot stuns sentry once shield is down")
	await frames(3)
	assert(zat_guard.health_component.is_stunned, "2nd Zat shot stuns after shield overload")

	# Verify recharge after overload timer expires on a live unstunned officer
	var recharge_guard := shielded_sentry(open.front, open.facing, true)
	await frames(3)
	recharge_guard.health_component.apply_zat_shot(player)
	assert(recharge_guard.personal_shield.is_overloaded)
	recharge_guard.personal_shield.overload_timer = 0.05
	await frames(8)
	assert(recharge_guard.has_active_shield() and not recharge_guard.personal_shield.is_overloaded, "Personal shield restores after overload duration")
	assert(recharge_guard.personal_shield.energy == recharge_guard.personal_shield.max_energy)
	assert(recharge_guard.personal_shield.aura_mesh.visible, "Restored shield aura becomes visible again")

	# --- 5. Ma'Tok Staff plasma drain, C4/Claymore shatter + bleed-through, Kawoosh bypass ---
	var plasma_guard := shielded_sentry(open.at, open.facing, true)
	await frames(3)
	plasma_guard.health_component.take_damage(85.0, player, "plasma")
	assert(plasma_guard.health_component.current_health == 140.0 and is_equal_approx(plasma_guard.personal_shield.energy, 45.0), "1st plasma shot drains 55 shield energy")
	assert(plasma_guard.has_active_shield(), "Shield still active at 45 energy")
	plasma_guard.health_component.take_damage(85.0, player, "plasma")
	assert(plasma_guard.health_component.current_health == 140.0 and plasma_guard.personal_shield.is_overloaded, "2nd plasma shot overloads shield")
	plasma_guard.health_component.take_damage(85.0, player, "plasma")
	assert(plasma_guard.health_component.current_health == 55.0, "3rd plasma shot deals full HP damage to unshielded Jaffa")

	var blast_guard := shielded_sentry(open.at, open.facing, true)
	await frames(2)
	blast_guard.health_component.take_damage(100.0, player, "c4_explosion")
	assert(blast_guard.personal_shield.is_overloaded and blast_guard.health_component.current_health == 90.0, "C4 overloads shield and deals 50% concussive bleed-through")

	var kawoosh_guard := shielded_sentry(open.at, open.facing, true)
	await frames(2)
	kawoosh_guard.health_component.take_damage(999.0, null, "kawoosh_vortex")
	assert(kawoosh_guard.health_component.is_dead and not kawoosh_guard.has_active_shield(), "Kawoosh vortex bypasses personal shield")

	# Verify stand_down disables projection cleanly
	var standdown_guard := shielded_sentry(open.at, open.facing, true)
	await frames(2)
	assert(standdown_guard.personal_shield.aura_mesh.visible)
	standdown_guard.stand_down()
	assert(standdown_guard.personal_shield.frozen and not standdown_guard.has_active_shield())
	assert(not standdown_guard.personal_shield.aura_mesh.visible)

	# --- 6. Authored mission definitions & Mothership Bridge Commander spawn ---
	var infil_def := load("res://resources/missions/goauld_infiltration.tres") as MissionDefinition
	assert(infil_def != null and infil_def.reinforcements.size() >= 2)
	assert(infil_def.reinforcements[1].shock_guard and infil_def.reinforcements[1].personal_shield, "Infiltration second reinforcement deploys shielded Horus lead")

	var alarm_def := load("res://resources/missions/goauld_alarm_escape.tres") as MissionDefinition
	assert(alarm_def != null and alarm_def.reinforcements[1].personal_shield)

	zat.queue_free()
	gun.queue_free()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()

	var ms_scene := load("res://scenes/mission/GoauldMothershipObjectiveMission.tscn") as PackedScene
	var ms_room := ms_scene.instantiate() as ModularMission
	root.add_child(ms_room)
	if not ms_room.is_started:
		await ms_room.started
	assert(ms_room.setup_errors.is_empty(), str(ms_room.setup_errors))
	var shielded_bridge := 0
	for enemy: Node in ms_room.enemies.get_children():
		var j := enemy as JaffaAI
		if j != null and j.is_shock_guard and j.has_personal_shield and j.has_active_shield():
			shielded_bridge += 1
	assert(shielded_bridge == 1, "Mothership Bridge spawns shielded Horus Commander (%d)" % shielded_bridge)
	ms_room.queue_free()
	await frames(3)

	print("PASS SW-2 Goa'uld Personal Shield: ballistic deflection, suppression immunity, perception/alert, slow/flank melee, stealth takedown, Zat/plasma/C4 overload & recharge, and mission deployment")
	await preload("res://tests/support/finish.gd").success(self)
