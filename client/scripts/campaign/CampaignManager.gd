class_name SGCCampaignManager
extends Node
## Central manager for multi-stage operational campaigns (Milestones CA-1 & CA-2).
## Tracks active campaign progression, difficulty tier, deterministic run seed,
## operational mutators, stage variants, tactical ratings, career records,
## squad inventory carryover, and host-authoritative persistence (Decision D-007).

signal campaign_started(campaign_id: String)
signal campaign_stage_advanced(stage_index: int, stage_data: Dictionary)
signal campaign_completed_event(summary: Dictionary)
signal campaign_reset_event()
signal campaign_state_synced()

const DEFAULT_SAVE_PATH: String = "user://campaign_save.json"
const DEFAULT_RECORDS_PATH: String = "user://campaign_records.json"
const CANONICAL_CAMPAIGN_PATH: String = "res://resources/campaigns/operation_hatak_strike.tres"

var active_campaign: CampaignDefinition = null
var is_campaign_active: bool = false
var current_stage_index: int = 0
var stage_history: Array[Dictionary] = []
var squad_carryover: Dictionary = {}
var campaign_completed: bool = false

# CA-2 variation, difficulty tiers, and career persistence
var campaign_difficulty: int = SGCNetworkManager.DIFFICULTY_EASY
var run_seed: int = 0
var active_modifiers: Array[String] = []
var stage_variants: Dictionary = {}
var career_records: Dictionary = {}


func _ready() -> void:
	# Connect to peer connection events to sync campaign state to new joiners
	multiplayer.peer_connected.connect(_on_peer_connected)
	load_records()


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and is_campaign_active:
		sync_campaign_state.rpc_id(peer_id, get_state_snapshot())


