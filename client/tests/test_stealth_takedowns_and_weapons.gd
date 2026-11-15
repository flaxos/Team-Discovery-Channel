extends SceneTree
## Stealth takedowns from behind, quiet Zat incapacitation (roadmap SW-1), and licensed external
## .glb weapon model ingestion with D-015 material sanitization (roadmap AP-1a).
const MISSION := SGCNetworkManager.MISSION_MODULAR_EXTRACTION
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var serial := 0


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func on_floor(spot: Vector3) -> bool:
	return NavigationServer3D.map_get_closest_point(level.navigation_map, spot).distance_to(spot) < 0.4


func rays_clear(from: Vector3, to: Vector3) -> int:
	var space := room.get_world_3d().direct_space_state
	var count := 0
	for eye: float in [1.0, 1.4]:
		for aim: float in [1.0, 1.5]:
			var query := PhysicsRayQueryParameters3D.create(
				from + Vector3(0, eye, 0), to + Vector3(0, aim, 0), 1
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


func sentry(at: Vector3, facing: Vector3) -> JaffaAI:
	serial += 1
	var jaffa := (load(JAFFA) as PackedScene).instantiate() as JaffaAI
	jaffa.name = "StealthSentry%d" % serial
	jaffa.position = room.enemies.to_local(at + Vector3(0, 0.05, 0))
	jaffa.rotation.y = atan2(-facing.x, -facing.z)
	room.enemies.add_child(jaffa, true)
	var points: Array[Vector3] = [at]
	jaffa.start_patrol(points)
	return jaffa


func retire(jaffa: JaffaAI) -> void:
	if is_instance_valid(jaffa):
		jaffa.queue_free()
	await frames(2)


func verify_ap1a_weapon_models() -> void:
	var repo_root := ProjectSettings.globalize_path("res://").trim_suffix("client/").trim_suffix("client")
	var attr_path := repo_root.path_join("credits/ATTRIBUTIONS.md")
	var lic_path := repo_root.path_join("credits/licenses/CC0-1.0.txt")
	assert(FileAccess.file_exists(attr_path), "AP-1a provenance manifest exists: " + attr_path)
	assert(FileAccess.file_exists(lic_path), "AP-1a license text exists: " + lic_path)
	var attr_text := FileAccess.get_file_as_string(attr_path)
	assert(attr_text.contains("p90_smg.glb") and attr_text.contains("mp5_silenced.glb"), "Manifest records both weapon GLBs")

	for pair: Array in [[WeaponP90, "p90"], [WeaponMP5, "mp5"]]:
		var script_cls: GDScript = pair[0]
		var expected_id: String = pair[1]
		var gun := script_cls.new() as WeaponBase
		room.add_child(gun)
		await frames(1)
		assert(gun.weapon_id == expected_id)
		var imported := gun.get_node_or_null("WeaponModel/ImportedGLB") as Node3D
		assert(imported != null, "ImportedGLB node attached for " + expected_id)
		var meshes := imported.find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty(), "ImportedGLB contains MeshInstance3D children for " + expected_id)
		for node in meshes:
			var mi := node as MeshInstance3D
			assert(mi.mesh != null and mi.mesh.get_aabb().size.length() > 0.1, "Valid mesh AABB for " + expected_id)
			for s in range(mi.mesh.get_surface_count()):
				var mat := mi.get_surface_override_material(s) as BaseMaterial3D
				if mat == null:
					mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
				assert(mat != null and is_zero_approx(mat.metallic), "D-015 metallic == 0.0 on " + expected_id)
		assert(gun.muzzle_point != null and gun.muzzle_point.position.z < -0.25, "MuzzlePoint in front (-Z) for " + expected_id)
		gun.queue_free()
	await frames(2)


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
	player.health_component.current_health = 1000000.0
	for enemy in room.enemies.get_children():
		enemy.queue_free()
	await frames(3)

	# --- 1. AP-1a: Verify external .glb weapon ingestion, D-015 material rule, and provenance ---
	await verify_ap1a_weapon_models()

	var open := open_setup()
	assert(not open.is_empty(), "Fixture has an open setup for stealth takedown and quiet Zat tests")

	# --- 2. SW-1: Stealth takedown from behind ---
	var guard := sentry(open.at, open.facing)
	var witness := sentry(open.front, open.facing)  # 6 m ahead of guard, facing away
	await frames(5)
	assert(room.alert.alert_level == MissionAlert.Level.CALM)

	# Too far behind (3.5 m > 2.2 m): takedown rejected
	place(player, open.at - open.facing * 3.5)
	await frames(2)
	assert(not guard.can_be_taken_down_by(player), "Out of range cannot be taken down")
	assert(not player.try_stealth_takedown())

	# In front within 1.5 m: frontal takedown rejected
	place(player, open.at + open.facing * 1.5)
	await frames(1)
	assert(not guard.can_be_taken_down_by(player), "Frontal approach cannot be taken down")
	assert(not player.try_stealth_takedown())

	# Behind within 1.5 m: stealth takedown succeeds silently via _try_interact()
	place(player, open.at - open.facing * 1.5)
	player.rotation.y = atan2(-open.facing.x, -open.facing.z)
	await frames(2)
	assert(guard.can_be_taken_down_by(player), "Unalerted guard can be taken down from behind")
	player._try_interact()
	await frames(3)
	assert(guard.health_component.is_dead and guard.current_state == JaffaAI.State.DEAD, "Guard silently eliminated")
	assert(witness.awareness_level == JaffaPerception.Level.UNAWARE, "Nearby sentry did not hear or get alerted")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "Compound alert stays CALM after stealth takedown")

	# Pressing interact again drags the eliminated guard's corpse, then drops it
	player._try_interact()
	await frames(2)
	assert(player.is_dragging_body and player.dragged_body == guard, "Can drag taken-down guard corpse")
	player._try_interact()
	await frames(2)
	assert(not player.is_dragging_body and player.dragged_body == null, "Dropped corpse")
	await retire(guard)

	# Already-alerted guard cannot be stealth-taken-down even from behind
	var alerted_guard := sentry(open.at, open.facing)
	await frames(3)
	alerted_guard.perception.alert(player, player.global_position)
	alerted_guard._publish_awareness()
	place(player, open.at - open.facing * 1.4)
	await frames(2)
	assert(not alerted_guard.can_be_taken_down_by(player), "Alerted guard rejects stealth takedown")
	assert(not player.try_stealth_takedown())
	await retire(alerted_guard)
	await retire(witness)

	# Reset compound alert state to CALM for the quiet Zat test
	room.alert.alert_level = MissionAlert.Level.CALM
	room.alert.spotted = false

	# --- 3. SW-1: Quiet Zat incapacitation, stunned body dragging, silent kill & vaporize ---
	var zat := WeaponZat.new()
	var mp5_check := WeaponMP5.new()
	assert(zat.noise_radius <= 4.0 and zat.noise_radius < mp5_check.noise_radius, "Zat is quieter than suppressed MP5")
	mp5_check.free()
	zat.position = Vector3(0, 1.25, 0)
	player.add_child(zat)
	await frames(1)

	var target_sentry := sentry(open.at, open.facing)
	var sibling_sentry := sentry(open.front, open.facing)  # 6 m ahead of target_sentry, facing away
	place(player, open.at - open.facing * 4.5)  # 4.5 m behind target_sentry (> 4.0 m noise radius)
	await frames(5)
	assert(target_sentry.awareness_level == JaffaPerception.Level.UNAWARE)
	assert(sibling_sentry.awareness_level == JaffaPerception.Level.UNAWARE)

	# 1st Zat shot: stuns target_sentry for 20s without alerting target_sentry, sibling_sentry, or MissionAlert
	var aim_dir := ((target_sentry.global_position + Vector3(0, 1.0, 0)) - zat.muzzle_point.global_position).normalized()
	assert(zat.try_fire(0.0, aim_dir), "1st Zat shot fired")
	await frames(5)
	assert(target_sentry.health_component.is_stunned and target_sentry.current_state == JaffaAI.State.STUNNED, "1st Zat shot stuns sentry")
	assert(target_sentry.awareness_level == JaffaPerception.Level.UNAWARE, "Stunned sentry did not become ALERTED")
	assert(sibling_sentry.awareness_level == JaffaPerception.Level.UNAWARE, "Sibling sentry 6m away was not alerted")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "MissionAlert remains CALM on quiet Zat stun")

	# Move within reach of stunned sentry and drag the unconscious body
	place(player, open.at - open.facing * 1.5)
	await frames(2)
	player._try_interact()
	await frames(2)
	assert(player.is_dragging_body and player.dragged_body == target_sentry, "Operative can drag Zat-stunned Jaffa body")
	player._try_interact()
	await frames(2)
	assert(not player.is_dragging_body, "Operative released stunned Jaffa body")

	# 2nd Zat shot within window: silently kills the stunned sentry
	zat.fire_cooldown = 0.0
	zat.current_heat = 0.0
	place(player, open.at - open.facing * 4.5)
	await frames(2)
	aim_dir = ((target_sentry.global_position + Vector3(0, 1.0, 0)) - zat.muzzle_point.global_position).normalized()
	assert(zat.try_fire(0.0, aim_dir), "2nd Zat shot fired")
	await frames(4)
	assert(target_sentry.health_component.is_dead and target_sentry.current_state == JaffaAI.State.DEAD, "2nd Zat shot kills stunned sentry")
	assert(sibling_sentry.awareness_level == JaffaPerception.Level.UNAWARE, "Sibling sentry still unaware after 2nd Zat shot")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "MissionAlert still CALM after 2nd Zat shot")

	# 3rd Zat shot: vaporizes corpse
	zat.fire_cooldown = 0.0
	zat.current_heat = 0.0
	aim_dir = ((target_sentry.global_position + Vector3(0, 0.9, 0)) - zat.muzzle_point.global_position).normalized()
	assert(zat.try_fire(0.0, aim_dir), "3rd Zat shot fired")
	await frames(4)
	assert(target_sentry.health_component.is_vaporized, "3rd Zat shot vaporizes corpse")
	assert(room.alert.alert_level == MissionAlert.Level.CALM, "MissionAlert remains CALM after vaporization")

	print("SW-1 & AP-1a stealth takedowns, quiet Zat, and weapon GLB ingestion verified.")
	quit(0)
