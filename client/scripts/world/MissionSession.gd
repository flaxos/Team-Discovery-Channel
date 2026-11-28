class_name MissionSession
extends Node
## One mission played across more than one world (docs/plans/gate-travel-split-worlds.md).
## It records which world each peer's operative is in, applies the rule for losing the
## mission, and decides which world this peer presents. A single-world mission has no
## session and behaves exactly as it did.
##
## Worlds are untyped here so that this script and GateRoom do not name each other.
signal presented_changed(world: Node)

## Home first. A world's operatives start at home unless placed elsewhere.
var worlds: Array[Node] = []
## Host only: peer id -> the world its operative belongs in.
var placement: Dictionary = {}
## Host only: mission participant tracking for debrief reporting.
var participants: Dictionary = {}
var went_offworld: Dictionary = {}
var returned_home: Dictionary = {}
var disconnected_offworld: Dictionary = {}
var mission_start_msec: int = 0
var last_debrief: Dictionary = {}
var result: int = -1
var presented: Node = null
const SHADOW_SETTLE_S := 1.5
var _settling := false
var _traveling: Dictionary = {}


func _ready() -> void:
	mission_start_msec = Time.get_ticks_msec()
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		if worlds.size() >= 2 and world_of(id) != home():
			disconnected_offworld[id] = true
		placement.erase(id)
	)


func add_world(world: Node) -> void:
	worlds.append(world)
	world.set(&"session", self)


func home() -> Node:
	return null if worlds.is_empty() else worlds[0]


func world_of(peer_id: int) -> Node:
	var world: Variant = placement.get(peer_id)
	return world as Node if is_instance_valid(world) else home()


func place(peer_id: int, world: Node) -> void:
	placement[peer_id] = world


func record_participant(peer_id: int, class_id: String, callsign: String) -> void:
	var label := callsign.strip_edges()
	if label.is_empty():
		label = "OPERATIVE %d" % peer_id if peer_id != 1 else "OPERATIVE"
	participants[peer_id] = {"callsign": label, "class_id": class_id}
	disconnected_offworld.erase(peer_id)


func _ensure_participants_recorded() -> void:
	var home_world: Node = home()
	for world in worlds:
		var players_node: Node = world.get(&"players_container") as Node
		if players_node == null:
			continue
		for child in players_node.get_children():
			var p := child as PlayerController3D
			if p == null:
				continue
			if not participants.has(p.peer_id):
				var label: String = p.player_callsign
				if label == "OPERATIVE" and p.peer_id != 1:
					label = "OPERATIVE %d" % p.peer_id
				record_participant(p.peer_id, p.class_id, label)
			if world != home_world:
				went_offworld[p.peer_id] = true


## Draw and hear `world` on this peer and hide the others. Every world keeps simulating.
func present(world: Node) -> void:
	presented = world
	for item in worlds:
		item.call(&"set_presented", item == world)
	presented_changed.emit(world)
	_settle_shadows()


## Loading two worlds can leave the engine's shadow atlas in an allocation it never leaves,
## in which every shadowed light is redrawn every frame (measured in the SGC: 3,938 objects
## drawn a frame instead of 472). Rebuilding the atlas once the view has settled clears it.
func _settle_shadows() -> void:
	if DisplayServer.get_name() == "headless" or _settling:
		return
	_settling = true
	await get_tree().create_timer(SHADOW_SETTLE_S).timeout
	_settling = false
	var viewport := get_viewport()
	if viewport == null:
		return
	var size := viewport.positional_shadow_atlas_size
	if size > 0:
		viewport.positional_shadow_atlas_size = size / 2
		viewport.positional_shadow_atlas_size = size


## Decision D-017:
## - Lost when every operative, in every world, is down.
## - Succeeded when site objectives are complete, no standing operative remains offworld,
##   and at least one operative came home.
func squad_changed() -> void:
	evaluate_outcome()


