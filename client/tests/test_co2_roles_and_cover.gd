extends SceneTree
## Single-process CO-2 roles, field medic aid, offworld deployable cover, and lobby/HUD alignment checks.

const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
const JAFFA_SCENE := "res://scenes/entities/JaffaGuard.tscn"
const AIRMAN_SCENE := "res://scenes/entities/SGCAirman.tscn"
const PLASMA_BOLT_SCENE := "res://scenes/entities/PlasmaBolt.tscn"


func frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func _init() -> void:
	call_deferred("run")


func _verify_lobby_alignment() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var lobby := (preload("res://scenes/main/Lobby.tscn") as PackedScene).instantiate() as LobbyUI
	var player_scene := preload("res://scenes/entities/Player.tscn") as PackedScene
	root.add_child(lobby)
	var viewport := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	lobby.size = viewport.size
	await frames(2)
	for control: Control in [lobby.class_option_button, lobby.class_desc_label, lobby.difficulty_option_button]:
		assert(viewport.encloses(control.get_global_rect()), "Lobby control must stay inside 1280x720: " + str(control.name))

	var classes: Array[String] = [
		SGCNetworkManager.CLASS_SG3_HEAVY,
		SGCNetworkManager.CLASS_CARTER_TECH,
		SGCNetworkManager.CLASS_ONEILL_RECON,
		SGCNetworkManager.CLASS_TEALC_JAFFA,
	]
	for idx: int in range(lobby.class_option_button.item_count):
		lobby.class_option_button.select(idx)
		lobby.class_option_button.item_selected.emit(idx)
		var cid: String = str(lobby.class_option_button.get_selected_metadata())
		assert(cid in classes, "Known class in Lobby selector: " + cid)
		var p := player_scene.instantiate() as PlayerController3D
		p.class_id = cid
		root.add_child(p)
		p.set_physics_process(false)
		var text := lobby.class_desc_label.text
		if cid == SGCNetworkManager.CLASS_CARTER_TECH:
			assert(p.is_field_medic() and p.medkit_charges == 2 and is_equal_approx(p.revive_duration_s(), 1.25))
			assert(text.contains("2x revive") and text.contains("2 medkits"))
		elif cid == SGCNetworkManager.CLASS_SG3_HEAVY:
			assert(not p.is_field_medic() and p.medkit_charges == 0)
			assert(text.contains(".50 cal") and text.contains("30s cooldown"))
		elif cid == SGCNetworkManager.CLASS_ONEILL_RECON:
			assert(not p.is_field_medic() and p.medkit_charges == 0 and p.c4_charges_remaining == 2)
			assert(text.contains("2 remote or timed C4 satchels"))
		elif cid == SGCNetworkManager.CLASS_TEALC_JAFFA:
			assert(not p.is_field_medic() and p.medkit_charges == 0)
			assert(text.contains("Heat-based Staff") and text.contains("Goa'uld shields"))
		p.free()
	lobby.free()
	net.selected_class_id = SGCNetworkManager.CLASS_SG3_HEAVY