func sync_to_peer(peer_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and is_campaign_active:
		sync_campaign_state.rpc_id(peer_id, get_state_snapshot())


func _is_client_blocked() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.is_server()


func _roll_run_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(100000, 9999999)


func _rebuild_stage_variants() -> void:
	stage_variants.clear()
	if active_campaign == null:
		return
	for i: int in range(active_campaign.stage_count()):
		var stage: Dictionary = active_campaign.get_stage(i)
		var avail: Array = stage.get("objective_variants", [])
		stage_variants[str(i)] = MissionDifficulty.build_stage_variant(
			run_seed, i, campaign_difficulty, avail
		)


func start_campaign(
	def: CampaignDefinition = null,
	difficulty: int = -1,
	seed_override: int = 0,
	modifiers: Array = []
) -> void:
	if _is_client_blocked():
		push_warning("CampaignManager: Only server can start a campaign.")
		return

	if def == null:
		def = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	if def == null:
		push_error("CampaignManager: Failed to load campaign definition.")
		return

	var errors := def.validate()
	if not errors.is_empty():
		push_error("CampaignManager: Campaign validation failed: %s" % str(errors))
		return

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var resolved_tier: int = campaign_difficulty
	if difficulty >= 0:
		resolved_tier = MissionDifficulty.clamp_tier(difficulty)
	elif net != null:
		resolved_tier = MissionDifficulty.clamp_tier(net.mission_difficulty)
	else:
		resolved_tier = MissionDifficulty.TIER_EASY

	var resolved_seed: int = seed_override
	if resolved_seed <= 0 and net != null and net.run_seed > 0:
		resolved_seed = net.run_seed
	if resolved_seed <= 0:
		resolved_seed = _roll_run_seed()

	var resolved_mods: Array[String] = []
	if not modifiers.is_empty():
		resolved_mods = MissionDifficulty.sanitize_modifiers(modifiers)
	elif net != null and not net.selected_modifiers.is_empty():
		resolved_mods = MissionDifficulty.sanitize_modifiers(net.selected_modifiers)

	active_campaign = def
	is_campaign_active = true
	current_stage_index = 0
	stage_history.clear()
	squad_carryover.clear()
	campaign_completed = false
	campaign_difficulty = resolved_tier
	run_seed = resolved_seed
	active_modifiers = resolved_mods
	_rebuild_stage_variants()

	var current_mission_id := get_current_mission_id()
	if net != null and not current_mission_id.is_empty():
		if not net.mission_started:
			net.set_mission(current_mission_id)
			net.set_mission_difficulty(campaign_difficulty)
			net.set_run_variation(run_seed, active_modifiers)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	campaign_started.emit(active_campaign.campaign_id)
	save_to_disk()
	print("CampaignManager: Started campaign '%s' (%s) [Tier=%s, Seed=%d], stage 0: %s" % [
		active_campaign.campaign_id,
		active_campaign.title,
		MissionDifficulty.tier_name(campaign_difficulty),
		run_seed,
		current_mission_id
	])


func replay_campaign(
	difficulty: int = -1,
	seed_override: int = 0,
	modifiers: Array = []
) -> void:
	if _is_client_blocked():
		push_warning("CampaignManager: Only server can replay a campaign.")
		return
	var next_def: CampaignDefinition = active_campaign
	var target_tier: int = difficulty if difficulty >= 0 else campaign_difficulty
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not net.mission_started:
		net.run_seed = seed_override if seed_override > 0 else 0
	start_campaign(next_def, target_tier, seed_override, modifiers)


func set_campaign_difficulty(tier: int) -> bool:
	if _is_client_blocked():
		return false
	if tier < MissionDifficulty.TIER_EASY or tier > MissionDifficulty.TIER_HARD:
		return false
	campaign_difficulty = tier
	if active_campaign != null and is_campaign_active:
		_rebuild_stage_variants()
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not net.mission_started:
		net.set_mission_difficulty(campaign_difficulty)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	save_to_disk()
	campaign_state_synced.emit()
	return true


func set_campaign_modifiers(modifiers: Array) -> bool:
	if _is_client_blocked():
		return false
	active_modifiers = MissionDifficulty.sanitize_modifiers(modifiers)
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not net.mission_started:
		net.set_run_variation(run_seed, active_modifiers)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	save_to_disk()
	campaign_state_synced.emit()
	return true


func set_run_seed(seed_value: int) -> bool:
	if _is_client_blocked() or seed_value <= 0:
		return false
	run_seed = seed_value
	if active_campaign != null and is_campaign_active:
		_rebuild_stage_variants()
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not net.mission_started:
		net.set_run_variation(run_seed, active_modifiers)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	save_to_disk()
	campaign_state_synced.emit()
	return true


func get_current_stage() -> Dictionary:
	if active_campaign == null or not is_campaign_active:
		return {}
	return active_campaign.get_stage(current_stage_index)


func get_current_mission_id() -> String:
	var stage := get_current_stage()
	return stage.get("mission_id", "")


func get_current_chevron_sequence() -> Array:
	var stage := get_current_stage()
	return stage.get("chevron_sequence", [])


func get_stage_variant(index: int = -1) -> Dictionary:
	var idx: int = current_stage_index if index < 0 else index
	var key: String = str(idx)
	if stage_variants.has(key) and stage_variants[key] is Dictionary:
		return stage_variants[key] as Dictionary
	return {}


func record_stage_completion(debrief: Dictionary, victory: bool, captured_states: Dictionary) -> void:
	if _is_client_blocked():
		return
	if not is_campaign_active or active_campaign == null:
		return

	var current_stage := get_current_stage()
	var stealth_str: String = str(debrief.get("stealth", ""))
	if stealth_str.is_empty():
		var status_str: String = str(debrief.get("status", ""))
		if "ALARM RAISED" in status_str:
			stealth_str = "ALARM RAISED"
		elif "SPOTTED" in status_str:
			stealth_str = "SPOTTED, NO ALARM"
		else:
			stealth_str = "UNDETECTED"
	var lost_count: int = int(debrief.get("lost_count", 0))
	var stage_rating: String = str(debrief.get("rating", ""))
	if stage_rating.is_empty():
		stage_rating = MissionDifficulty.compute_stage_rating(
			victory, stealth_str, lost_count, campaign_difficulty, active_modifiers
		)

	var record := {
		"stage_index": current_stage_index,
		"stage_id": current_stage.get("stage_id", ""),
		"stage_title": current_stage.get("stage_title", ""),
		"mission_id": current_stage.get("mission_id", ""),
		"victory": victory,
		"difficulty": campaign_difficulty,
		"rating": stage_rating,
		"variant": get_stage_variant(current_stage_index),
		"debrief": debrief,
		"timestamp": Time.get_unix_time_from_system()
	}
	stage_history.append(record)

	if victory:
		squad_carryover = captured_states.duplicate(true)
		if current_stage_index + 1 >= active_campaign.stage_count():
			campaign_completed = true
			var summary := get_campaign_summary()
			_record_career_completion(summary)
			save_records()
			campaign_completed_event.emit(summary)
			print("CampaignManager: CAMPAIGN COMPLETED! Rating %s, all %d stages successful." % [
				str(summary.get("rating", "A")), active_campaign.stage_count()
			])

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	save_to_disk()


func advance_to_next_stage() -> bool:
	if _is_client_blocked():
		push_warning("CampaignManager: Only server can advance campaign stage.")
		return false
	if not is_campaign_active or active_campaign == null or campaign_completed:
		return false

	if current_stage_index + 1 >= active_campaign.stage_count():
		return false

	current_stage_index += 1
	var next_stage := get_current_stage()
	var next_mission_id := str(next_stage.get("mission_id", ""))

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not next_mission_id.is_empty():
		net.set_mission(next_mission_id)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())

	campaign_stage_advanced.emit(current_stage_index, next_stage)
	save_to_disk()
	print("CampaignManager: Advanced to stage %d: %s (%s)" % [
		current_stage_index, next_stage.get("stage_title", ""), next_mission_id
	])
	return true