func evaluate_outcome() -> void:
	if result >= 0 or not multiplayer.is_server():
		return
	var operatives := 0
	var standing := 0
	for world in worlds:
		var state: Vector2i = world.call(&"squad_state")
		operatives += state.x
		standing += state.y
	if operatives > 0 and standing == 0:
		finish(false)
		return
	if worlds.size() >= 2:
		var site: Node = worlds[1]
		var site_objectives: Variant = site.get(&"objectives")
		var objectives_done: bool = site_objectives != null and bool(site_objectives.call(&"is_complete"))
		var site_squad: Vector2i = site.call(&"squad_state")
		if objectives_done and site_squad.y == 0 and not returned_home.is_empty():
			finish(true)


## One result for the whole mission, shown in every world.
func finish(victory: bool) -> void:
	if result >= 0:
		return
	result = 1 if victory else 0
	var debrief: Dictionary = _build_debrief(victory)
	last_debrief = debrief

	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and campaign_mgr.get("is_campaign_active") and multiplayer.is_server():
		var captured_squad: Dictionary = {}
		for world in worlds:
			var p_container: Node = world.get(&"players_container") as Node
			if p_container != null:
				for child in p_container.get_children():
					var p := child as PlayerController3D
					if p != null and not captured_squad.has(p.peer_id):
						captured_squad[p.peer_id] = capture_state(p)
		campaign_mgr.call(&"record_stage_completion", debrief, victory, captured_squad)

	for world in worlds:
		world.call(&"_finish_mission", victory)
	if not debrief.is_empty():
		SGCNetworkManager.mission_rpc(self, &"sync_debrief", [debrief, victory])
		sync_debrief(debrief, victory)