func run() -> void:
	await _verify_lobby_alignment()

	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	net.selected_class_id = SGCNetworkManager.CLASS_CARTER_TECH
	assert(net.set_mission(MISSION))
	assert(net.host_game(0) == OK)
	(main.current_lobby as LobbyUI)._on_start_game_pressed()
	await frames(3)
	var room := main.current_gate_room as ModularMission
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	for enemy in room.enemies.get_children():
		enemy.set_physics_process(false)

	var carter := room.players_container.get_node("1") as PlayerController3D
	var hud := room.hud
	assert(carter.is_field_medic() and carter.medkit_charges == 2)
	assert(hud != null and hud.gadget_label.text.contains("FIELD MEDKIT (2/2)"))
	assert(hud.gadget_label.text.contains("SHIELD (1/1)") and not hud.gadget_label.text.contains("TACTICAL SATCHEL") and not hud.gadget_label.text.contains("(0/3)"))

	var entry := room.level.marker(room.level.layout.entry_instance, room.level.layout.entry_marker)
	carter.global_position = entry + Vector3(0.0, 0.05, 0.0)
	room._spawn_player(2, SGCNetworkManager.CLASS_SG3_HEAVY, entry + Vector3(1.5, 0.05, 0.0))
	var heavy := room.players_container.get_node("2") as PlayerController3D
	await frames(5)
	assert(not heavy.is_field_medic() and heavy.medkit_charges == 0)

	# 1. Role-based revive speed & recovery HP: Carter = 1.25s -> 75% HP; Heavy = 2.5s -> 40% HP
	heavy.health_component.take_damage(9999.0, null, "bullet")
	assert(heavy.health_component.is_downed)
	Input.action_press("interact")
	for _i: int in range(85):
		await physics_frame
		if not heavy.health_component.is_downed:
			break
	Input.action_release("interact")
	await frames(2)
	assert(not heavy.health_component.is_downed, "Carter must finish medic revive within ~1.25s")
	assert(is_equal_approx(heavy.health_component.current_health, heavy.health_component.max_health * 0.75),
		"Medic revive restores 75%% HP, got %.1f" % heavy.health_component.current_health)

	# Baseline Heavy reviver still takes > 1.5s (2.5s) and restores 40% HP
	carter.health_component.take_damage(9999.0, null, "bullet")
	assert(carter.health_component.is_downed)
	heavy.health_component.revive(null) # ensure standing
	carter.health_component.revive(heavy)
	assert(not carter.health_component.is_downed)
	assert(is_equal_approx(carter.health_component.current_health, carter.health_component.max_health * 0.40),
		"Non-medic revive restores 40%% HP, got %.1f" % carter.health_component.current_health)

	# 2. Field Medkit validation, healing & carryover
	carter.health_component.heal(carter.health_component.max_health)
	heavy.health_component.heal(heavy.health_component.max_health)
	heavy.health_component.current_health = 50.0 # Heavy is 50 / 150 HP

	# Non-medic cannot apply medkit
	var bad_offer := heavy.field_aid_offer(carter)
	assert(float(bad_offer.heal) == 0.0 and str(bad_offer.reason).contains("TECH SPECIALIST"))

	# Out of reach > 3m rejects without spending charge
	heavy.global_position = carter.global_position + Vector3(4.2, 0.0, 0.0)
	await frames(2)
	carter.request_field_aid(heavy)
	assert(carter.medkit_charges == 2 and heavy.health_component.current_health == 50.0, "Out-of-reach aid must not spend charge")

	# Valid in-reach aid heals +50 HP and decrements 2 -> 1
	heavy.global_position = carter.global_position + Vector3(0.0, 0.0, -1.8)
	carter.rotation.y = 0.0
	await frames(4)
	carter.request_field_aid(heavy)
	await frames(1)
	assert(is_equal_approx(heavy.health_component.current_health, 100.0), "Medkit heals +50 HP")
	assert(carter.medkit_charges == 1, "Medkit charge decrements to 1")
	assert(hud.gadget_label.text.contains("FIELD MEDKIT (1/2)"))

	# Immediate repeat blocked by 1000ms cooldown without consuming charge
	carter.request_field_aid(heavy)
	assert(carter.medkit_charges == 1 and is_equal_approx(heavy.health_component.current_health, 100.0))

	# Injured self-heal once cooldown expires
	carter._next_field_aid_ms = 0
	carter.health_component.current_health = 45.0
	carter.request_field_aid(null)
	assert(is_equal_approx(carter.health_component.current_health, 95.0), "Self-aid heals +50 HP")
	assert(carter.medkit_charges == 0, "Medkit charge decrements to 0")
	carter._next_field_aid_ms = 0
	carter.request_field_aid(heavy)
	assert(carter.medkit_charges == 0 and is_equal_approx(heavy.health_component.current_health, 100.0), "Empty medkit rejects safely")

	# Allied AI healing & resupply station restock
	var airman := (load(AIRMAN_SCENE) as PackedScene).instantiate() as SGCAirmanAI
	airman.position = room.to_local(carter.global_position + Vector3(1.2, 0.0, 0.0))
	room.add_child(airman)
	await frames(2)
	carter.medkit_charges = 1
	airman.health_component.current_health = 60.0
	carter.request_field_aid(airman)
	assert(airman.health_component.current_health > 60.0 and carter.medkit_charges == 0, "Carter heals injured Airman")
	airman.queue_free()
	if room.allies_container != null:
		for ally in room.allies_container.get_children():
			ally.set_physics_process(false)

	var armoury := room.level.get_node_or_null("armoury") as LevelModule
	assert(armoury != null)
	var station := armoury.get_node_or_null("Attachments/RoomContent/inventory") as ArmoryResupplyStation
	assert(station != null)
	carter.global_position = station.global_position + Vector3(0.5, 0.0, 0.5)
	station.interact(carter)
	assert(carter.medkit_charges == 2, "Armoury restocks Carter medkits to 2")
	station.reset_station()
	heavy.global_position = station.global_position + Vector3(0.5, 0.0, 0.5)
	station.interact(heavy)
	assert(heavy.medkit_charges == 0, "Armoury keeps non-medic medkits at 0")

	# State carryover persistence check
	carter.medkit_charges = 1
	var session := MissionSession.new()
	var captured := session.capture_state(carter)
	assert(int(captured.get("medkit_charges", -1)) == 1)
	var clone := (preload("res://scenes/entities/Player.tscn") as PackedScene).instantiate() as PlayerController3D
	clone.class_id = SGCNetworkManager.CLASS_CARTER_TECH
	root.add_child(clone)
	session.apply_state(clone, captured)
	assert(clone.medkit_charges == 1, "MissionSession carryover preserves medkit_charges")
	clone.medkit_charges = 2
	var cm := root.get_node("CampaignManager")
	cm.squad_carryover[clone.peer_id] = captured
	cm.apply_carryover(clone)
	assert(clone.medkit_charges == 1, "CampaignManager carryover preserves medkit_charges")
	cm.squad_carryover.clear()
	clone.queue_free()
	session.queue_free()
	await frames(2)

	# 3. Offworld Deployable Shield: placement validation, cover, LOS blocking & plasma absorption
	# Wall clearance rejection without losing charge
	var box := PhysicsRayQueryParameters3D.create(entry + Vector3(0, 0.55, 0), entry + Vector3(0, 0.55, -20.0), 1)
	var wall_hit := room.get_world_3d().direct_space_state.intersect_ray(box)
	assert(not wall_hit.is_empty(), "Entry room must have a wall for clearance check")
	var wall_pt: Vector3 = wall_hit["position"]
	carter.global_position = Vector3(wall_pt.x, entry.y + 0.05, wall_pt.z + 0.45)
	carter.rotation.y = 0.0
	await frames(3)
	var before_shields := carter.deployable_shields_count
	carter.deploy_shield()
	await frames(2)
	assert(carter.deployable_shields_count == before_shields, "Wall-blocked placement must reject without consuming shield")

	# Valid open floor placement inside entry module with clear forward sightline
	carter.global_position = entry + Vector3(0.0, 0.05, 1.8)
	carter.rotation.y = 0.0
	heavy.global_position = entry + Vector3(2.2, 0.05, 2.2)
	await frames(3)
	carter.deploy_shield()
	await frames(3)
	assert(carter.deployable_shields_count == 0, "Valid offworld deployment consumes 1 shield")
	var deployments := room.get_node("FieldKitDeployments") as Node3D
	var shield: DeployableShield = null
	for child in deployments.get_children():
		if child is DeployableShield:
			shield = child as DeployableShield
	assert(shield != null and shield.is_in_group("cover") and shield.is_in_group("deployable_shield"))
	assert(shield in LevelNavigator.cover_props(room.level), "Deployed offworld shield registers in LevelNavigator.cover_props")

	# Overlap rejection
	carter.deployable_shields_count = 1
	carter.deploy_shield()
	await frames(2)
	assert(carter.deployable_shields_count == 1, "Overlapping shield deployment must reject without consuming charge")

	# Auto-cover + Jaffa LOS block while crouched behind offworld shield + peek exposure
	carter.global_position = shield.global_position + Vector3(0.0, 0.05, 1.0)
	carter.set_physics_process(true)
	await frames(8)
	assert(carter.is_in_cover and carter.is_crouching and not carter.is_peeking, "Operative auto-crouches in cover behind deployed shield")

	var jaffa := (load(JAFFA_SCENE) as PackedScene).instantiate() as JaffaAI
	jaffa.position = room.enemies.to_local(shield.global_position + Vector3(0.0, 0.05, -2.8))
	room.enemies.add_child(jaffa, true)
	jaffa.set_physics_process(false)
	await frames(3)
	assert(LevelNavigator.prop_blocks(shield, carter.global_position, jaffa.global_position), "LevelNavigator.prop_blocks sees DeployableShield occlusion")
	assert(not jaffa._has_line_of_sight(carter, true), "Crouched operative behind shield breaks Jaffa eye LOS")
	carter.is_peeking = true
	carter.is_crouching = false
	assert(jaffa._has_line_of_sight(carter, true), "Standing/peeking above 0.9m shield exposes LOS")
	carter.is_peeking = false
	carter.is_crouching = true

	# Incoming plasma bolt impacts shield instead of operative
	var hp_before := carter.health_component.current_health
	var shield_hp_before := shield.health_component.current_health
	var bolt := (load(PLASMA_BOLT_SCENE) as PackedScene).instantiate() as PlasmaBolt
	room.add_child(bolt)
	var bolt_origin := shield.global_position + Vector3(0.0, 0.65, -2.0)
	var aim_dir := ((carter.global_position + Vector3(0.0, 0.60, 0.0)) - bolt_origin).normalized()
	bolt.initialize(bolt_origin, aim_dir, jaffa, true)
	for _i: int in range(30):
		await physics_frame
		if not is_instance_valid(bolt) or shield.health_component.current_health < shield_hp_before:
			break
	assert(shield.health_component.current_health < shield_hp_before, "Plasma bolt hits deployed shield")
	assert(is_equal_approx(carter.health_component.current_health, hp_before), "Operative behind shield takes no bolt damage")

	shield.health_component.take_damage(700.0)
	assert(shield.collision_layer == 0 and not shield.is_in_group("cover"))
	await frames(30)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS CO-2 roles, field medic revive/aid, offworld deployable cover, and lobby/HUD alignment")
	await preload("res://tests/support/finish.gd").success(self)