func reset_campaign() -> void:
	if _is_client_blocked():
		return

	is_campaign_active = false
	current_stage_index = 0
	stage_history.clear()
	squad_carryover.clear()
	campaign_completed = false
	active_campaign = null
	campaign_difficulty = SGCNetworkManager.DIFFICULTY_EASY
	run_seed = 0
	active_modifiers.clear()
	stage_variants.clear()

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	campaign_reset_event.emit()

	# Remove active run save on disk while keeping career_records intact
	if FileAccess.file_exists(DEFAULT_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEFAULT_SAVE_PATH))
	print("CampaignManager: Campaign reset cleanly.")


func has_carryover(peer_id: int) -> bool:
	return squad_carryover.has(peer_id) or squad_carryover.has(str(peer_id))


func get_carryover(peer_id: int) -> Dictionary:
	if squad_carryover.has(peer_id):
		return squad_carryover[peer_id]
	if squad_carryover.has(str(peer_id)):
		return squad_carryover[str(peer_id)]
	return {}


func apply_carryover(player: PlayerController3D) -> bool:
	if not is_instance_valid(player):
		return false
	var state := get_carryover(player.peer_id)
	if state.is_empty():
		return false

	# Apply weapons and reserve counts
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

	# Apply health, preserving partial damage down to difficulty/mutator survival floor
	var min_hp: float = MissionDifficulty.carryover_min_health(campaign_difficulty, active_modifiers)
	var health: HealthComponent = player.health_component
	if health != null:
		if state.has("max_health"):
			health.max_health = state["max_health"]
		if state.has("health"):
			health.current_health = maxf(min_hp, float(state["health"]))
		health.is_downed = false
		health.is_dead = false
		health.is_stunned = false
		health.health_changed.emit(health.current_health, health.max_health)
		health._publish_state()

	# Apply tactical supplies
	player.turret_cooldown = state.get("turret_cooldown", 0.0)
	player.claymore_charges = state.get("claymore_charges", player.claymore_charges)
	player.c4_charges_remaining = state.get("c4_charges_remaining", player.c4_charges_remaining)
	player.smoke_grenades_count = state.get("smoke_grenades_count", player.smoke_grenades_count)
	player.deployable_shields_count = state.get("deployable_shields_count", player.deployable_shields_count)
	return true