func _build_debrief(victory: bool) -> Dictionary:
	if worlds.size() < 2:
		return {}
	_ensure_participants_recorded()
	var home_world: Node = home()
	var site_world: Node = worlds[1]
	var home_players: Node = home_world.get(&"players_container") as Node
	var site_players: Node = site_world.get(&"players_container") as Node

	var returned_names: Array[String] = []
	var lost_names: Array[String] = []
	var pids: Array = participants.keys()
	pids.sort()
	for pid_v: Variant in pids:
		var pid: int = int(pid_v)
		var label: String = str(participants[pid].get("callsign", "OPERATIVE %d" % pid))
		var hp := home_players.get_node_or_null(str(pid)) as PlayerController3D if home_players != null else null
		var sp := site_players.get_node_or_null(str(pid)) as PlayerController3D if site_players != null else null
		if hp != null:
			var hc: HealthComponent = hp.health_component
			if hc != null and (hc.is_dead or hc.is_downed):
				lost_names.append(label)
			elif returned_home.get(pid, false):
				returned_names.append(label)
		elif sp != null:
			var sc: HealthComponent = sp.health_component
			if (sc != null and (sc.is_dead or sc.is_downed)) or not victory:
				lost_names.append(label)
		elif went_offworld.get(pid, false) or disconnected_offworld.get(pid, false):
			lost_names.append(label)

	var kills: int = int(site_world.call(&"hostiles_eliminated_count")) if site_world.has_method(&"hostiles_eliminated_count") else 0
	var site_obj: Variant = site_world.get(&"objectives")
	var site_def: Variant = site_world.get(&"definition")
	var obj_done: int = int(site_obj.get(&"index")) if site_obj != null else 0
	var obj_total: int = site_def.objectives.size() if site_def != null else 0
	var stealth: String = str(site_world.call(&"alert_summary")) if site_world.has_method(&"alert_summary") else "UNDETECTED"
	var duration_s: int = maxi(0, (Time.get_ticks_msec() - mission_start_msec) / 1000)

	var ret_text: String = "NONE" if returned_names.is_empty() else "%d (%s)" % [returned_names.size(), ", ".join(returned_names)]
	var lost_text: String = "NONE" if lost_names.is_empty() else "%d (%s)" % [lost_names.size(), ", ".join(lost_names)]
	var outcome: String = ("ALL AWAY TEAM RETURNED" if lost_names.is_empty() else "RETURNED WITH LOSSES") if victory else "SQUAD LOST"

	var tier: int = SGCNetworkManager.DIFFICULTY_EASY
	var run_seed: int = 0
	var active_mods: Array[String] = []
	var variant_label: String = "STANDARD DIRECTIVE"
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if site_world.get("active_difficulty") != null:
		tier = MissionDifficulty.clamp_tier(int(site_world.get("active_difficulty")))
	elif net != null:
		tier = MissionDifficulty.clamp_tier(net.mission_difficulty)
	if site_world.get("active_run_seed") != null:
		run_seed = int(site_world.get("active_run_seed"))
	if site_world.get("active_modifiers") is Array:
		active_mods = MissionDifficulty.sanitize_modifiers(site_world.get("active_modifiers"))
	if site_world.get("active_variant") is Dictionary:
		var site_var: Dictionary = site_world.get("active_variant") as Dictionary
		if not str(site_var.get("objective_variant_label", "")).is_empty():
			variant_label = str(site_var.get("objective_variant_label"))

	var tier_name: String = MissionDifficulty.tier_name(tier).to_upper()
	var stage_rating: String = MissionDifficulty.compute_stage_rating(
		victory, stealth, lost_names.size(), tier, active_mods
	)
	var status_text: String = "STATUS: %s — %s | TIER: %s | RATING: %s" % [outcome, stealth, tier_name, stage_rating]

	var title_text: String = "EXTRACTION SUCCESSFUL" if victory else "MISSION FAILED"
	var subtitle_text: String = (
		"AWAY TEAM DEBRIEF — RETURNED TO SGC"
		if victory
		else "OFFWORLD OPERATION FAILED — SGC DEBRIEF"
	)
	var leave_text: String = "RETURN TO SGC BRIEFING"

	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null and campaign_mgr.get("is_campaign_active"):
		var stage_idx: int = int(campaign_mgr.get("current_stage_index"))
		var stage_total: int = int(campaign_mgr.get("active_campaign").stage_count()) if campaign_mgr.get("active_campaign") != null else 3
		var stage_data: Dictionary = campaign_mgr.call(&"get_current_stage")
		var stage_title: String = str(stage_data.get("stage_title", "Stage %d" % (stage_idx + 1)))
		if run_seed <= 0:
			run_seed = int(campaign_mgr.get("run_seed"))
		if victory:
			if stage_idx + 1 < stage_total:
				title_text = "STAGE %d SECURED: %s" % [stage_idx + 1, stage_title.to_upper()]
				subtitle_text = "INTEL SECURED: %s" % str(stage_data.get("intel_unlocked_description", "GATE TELEMETRY ACQUIRED"))
				leave_text = "PROCEED TO NEXT STAGE (STAGE %d/%d)" % [stage_idx + 2, stage_total]
			else:
				var camp_rating: Dictionary = MissionDifficulty.compute_campaign_rating(
					campaign_mgr.get("stage_history"), tier, active_mods
				)
				var honors_arr: Array = camp_rating.get("honors", [])
				var honors_suffix: String = "" if honors_arr.is_empty() else " | HONORS: %s" % ", ".join(honors_arr)
				title_text = "CAMPAIGN VICTORY — OPERATION COMPLETE"
				subtitle_text = "ALL %d STAGES CLEARED (%s · GRADE %s%s)" % [
					stage_total, tier_name, str(camp_rating.get("rating", stage_rating)), honors_suffix
				]
				leave_text = "FINALIZE CAMPAIGN"
		else:
			title_text = "STAGE %d COMPROMISED: %s" % [stage_idx + 1, stage_title.to_upper()]
			subtitle_text = "TACTICAL WITHDRAWAL REQUIRED — SGC DEBRIEF"
			leave_text = "RETURN TO SGC BRIEFING"

	return {
		"title": title_text,
		"subtitle": subtitle_text,
		"time": "MISSION DURATION: %02d:%02d" % [duration_s / 60, duration_s % 60],
		"kills": "HOSTILES ELIMINATED: %d" % kills,
		"objectives": "OBJECTIVES COMPLETE: %d / %d" % [obj_done, obj_total],
		"squad": "RETURNED: %s | LOST: %s" % [ret_text, lost_text],
		"status": status_text,
		"leave": leave_text,
		"kill_count": kills,
		"duration_seconds": duration_s,
		"stealth": stealth,
		"lost_count": lost_names.size(),
		"difficulty": tier,
		"rating": stage_rating,
		"run_seed": run_seed,
		"variant_label": variant_label
	}


@rpc("authority", "call_local", "reliable")
func sync_debrief(debrief: Dictionary, victory: bool) -> void:
	last_debrief = debrief
	if victory and home() != null:
		present(home())
	for world in worlds:
		var world_hud: Variant = world.get(&"hud")
		if world_hud != null:
			if debrief.has("kill_count"):
				world_hud.set(&"total_kills", int(debrief["kill_count"]))
			if debrief.has("duration_seconds"):
				world_hud.set(&"mission_seconds", float(debrief["duration_seconds"]))
			world_hud.call(&"set_debrief", debrief)


signal player_traveled(peer_id: int, from_world: Node, to_world: Node)


## Gathers an operative's carried state before removing them from a world.
func capture_state(player: PlayerController3D) -> Dictionary:
	var state: Dictionary = {
		"peer_id": player.peer_id,
		"class_id": player.class_id,
		"player_callsign": player.player_callsign,
		"active_slot": player.active_slot,
		"primary_weapon_id": player.primary_weapon_id,
		"secondary_weapon_id": player.secondary_weapon_id,
		"turret_cooldown": player.turret_cooldown,
		"claymore_charges": player.claymore_charges,
		"c4_charges_remaining": player.c4_charges_remaining,
		"smoke_grenades_count": player.smoke_grenades_count,
		"throwing_knives_count": player.throwing_knives_count,
		"deployable_shields_count": player.deployable_shields_count,
		"medkit_charges": player.medkit_charges,
		"is_carrying_patch_rom": player.is_carrying_patch_rom,
		"weapons": {}
	}
	var health: HealthComponent = player.health_component
	if health != null:
		state["health"] = health.current_health
		state["max_health"] = health.max_health
		state["is_downed"] = health.is_downed
		state["is_dead"] = health.is_dead
		state["is_stunned"] = health.is_stunned
		state["stun_timer"] = health.stun_timer
		state["bleedout_timer"] = health.bleedout_timer
	if player.current_weapon != null:
		state["weapons"][player.current_weapon.weapon_id] = {
			"current_ammo": player.current_weapon.current_ammo,
			"reserve_ammo": player.current_weapon.reserve_ammo,
			"current_heat": player.current_weapon.current_heat,
			"is_overheated": player.current_weapon.is_overheated,
			"is_reloading": player.current_weapon.is_reloading
		}
	for wid: String in player._weapon_inventory:
		var w: WeaponBase = player._weapon_inventory[wid] as WeaponBase
		if is_instance_valid(w) and not state["weapons"].has(wid):
			state["weapons"][wid] = {
				"current_ammo": w.current_ammo,
				"reserve_ammo": w.reserve_ammo,
				"current_heat": w.current_heat,
				"is_overheated": w.is_overheated,
				"is_reloading": w.is_reloading
			}
	return state


## Applies captured state to a newly spawned operative in the destination world.
func apply_state(player: PlayerController3D, state: Dictionary) -> void:
	if state.has("class_id") and player.class_id != state["class_id"]:
		player.class_id = state["class_id"]
	if state.has("player_callsign"):
		player.player_callsign = state["player_callsign"]
	var health: HealthComponent = player.health_component
	if health != null:
		if state.has("max_health"):
			health.max_health = state["max_health"]
		if state.has("health"):
			health.current_health = state["health"]
		if state.get("is_downed", false):
			health.is_downed = true
			health.bleedout_timer = state.get("bleedout_timer", 30.0)
		if state.get("is_stunned", false):
			health.is_stunned = true
			health.stun_timer = state.get("stun_timer", 0.0)
		health.health_changed.emit(health.current_health, health.max_health)
		health._publish_state()
	if state.has("weapons"):
		for wid: String in state["weapons"]:
			var w_data: Dictionary = state["weapons"][wid]
			if not player._weapon_inventory.has(wid):
				player._equip_weapon_by_id(wid)
			var w: WeaponBase = player._weapon_inventory.get(wid) as WeaponBase
			if is_instance_valid(w):
				w.current_ammo = w_data.get("current_ammo", w.current_ammo)
				w.reserve_ammo = w_data.get("reserve_ammo", w.reserve_ammo)
				w.current_heat = w_data.get("current_heat", w.current_heat)
				w.is_overheated = w_data.get("is_overheated", false)
				w.is_reloading = false
	if state.has("active_slot"):
		player._equip_slot_local(state["active_slot"])
	if player.current_weapon != null:
		player.weapon_ammo_changed.emit(player.current_weapon.current_ammo, player.current_weapon.reserve_ammo)
	player._broadcast_weapon_state()
	player.turret_cooldown = state.get("turret_cooldown", 0.0)
	player.claymore_charges = state.get("claymore_charges", player.claymore_charges)
	player.c4_charges_remaining = state.get("c4_charges_remaining", player.c4_charges_remaining)
	player.smoke_grenades_count = state.get("smoke_grenades_count", player.smoke_grenades_count)
	player.throwing_knives_count = state.get("throwing_knives_count", player.throwing_knives_count)
	player.deployable_shields_count = state.get("deployable_shields_count", player.deployable_shields_count)
	player.medkit_charges = state.get("medkit_charges", player.max_medkit_charges() if state.get("class_id", player.class_id) == SGCNetworkManager.CLASS_CARTER_TECH else 0)
	player.is_carrying_patch_rom = state.get("is_carrying_patch_rom", false)