func get_campaign_summary() -> Dictionary:
	var total_kills := 0
	var total_duration := 0
	var stages_won := 0
	for record: Dictionary in stage_history:
		if record.get("victory", false):
			stages_won += 1
		var debrief: Dictionary = record.get("debrief", {})
		total_kills += int(debrief.get("kill_count", 0))
		total_duration += int(debrief.get("duration_seconds", 0))

	var rating_data: Dictionary = MissionDifficulty.compute_campaign_rating(
		stage_history, campaign_difficulty, active_modifiers
	)

	return {
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"title": active_campaign.title if active_campaign != null else "",
		"total_stages": active_campaign.stage_count() if active_campaign != null else 0,
		"stages_won": stages_won,
		"completed": campaign_completed,
		"total_kills": total_kills,
		"total_duration_seconds": total_duration,
		"difficulty": campaign_difficulty,
		"difficulty_name": MissionDifficulty.tier_name(campaign_difficulty),
		"run_seed": run_seed,
		"active_modifiers": active_modifiers.duplicate(),
		"stage_variants": stage_variants.duplicate(true),
		"rating": str(rating_data.get("rating", "C")),
		"honors": rating_data.get("honors", []),
		"stage_history": stage_history
	}


func get_state_snapshot() -> Dictionary:
	return {
		"is_campaign_active": is_campaign_active,
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"current_stage_index": current_stage_index,
		"campaign_completed": campaign_completed,
		"campaign_difficulty": campaign_difficulty,
		"run_seed": run_seed,
		"active_modifiers": active_modifiers.duplicate(),
		"stage_variants": stage_variants.duplicate(true),
		"stage_history": stage_history.duplicate(true),
		"squad_carryover": squad_carryover.duplicate(true)
	}


@rpc("authority", "call_local", "reliable")
func sync_campaign_state(state: Dictionary) -> void:
	var incoming_history: Array = (state.get("stage_history", []) as Array).duplicate(true)
	var raw_carryover: Variant = state.get("squad_carryover", {})
	var incoming_carryover: Dictionary = (raw_carryover as Dictionary).duplicate(true) if raw_carryover is Dictionary else {}
	var raw_variants: Variant = state.get("stage_variants", {})
	var incoming_variants: Dictionary = (raw_variants as Dictionary).duplicate(true) if raw_variants is Dictionary else {}

	is_campaign_active = bool(state.get("is_campaign_active", false))
	current_stage_index = int(state.get("current_stage_index", 0))
	campaign_completed = bool(state.get("campaign_completed", false))
	campaign_difficulty = MissionDifficulty.clamp_tier(int(state.get("campaign_difficulty", SGCNetworkManager.DIFFICULTY_EASY)))
	run_seed = int(state.get("run_seed", 0))
	active_modifiers = MissionDifficulty.sanitize_modifiers(state.get("active_modifiers", []))
	stage_variants = incoming_variants
	stage_history.clear()
	for record: Variant in incoming_history:
		if record is Dictionary:
			stage_history.append(record)
	squad_carryover = incoming_carryover

	var cid: String = state.get("campaign_id", "")
	if not cid.is_empty():
		if active_campaign == null or active_campaign.campaign_id != cid:
			if cid == "operation_hatak_strike":
				active_campaign = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	else:
		active_campaign = null

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and is_campaign_active:
		net.mission_difficulty = campaign_difficulty
		net.run_seed = run_seed
		net.selected_modifiers = active_modifiers.duplicate()
		net.mission_settings_changed.emit(campaign_difficulty)
		net.run_variation_changed.emit(run_seed, PackedStringArray(active_modifiers))

	campaign_state_synced.emit()