## Moves one operative from its current world to the destination world.
func travel_player(player: PlayerController3D, from_world: Node = null) -> void:
	if result >= 0 or not multiplayer.is_server() or player == null or worlds.size() < 2:
		return
	var peer_id: int = player.peer_id
	if from_world == null:
		from_world = world_of(peer_id)
	var to_world: Node = worlds[1] if from_world == home() else home()
	if to_world == from_world:
		return
	if from_world != home() and to_world == home():
		var site_objectives: Variant = from_world.get(&"objectives")
		if site_objectives != null and not bool(site_objectives.call(&"is_complete")):
			return
	if _traveling.has(peer_id):
		return
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and net.is_in_active_session() and multiplayer == net.multiplayer:
		_traveling[peer_id] = true
		var paused: bool = await net.pause_player_for_transfer(player)
		_traveling.erase(peer_id)
		if not paused or not is_instance_valid(player) or result >= 0:
			return
	if not participants.has(peer_id):
		var label: String = player.player_callsign
		if label == "OPERATIVE" and peer_id != 1:
			label = "OPERATIVE %d" % peer_id
		record_participant(peer_id, player.class_id, label)

	var state: Dictionary = capture_state(player)

	# Despawn from from_world
	var players_container: Node3D = from_world.get("players_container") as Node3D
	if players_container == null or not players_container.has_node(str(peer_id)):
		return
	players_container.remove_child(player)
	player.queue_free()

	# Record new world placement and travel history
	place(peer_id, to_world)
	if to_world != home():
		went_offworld[peer_id] = true
	elif from_world != home():
		returned_home[peer_id] = true

	# Spawn in to_world at its arrival point
	var spawn_pos: Vector3
	if to_world == home() and to_world.has_method(&"return_spawn_position"):
		spawn_pos = to_world.call(&"return_spawn_position", peer_id)
	else:
		var spawns_container: Node3D = to_world.get("spawns_container") as Node3D
		var spawn_points: Array[Node] = spawns_container.get_children() if spawns_container != null else []
		spawn_pos = (spawn_points[0] as Node3D).global_position if not spawn_points.is_empty() else (to_world as Node3D).global_position
	to_world.call(&"_spawn_player", peer_id, state.get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY), spawn_pos)

	var target_players: Node3D = to_world.get("players_container") as Node3D
	if target_players != null:
		var new_player := target_players.get_node_or_null(str(peer_id)) as PlayerController3D
		if new_player != null:
			apply_state(new_player, state)
			if to_world == home():
				new_player.rotation.y = PI

	# Synchronize presentation switch to the travelling client
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id):
		sync_presentation_change.rpc_id(peer_id, worlds.find(to_world))
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == local_id:
		present(to_world)

	player_traveled.emit(peer_id, from_world, to_world)
	evaluate_outcome()


@rpc("authority", "call_local", "reliable")
func sync_presentation_change(world_index: int) -> void:
	if world_index >= 0 and world_index < worlds.size():
		present(worlds[world_index])


func abort_mission() -> void:
	if not multiplayer.is_server():
		return
	finish(false)