func save_to_disk(path: String = DEFAULT_SAVE_PATH) -> bool:
	var data := {
		"version": 2,
		"is_campaign_active": is_campaign_active,
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"current_stage_index": current_stage_index,
		"campaign_completed": campaign_completed,
		"campaign_difficulty": campaign_difficulty,
		"run_seed": run_seed,
		"active_modifiers": active_modifiers,
		"stage_variants": stage_variants,
		"stage_history": stage_history,
		"squad_carryover": squad_carryover
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("CampaignManager: Could not open %s for saving: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var json_str := JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()
	return true


func load_from_disk(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_warning("CampaignManager: Failed to parse campaign save from %s." % path)
		return false

	var data: Dictionary = json.data as Dictionary
	if data == null or not data.has("is_campaign_active"):
		return false

	is_campaign_active = bool(data.get("is_campaign_active", false))
	current_stage_index = int(data.get("current_stage_index", 0))
	campaign_completed = bool(data.get("campaign_completed", false))
	campaign_difficulty = MissionDifficulty.clamp_tier(int(data.get("campaign_difficulty", SGCNetworkManager.DIFFICULTY_EASY)))
	run_seed = int(data.get("run_seed", 0))
	active_modifiers = MissionDifficulty.sanitize_modifiers(data.get("active_modifiers", []))
	var raw_variants: Variant = data.get("stage_variants", {})
	stage_variants = (raw_variants as Dictionary).duplicate(true) if raw_variants is Dictionary else {}
	stage_history.clear()
	for record: Variant in data.get("stage_history", []):
		if record is Dictionary:
			stage_history.append(record)
	squad_carryover = data.get("squad_carryover", {})

	var cid: String = data.get("campaign_id", "")
	if not cid.is_empty():
		if cid == "operation_hatak_strike":
			active_campaign = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	else:
		active_campaign = null

	if is_campaign_active and active_campaign != null and stage_variants.is_empty() and run_seed > 0:
		_rebuild_stage_variants()

	if is_campaign_active and active_campaign != null:
		var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
		var cur_mission := get_current_mission_id()
		if net != null and not cur_mission.is_empty() and not net.mission_started:
			net.set_mission(cur_mission)
			net.set_mission_difficulty(campaign_difficulty)
			net.set_run_variation(run_seed, active_modifiers)

	campaign_state_synced.emit()
	print("CampaignManager: Loaded campaign save from %s (stage %d, tier %s)." % [
		path, current_stage_index, MissionDifficulty.tier_name(campaign_difficulty)
	])
	return true


func _record_career_completion(summary: Dictionary) -> void:
	var cid: String = str(summary.get("campaign_id", "operation_hatak_strike"))
	var completions: int = int(career_records.get("total_completions", 0)) + 1
	var rating: String = str(summary.get("rating", "C"))
	var prev_best_rating: String = str(career_records.get("best_rating", ""))
	var best_rating: String = rating
	if not prev_best_rating.is_empty() and MissionDifficulty.rating_rank(prev_best_rating) > MissionDifficulty.rating_rank(rating):
		best_rating = prev_best_rating

	var tier: int = int(summary.get("difficulty", campaign_difficulty))
	var highest_diff: int = maxi(int(career_records.get("highest_difficulty", -1)), tier)
	var duration_s: int = int(summary.get("total_duration_seconds", 0))
	var prev_fastest: int = int(career_records.get("fastest_clear_seconds", 0))
	var fastest_clear: int = duration_s if prev_fastest <= 0 else mini(prev_fastest, duration_s)

	var history: Array = []
	if career_records.get("recent_runs") is Array:
		history = (career_records["recent_runs"] as Array).duplicate(true)
	history.append({
		"campaign_id": cid,
		"difficulty": tier,
		"difficulty_name": MissionDifficulty.tier_name(tier),
		"run_seed": int(summary.get("run_seed", run_seed)),
		"modifiers": summary.get("active_modifiers", []),
		"rating": rating,
		"honors": summary.get("honors", []),
		"total_kills": int(summary.get("total_kills", 0)),
		"total_duration_seconds": duration_s,
		"timestamp": Time.get_unix_time_from_system()
	})
	while history.size() > 10:
		history.pop_front()

	career_records = {
		"version": 1,
		"total_completions": completions,
		"best_rating": best_rating,
		"highest_difficulty": highest_diff,
		"highest_difficulty_name": MissionDifficulty.tier_name(highest_diff),
		"fastest_clear_seconds": fastest_clear,
		"last_rating": rating,
		"last_honors": summary.get("honors", []),
		"recent_runs": history
	}


func get_career_records() -> Dictionary:
	return career_records.duplicate(true)


func save_records(path: String = DEFAULT_RECORDS_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(career_records, "\t"))
	file.close()
	return true


func load_records(path: String = DEFAULT_RECORDS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		return false
	if not (json.data is Dictionary):
		return false
	career_records = (json.data as Dictionary).duplicate(true)
	return true


func clear_records(path: String = DEFAULT_RECORDS_PATH) -> void:
	career_records.clear()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
