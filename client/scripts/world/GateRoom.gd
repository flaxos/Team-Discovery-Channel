class_name GateRoom
extends Node3D
## SGC Level 28 Gate Room Arena & Stargate Ramp.
## Coordinates player spawning via MultiplayerSpawner, dedicated server pawnless host,
## mid-mission operative joins, defensive sandbags, gate status, and emergency alert lighting.

const PLAYER_SCENE_PATH: String = "res://scenes/entities/Player.tscn"
const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")
const LabDataPatchDriveScript = preload("res://scripts/props/LabDataPatchDrive.gd")

# Sector identifiers for SGC Sublevels 28 & 27
const SECTOR_GATE_ROOM: String = "GATE_ROOM"
const SECTOR_CONTROL_ROOM: String = "CONTROL_ROOM"
const SECTOR_FALLBACK_HALLWAY: String = "FALLBACK_HALLWAY"
const SECTOR_CONNECTOR_TUNNEL: String = "CONNECTOR_TUNNEL"
const SECTOR_ROUND_HALLWAY: String = "ROUND_HALLWAY"
const SECTOR_ARMORY: String = "ARMORY"
const SECTOR_LABORATORY: String = "LABORATORY"
const SECTOR_ELEVATOR_LOBBY: String = "ELEVATOR_LOBBY"
const SECTOR_EAST_CORRIDOR: String = "EAST_CORRIDOR"
const SECTOR_WEST_CORRIDOR: String = "WEST_CORRIDOR"

# Sublevel 27 Sectors
const SECTOR_BRIEFING_ROOM: String = "BRIEFING_ROOM"
const SECTOR_GENERALS_OFFICE: String = "GENERALS_OFFICE"
const SECTOR_SECURITY_STATION: String = "SECURITY_STATION"
const SECTOR_UPPER_CORRIDOR: String = "UPPER_CORRIDOR"
const SECTOR_UPPER_ELEVATOR_LOBBY: String = "UPPER_ELEVATOR_LOBBY"

const SECTOR_UNKNOWN: String = "UNKNOWN"

@onready var players_container: Node3D = $Players
@onready var spawns_container: Node3D = $Spawns
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var stargate_mesh: StargateRing = $Stargate as StargateRing if has_node("Stargate") else null
@onready var event_horizon: MeshInstance3D = $Stargate/EventHorizon if has_node("Stargate/EventHorizon") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null
@onready var dialing_console: DHDDialer = _find_dialing_console()
@onready var hud: TacticalHUD = $TacticalHUD if has_node("TacticalHUD") else null
@onready var door_left: CSGBox3D = $BlastDoors/BlastDoorLeft if has_node("BlastDoors/BlastDoorLeft") else null
@onready var door_right: CSGBox3D = $BlastDoors/BlastDoorRight if has_node("BlastDoors/BlastDoorRight") else null
@onready var console_light: OmniLight3D = $BlastDoors/BlastDoorConsole/ConsoleLight if has_node("BlastDoors/BlastDoorConsole/ConsoleLight") else null
@onready var emergency_lights_container: Node3D = $EmergencyLights if has_node("EmergencyLights") else null
@onready var allies_container: Node3D = $Allies if has_node("Allies") else null

var dhd_console: DHDDialer:
	get:
		if dialing_console == null or not is_instance_valid(dialing_console):
			dialing_console = _find_dialing_console()
		return dialing_console
	set(v):
		dialing_console = v

var keybindings_modal: KeybindingsModal:
	get:
		if hud != null:
			return hud.keybindings_modal
		return null


func toggle_keybindings_modal() -> void:
	if hud != null:
		hud.toggle_keybindings_modal()

var is_blast_doors_closed: bool = false
var is_animating_doors: bool = false
var is_control_window_closed: bool = false
var is_control_window_animating: bool = false
var is_observation_shutters_closed: bool = false
var is_animating_observation_shutters: bool = false
var is_emergency_active: bool = false
var emergency_strobe_timer: float = 0.0
var player_sectors: Dictionary = {}
@export var mission_id: String = SGCNetworkManager.MISSION_SGC_DEFENSE
var mission_result: int = -1
var visited_sectors: Dictionary = {}

var neutralized_players: Dictionary = {}
var sector_shrouds: Dictionary = {}
var shroud_mat_opaque: StandardMaterial3D = null
var shroud_mat_adjacent: StandardMaterial3D = null
var shroud_mat_visited: StandardMaterial3D = null

var sector_adjacency: Dictionary = {
	SECTOR_GATE_ROOM: [SECTOR_EAST_CORRIDOR, SECTOR_WEST_CORRIDOR, SECTOR_CONTROL_ROOM, SECTOR_BRIEFING_ROOM],
	SECTOR_CONTROL_ROOM: [SECTOR_GATE_ROOM, SECTOR_FALLBACK_HALLWAY, SECTOR_ELEVATOR_LOBBY],
	SECTOR_FALLBACK_HALLWAY: [SECTOR_CONTROL_ROOM, SECTOR_CONNECTOR_TUNNEL],
	SECTOR_CONNECTOR_TUNNEL: [SECTOR_FALLBACK_HALLWAY, SECTOR_ROUND_HALLWAY],
	SECTOR_ROUND_HALLWAY: [SECTOR_ARMORY, SECTOR_CONNECTOR_TUNNEL, SECTOR_ELEVATOR_LOBBY, SECTOR_LABORATORY],
	SECTOR_ARMORY: [SECTOR_ROUND_HALLWAY],
	SECTOR_ELEVATOR_LOBBY: [SECTOR_EAST_CORRIDOR, SECTOR_ROUND_HALLWAY, SECTOR_CONTROL_ROOM, SECTOR_UPPER_ELEVATOR_LOBBY],
	SECTOR_EAST_CORRIDOR: [SECTOR_GATE_ROOM, SECTOR_ELEVATOR_LOBBY],
	SECTOR_WEST_CORRIDOR: [SECTOR_GATE_ROOM],
	SECTOR_LABORATORY: [SECTOR_ROUND_HALLWAY],
	SECTOR_BRIEFING_ROOM: [SECTOR_GATE_ROOM, SECTOR_GENERALS_OFFICE, SECTOR_SECURITY_STATION, SECTOR_UPPER_CORRIDOR],
	SECTOR_GENERALS_OFFICE: [SECTOR_BRIEFING_ROOM],
	SECTOR_SECURITY_STATION: [SECTOR_BRIEFING_ROOM],
	SECTOR_UPPER_CORRIDOR: [SECTOR_BRIEFING_ROOM, SECTOR_UPPER_ELEVATOR_LOBBY],
	SECTOR_UPPER_ELEVATOR_LOBBY: [SECTOR_UPPER_CORRIDOR, SECTOR_ELEVATOR_LOBBY]
}

signal blast_doors_toggled(closed: bool)
signal observation_shutters_toggled(closed: bool)
signal control_window_toggled(closed: bool)
signal sector_changed(player_id: int, old_sector: String, new_sector: String)


func _find_dialing_console() -> DHDDialer:
	var console := find_child("SGCDialingConsole", true, false) as DHDDialer
	if console == null:
		console = find_child("DHDConsole", true, false) as DHDDialer
	return console


func _ready() -> void:
	# Configure spawner
	if spawner != null:
		spawner.spawn_path = NodePath("../Players")
		if spawner.get_spawnable_scene_count() == 0:
			spawner.add_spawnable_scene(PLAYER_SCENE_PATH)

	# Connect players container to bind HUD
	if players_container != null:
		players_container.child_entered_tree.connect(_on_player_child_entered)
		for existing_p: Node in players_container.get_children():
			_on_player_child_entered(existing_p)

	# Connect WaveManager and DHD to HUD and emergency lighting
	if wave_manager != null:
		wave_manager.wave_started.connect(func(w: int, c: int) -> void:
			if hud != null:
				hud.on_wave_started(w, c)
			set_emergency_lights(true)
		)
		wave_manager.jaffa_count_changed.connect(func(rem: int, cur: int) -> void:
			if hud != null:
				hud.on_jaffa_count_changed(rem, cur)
		)
		wave_manager.wave_cleared.connect(func(w: int) -> void:
			if hud != null:
				hud.on_wave_cleared(w, wave_manager.inter_gate_recharge_s)
		)
		wave_manager.all_waves_defeated.connect(func() -> void:
			if hud != null:
				hud.on_all_waves_defeated()
			set_emergency_lights(false)
		)
		wave_manager.wormhole_timer_tick.connect(func(left: float, total: float) -> void:
			if hud != null:
				hud.on_wormhole_timer_tick(left, total)
		)
		wave_manager.intermission_tick.connect(func(sec: int) -> void:
			if hud != null:
				hud.on_intermission_tick(sec)
		)
		wave_manager.iris_malfunction_declared.connect(func() -> void:
			if hud != null:
				hud.on_iris_malfunction()
		)
		wave_manager.objective_status_changed.connect(func(text: String) -> void:
			if hud != null:
				hud.update_objective(text)
		)
		wave_manager.lab_patch_objective_started.connect(func() -> void:
			if hud != null:
				hud.on_lab_patch_objective_started()
		)

	if dialing_console != null and hud != null:
		hud.bind_dhd(dialing_console)

	var iris_servo := find_child("IrisServoHousing", true, false) as IrisServoHousingScript
	if iris_servo != null and hud != null:
		iris_servo.stage_completed.connect(func(stg: int, sname: String) -> void:
			hud.update_iris_repair_stage(stg, sname, float(stg) / 3.0)
		)

	if stargate_mesh != null:
		stargate_mesh.player_extracted.connect(_on_player_extracted)

	var map := get_node_or_null("SGCMap") as SGCMap
	if map != null:
		sector_adjacency.clear()
		for c in map.definition.connections:
			if not sector_adjacency.has(str(c.from_region)): sector_adjacency[str(c.from_region)] = []
			if not sector_adjacency.has(str(c.to_region)): sector_adjacency[str(c.to_region)] = []
			sector_adjacency[str(c.from_region)].append(str(c.to_region))
			sector_adjacency[str(c.to_region)].append(str(c.from_region))
	_setup_sector_shrouds()
	if mission_id == SGCNetworkManager.MISSION_SGC_UAT and hud != null:
		hud.update_objective("UAT BASE: EXPLORE SUBLEVELS 28 / 27 / 26 — NO HOSTILE ACTIVATION", Color(0.4, 0.9, 1.0))
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_room_snapshot.rpc_id(1)

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	# If host / server in an active game session, spawn all registered players and start waves
	if net != null and net.is_server:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		net.mission_peer_ready.connect(_on_peer_connected_during_mission)
		_spawn_all_players()

		# If dedicated server without clients yet, wait for first client before starting foothold defense
		if not net.is_dedicated_server:
			_start_foothold_defense()


func _process(delta: float) -> void:
	if is_emergency_active and emergency_lights_container != null:
		emergency_strobe_timer += delta * 4.5
		var strobe_energy: float = (sin(emergency_strobe_timer) * 0.5 + 0.5) * 2.5 + 0.4
		for light in emergency_lights_container.get_children():
			var omni := light as OmniLight3D
			if omni != null:
				omni.light_energy = strobe_energy

	# Operative sector tracking
	if players_container != null:
		for p in players_container.get_children():
			var player := p as PlayerController3D
			if player != null:
				var pid: int = player.name.to_int()
				if pid == 0 and player.name == "1":
					pid = 1
				var cur_sec: String = get_current_sector(player.global_position)
				var prev_sec: String = player_sectors.get(pid, "")
				if cur_sec != prev_sec:
					player_sectors[pid] = cur_sec
					if cur_sec != SECTOR_UNKNOWN:
						visited_sectors[cur_sec] = true
					sector_changed.emit(pid, prev_sec, cur_sec)
					print("GateRoom: Operative %s entered sector: %s" % [player.name, cur_sec])
					if hud != null:
						var local_id := 1
						if multiplayer != null and multiplayer.has_multiplayer_peer():
							local_id = multiplayer.get_unique_id()
						if player.name == str(local_id) or (local_id == 1 and player.name == "1"):
							hud.update_sector_display(cur_sec)

	# Update sector shrouds and fog-of-war culling for local operative
	var local_pid := 1
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		local_pid = multiplayer.get_unique_id()
	var local_sector: String = player_sectors.get(local_pid, "")
	if local_sector.is_empty():
		if players_container != null and players_container.get_child_count() > 0:
			var local_player := players_container.get_child(0) as CharacterBody3D
			if local_player != null:
				local_sector = get_current_sector(local_player.global_position)
		if local_sector.is_empty():
			local_sector = SECTOR_GATE_ROOM
	_update_sector_shrouding(local_sector)


func _setup_sector_shrouds() -> void:
	var shroud_container := Node3D.new()
	shroud_container.name = "SectorShrouds"
	add_child(shroud_container)

	# 1. Fully occluded / deep fog of war material for unvisited distant rooms (Alpha 1.0)
	shroud_mat_opaque = StandardMaterial3D.new()
	shroud_mat_opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	shroud_mat_opaque.albedo_color = Color(0.04, 0.05, 0.06, 1.0)
	shroud_mat_opaque.roughness = 0.95
	shroud_mat_opaque.metallic = 0.2
	shroud_mat_opaque.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# 2. Known / previously visited room material: shows opaque hallway / room structure but conceals contents (Alpha 1.0)
	shroud_mat_visited = StandardMaterial3D.new()
	shroud_mat_visited.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	shroud_mat_visited.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	shroud_mat_visited.roughness = 0.85
	shroud_mat_visited.metallic = 0.25
	shroud_mat_visited.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# 3. Adjacent room material: subtle ambient lighting with low-opacity structural silhouette (Alpha 0.90)
	shroud_mat_adjacent = StandardMaterial3D.new()
	shroud_mat_adjacent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shroud_mat_adjacent.albedo_color = Color(0.11, 0.13, 0.17, 0.90)
	shroud_mat_adjacent.roughness = 0.85
	shroud_mat_adjacent.metallic = 0.2
	shroud_mat_adjacent.emission_enabled = true
	shroud_mat_adjacent.emission = Color(0.03, 0.05, 0.08)
	shroud_mat_adjacent.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Level 28 sector bounding shroud caps at ceiling height Y = 5.8m
	var shroud_defs: Dictionary = {
		SECTOR_GATE_ROOM: {"pos": Vector3(0.0, 5.8, -7.0), "size": Vector3(37.0, 0.2, 30.0)},
		SECTOR_CONTROL_ROOM: {"pos": Vector3(0.0, 5.8, 15.0), "size": Vector3(14.0, 0.2, 14.0)},
		SECTOR_ARMORY: {"pos": Vector3(44.0, 5.8, 36.0), "size": Vector3(18.0, 0.2, 16.0)},
		SECTOR_LABORATORY: {"pos": Vector3(26.0, 5.8, 55.0), "size": Vector3(18.0, 0.2, 20.0)},
		SECTOR_ELEVATOR_LOBBY: {"pos": Vector3(26.0, 5.8, 18.75), "size": Vector3(18.0, 0.2, 17.5)},
		SECTOR_ROUND_HALLWAY: {"pos": Vector3(26.0, 5.8, 36.0), "size": Vector3(18.0, 0.2, 18.0)},
		SECTOR_CONNECTOR_TUNNEL: {"pos": Vector3(11.5, 5.8, 36.0), "size": Vector3(13.0, 0.2, 6.0)},
		SECTOR_FALLBACK_HALLWAY: {"pos": Vector3(0.0, 5.8, 32.0), "size": Vector3(10.0, 0.2, 20.0)},
		SECTOR_EAST_CORRIDOR: {"pos": Vector3(22.5, 5.8, 6.0), "size": Vector3(9.0, 0.2, 12.0)},
		SECTOR_WEST_CORRIDOR: {"pos": Vector3(-23.0, 5.8, 4.0), "size": Vector3(10.0, 0.2, 12.0)}
	}

	for sec_id: String in shroud_defs:
		var data: Dictionary = shroud_defs[sec_id]
		var shroud := MeshInstance3D.new()
		shroud.name = "Shroud_" + sec_id
		var box := BoxMesh.new()
		box.size = data["size"]
		shroud.mesh = box
		shroud.material_override = shroud_mat_opaque
		shroud.position = data["pos"]
		shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shroud_container.add_child(shroud)
		sector_shrouds[sec_id] = shroud

		# Control room has an attached connector corridor to Elevator Lobby (X: 7 to 17, Z: 12 to 18)
		if sec_id == SECTOR_CONTROL_ROOM:
			var sub_shroud := MeshInstance3D.new()
			sub_shroud.name = "SubShroud_ControlConnector"
			var sub_box := BoxMesh.new()
			sub_box.size = Vector3(10.0, 0.2, 6.0)
			sub_shroud.mesh = sub_box
			sub_shroud.material_override = shroud_mat_opaque
			sub_shroud.position = Vector3(12.0, 0.0, 0.0) # Relative to shroud (0, 5.8, 15) -> world (12, 5.8, 15)
			sub_shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shroud.add_child(sub_shroud)


func _update_sector_shrouding(local_sec: String) -> void:
	if sector_shrouds.is_empty():
		return

	if local_sec != SECTOR_UNKNOWN and not visited_sectors.has(local_sec):
		visited_sectors[local_sec] = true

	var adj: Array = sector_adjacency.get(local_sec, [])
	var upstairs: bool = false
	if players_container != null:
		for body: Node in players_container.get_children():
			var operative := body as PlayerController3D
			if operative != null and operative.is_local_authority and operative.global_position.y >= 4.5:
				upstairs = true
				break

	# Shroud management:
	# - Current room: shroud hidden (fully clear and visible to operative).
	# - Adjacent rooms: visible shroud with subtle structural silhouette (alpha ~0.90) and ambient emission.
	# - Other rooms: visible shroud, fully opaque (alpha 1.0) showing structure of known hallways, hiding contents.
	for sec_id: String in sector_shrouds:
		var shroud := sector_shrouds[sec_id] as MeshInstance3D
		if shroud == null:
			continue

		# Lower-level fog caps sit at Y=5.8; hide them from upstairs without revealing enemy entities.
		if upstairs or sec_id == local_sec:
			shroud.visible = false
		elif sec_id in adj:
			shroud.visible = true
			shroud.material_override = shroud_mat_adjacent
		elif visited_sectors.has(sec_id):
			shroud.visible = true
			shroud.material_override = shroud_mat_visited
		else:
			shroud.visible = true
			shroud.material_override = shroud_mat_opaque

		for child in shroud.get_children():
			var sub_shroud := child as MeshInstance3D
			if sub_shroud != null:
				sub_shroud.material_override = shroud.material_override

	# Dynamic Fog of War: cull enemies and pickups in non-current / non-visited sectors
	var local_pid := 1
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		local_pid = multiplayer.get_unique_id()

	var local_player: CharacterBody3D = null
	if players_container != null:
		var target_node := players_container.get_node_or_null(str(local_pid)) as CharacterBody3D
		if target_node != null:
			local_player = target_node
		elif players_container.get_child_count() > 0:
			local_player = players_container.get_child(0) as CharacterBody3D

	var enemies := get_node_or_null("Enemies") as Node3D
	if enemies != null:
		for child in enemies.get_children():
			var jaffa := child as JaffaAI
			if jaffa != null and is_instance_valid(jaffa):
				var jaffa_sec := get_current_sector(jaffa.global_position)
				if jaffa_sec == local_sec:
					jaffa.visible = true
				elif jaffa_sec in adj and local_player != null:
					# Only visible if operative has direct line of sight through open doorway
					jaffa.visible = jaffa._has_line_of_sight(local_player)
				else:
					# Non-adjacent / shrouded room: cull hostile entity
					jaffa.visible = false
			elif child is Node3D and is_instance_valid(child):
				var enemy_node := child as Node3D
				var e_sec := get_current_sector(enemy_node.global_position)
				enemy_node.visible = (e_sec == local_sec)

	# Dynamic Fog of War: cull objective pickups in shrouded / unvisited sectors
	var lab_patch := find_child("LabDataPatchDrive", true, false) as LabDataPatchDriveScript
	if lab_patch != null and is_instance_valid(lab_patch) and not lab_patch.is_retrieved:
		var patch_sec := get_current_sector(lab_patch.global_position)
		if patch_sec == local_sec:
			lab_patch.visible = true
		elif patch_sec in adj and local_player != null:
			var space_state := get_world_3d().direct_space_state if get_world_3d() != null else null
			if space_state != null:
				var query := PhysicsRayQueryParameters3D.create(local_player.global_position + Vector3(0, 1.2, 0), lab_patch.global_position + Vector3(0, 0.5, 0))
				query.collision_mask = 1
				var hit := space_state.intersect_ray(query)
				lab_patch.visible = hit.is_empty()
			else:
				lab_patch.visible = false
		else:
			lab_patch.visible = false

	# Cull generic pickup items in non-current sectors
	var tree := get_tree()
	if tree != null:
		for p_item in tree.get_nodes_in_group("pickups"):
			var p_node := p_item as Node3D
			if p_node != null and is_instance_valid(p_node):
				var p_sec := get_current_sector(p_node.global_position)
				p_node.visible = (p_sec == local_sec)


func get_current_sector(pos: Vector3) -> String:
	var map := get_node_or_null("SGCMap") as SGCMap
	if map != null:
		var sector := map.definition.region_at(pos)
		if sector != &"": return str(sector)
	# ==========================================
	# SUBLEVEL 27 SECTORS (Y >= 4.5m)
	# ==========================================
	if pos.y >= 4.5:
		# General Hammond's Office (X: 7.0 to 19.5, Z: 7.5 to 22.5)
		if pos.x >= 7.0 and pos.x <= 19.5 and pos.z >= 7.5 and pos.z <= 22.5:
			return SECTOR_GENERALS_OFFICE

		# Briefing Room & Gate Overlook (X: -7.5 to 7.0, Z: 7.5 to 22.5)
		if pos.x >= -7.5 and pos.x <= 7.0 and pos.z >= 7.5 and pos.z <= 22.5:
			return SECTOR_BRIEFING_ROOM

		# Security Operations Station (X: -19.5 to -7.5, Z: 7.5 to 22.5)
		if pos.x >= -19.5 and pos.x <= -7.5 and pos.z >= 7.5 and pos.z <= 22.5:
			return SECTOR_SECURITY_STATION

		# Upper Secure Corridor (X: 19.5 to 27.0, Z: 10.0 to 20.0)
		if pos.x >= 19.5 and pos.x <= 27.0 and pos.z >= 10.0 and pos.z <= 20.0:
			return SECTOR_UPPER_CORRIDOR

		# Level 27 Upper Elevator Lobby (X: 26.0 to 39.0, Z: 9.0 to 27.0)
		if pos.x >= 26.0 and pos.x <= 39.0 and pos.z >= 9.0 and pos.z <= 27.0:
			return SECTOR_UPPER_ELEVATOR_LOBBY

		return "LEVEL_27_MEZZANINE"

	# ==========================================
	# SUBLEVEL 28 SECTORS (Y < 4.5m)
	# ==========================================
	# Priority 1: Control Room (directly facing gate, Sublevel 28)
	if pos.x >= -7.5 and pos.x <= 7.5 and pos.z >= 7.8 and pos.z <= 22.0:
		return SECTOR_CONTROL_ROOM

	# Priority 2: Armory (X: 35 to 55, Z: 24 to 45)
	if pos.x >= 35.0 and pos.x <= 55.0 and pos.z >= 24.0 and pos.z <= 45.0:
		return SECTOR_ARMORY

	# Priority 3: Laboratory (X: 17 to 40, Z: 45 to 66)
	if pos.x >= 17.0 and pos.x <= 40.0 and pos.z >= 45.0 and pos.z <= 66.0:
		return SECTOR_LABORATORY

	# Priority 4: East Defense Corridor (X: 17.5 to 27.5, Z: 0.0 to 10.0)
	if pos.x >= 17.5 and pos.x <= 27.5 and pos.z >= 0.0 and pos.z <= 10.0:
		return SECTOR_EAST_CORRIDOR

	# Priority 4b: West Defense Corridor (X: -28.5 to -17.5, Z: -2.0 to 10.0)
	if pos.x >= -28.5 and pos.x <= -17.5 and pos.z >= -2.0 and pos.z <= 10.0:
		return SECTOR_WEST_CORRIDOR

	# Priority 5: Elevator Lobby (X: 17 to 39, Z: 9.5 to 24.0)
	if pos.x >= 17.0 and pos.x <= 39.0 and pos.z >= 9.5 and pos.z <= 24.0:
		return SECTOR_ELEVATOR_LOBBY

	# Priority 5b: Control-Elevator Connector Corridor
	if pos.x >= 7.0 and pos.x <= 17.0 and pos.z >= 12.0 and pos.z <= 18.0:
		return SECTOR_CONTROL_ROOM

	# Priority 6: Round Hallway Rotunda (X: 17 to 37, Z: 24.0 to 45.0)
	if pos.x >= 17.0 and pos.x <= 37.0 and pos.z >= 24.0 and pos.z <= 45.0:
		return SECTOR_ROUND_HALLWAY

	# Priority 6: East Connector Tunnel (X: 5.0 to 18.0, Z: 32.0 to 40.0)
	if pos.x >= 5.0 and pos.x <= 18.0 and pos.z >= 32.0 and pos.z <= 40.0:
		return SECTOR_CONNECTOR_TUNNEL

	# Priority 7: Fallback Defensive Hallway (X: -6.0 to 6.0, Z: 22.0 to 42.5)
	if pos.x >= -6.0 and pos.x <= 6.0 and pos.z >= 22.0 and pos.z <= 42.5:
		return SECTOR_FALLBACK_HALLWAY

	# Priority 8: Main Gate Room Arena (X: -18.5 to 18.5, Z: -22.5 to 8.0)
	if pos.x >= -18.5 and pos.x <= 18.5 and pos.z >= -22.5 and pos.z <= 8.0:
		return SECTOR_GATE_ROOM

	return SECTOR_UNKNOWN


func get_sector_display_name(sector_id: String) -> String:
	match sector_id:
		SECTOR_GATE_ROOM:
			return "GATE ROOM [LVL 28]"
		SECTOR_CONTROL_ROOM:
			return "GATE CONTROL MEZZANINE [LVL 28]"
		SECTOR_FALLBACK_HALLWAY:
			return "DEFENSIVE CHOKE CORRIDOR"
		SECTOR_CONNECTOR_TUNNEL:
			return "EAST CONNECTOR TUNNEL"
		SECTOR_ROUND_HALLWAY:
			return "ROUND HALLWAY ROTUNDA [LVL 28]"
		SECTOR_ARMORY:
			return "SGC ARMORY & MUNITIONS [LVL 28]"
		SECTOR_LABORATORY:
			return "NAQUADAH RESEARCH LAB [LVL 28]"
		SECTOR_ELEVATOR_LOBBY:
			return "ELEVATOR ACCESS LOBBY [LVL 28]"
		SECTOR_EAST_CORRIDOR:
			return "EAST DEFENSE CORRIDOR [LVL 28]"
		SECTOR_WEST_CORRIDOR:
			return "WEST DEFENSE CORRIDOR [LVL 28]"
		SECTOR_BRIEFING_ROOM:
			return "SGC BRIEFING ROOM [LVL 27]"
		SECTOR_GENERALS_OFFICE:
			return "GENERAL'S OFFICE [LVL 27]"
		SECTOR_SECURITY_STATION:
			return "SECURITY OPERATIONS [LVL 27]"
		SECTOR_UPPER_CORRIDOR:
			return "ADMINISTRATIVE CORRIDOR [LVL 27]"
		SECTOR_UPPER_ELEVATOR_LOBBY:
			return "UPPER ELEVATOR LOBBY [LVL 27]"
		_:
			var map := get_node_or_null("SGCMap") as SGCMap
			var region := map.definition.region(StringName(sector_id)) if map != null else null
			if region != null:
				return sector_id.replace("_", " ") + " [LVL %d]" % region.floor_number
			return "SGC CHEYENNE MOUNTAIN COMPLEX"


func set_emergency_lights(enabled: bool) -> void:
	is_emergency_active = enabled
	if not enabled and emergency_lights_container != null:
		for light in emergency_lights_container.get_children():
			var omni := light as OmniLight3D
			if omni != null:
				omni.light_energy = 0.0
	print("GateRoom: SGC Emergency alert lighting %s." % ("ACTIVATED" if enabled else "STANDBY"))


func _on_player_child_entered(node: Node) -> void:
	var player := node as PlayerController3D
	if player != null:
		player.player_died.connect(_check_squad_status)
		player.player_downed.connect(_check_squad_status)
		player.player_revived.connect(_check_squad_status)

		if hud != null:
			# Check if local player
			var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
			if player.name == str(local_id) or (local_id == 1 and player.name == "1"):
				hud.bind_local_player(player)


func _check_squad_status(id: int = 0) -> void:
	if not multiplayer.is_server():
		var local_id: int = multiplayer.get_unique_id()
		var local: PlayerController3D = players_container.get_node_or_null(str(local_id)) as PlayerController3D
		if local != null and local.health_component != null:
			report_squad_status.rpc_id(1, local_id, local.health_component.is_dead or local.health_component.is_downed)
		return
	if id != 0:
		var operative: PlayerController3D = players_container.get_node_or_null(str(id)) as PlayerController3D
		if operative != null and operative.health_component != null:
			neutralized_players[id] = operative.health_component.is_dead or operative.health_component.is_downed
	_evaluate_squad_status()


@rpc("any_peer", "call_local", "reliable")
func report_squad_status(id: int, neutralized: bool) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != id:
		return
	if players_container.get_node_or_null(str(id)) == null:
		return
	neutralized_players[id] = neutralized
	_evaluate_squad_status()


func _evaluate_squad_status() -> void:
	if players_container == null or players_container.get_child_count() == 0:
		return
	for body: Node in players_container.get_children():
		var operative := body as PlayerController3D
		if operative != null and operative.health_component != null:
			if not neutralized_players.get(operative.peer_id, false) and not operative.health_component.is_dead and not operative.health_component.is_downed:
				return
	_finish_mission(false)


func _on_player_extracted(_player: Node) -> void:
	if multiplayer.is_server():
		_finish_mission(true)


func _finish_mission(victory: bool) -> void:
	if wave_manager != null:
		wave_manager.end_mission()
	# A peer that is still loading receives the result in its room snapshot instead.
	SGCNetworkManager.mission_rpc(self, &"sync_mission_result", [victory])
	sync_mission_result(victory)


@rpc("authority", "call_local", "reliable")
func sync_mission_result(victory: bool) -> void:
	mission_result = 1 if victory else 0
	if wave_manager != null:
		wave_manager.mission_ended = true
	if hud != null:
		if victory:
			hud.show_victory()
		else:
			hud.show_defeat()


func toggle_blast_doors() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		sync_blast_doors.rpc(not is_blast_doors_closed)
	else:
		sync_blast_doors(not is_blast_doors_closed)


@rpc("authority", "call_local", "reliable")
func sync_blast_doors(closed: bool) -> void:
	if is_animating_doors:
		return
	is_blast_doors_closed = closed
	is_animating_doors = true
	blast_doors_toggled.emit(is_blast_doors_closed)

	var target_lx := -1.5 if is_blast_doors_closed else -4.8
	var target_rx := 1.5 if is_blast_doors_closed else 4.8

	# Side doors (West & East) target X relative to their local door frames:
	# Retracted (open): -2.8 and 2.8; Closed (sealed): -0.9 and 0.9
	var side_lx := -0.9 if is_blast_doors_closed else -2.8
	var side_rx := 0.9 if is_blast_doors_closed else 2.8

	if console_light != null:
		console_light.light_color = Color(1.0, 0.2, 0.2) if is_blast_doors_closed else Color(0.2, 0.9, 0.3)

	var tween := create_tween()
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", target_lx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", target_rx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Animate West Blast Door
	var west_door_n := get_node_or_null("BlastDoorsWest/BlastDoorNorth") as CSGBox3D
	var west_door_s := get_node_or_null("BlastDoorsWest/BlastDoorSouth") as CSGBox3D
	var west_light := get_node_or_null("BlastDoorsWest/BlastDoorConsole/ConsoleLight") as OmniLight3D
	if west_door_n != null and west_door_s != null:
		tween.parallel().tween_property(west_door_n, "position:x", side_lx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(west_door_s, "position:x", side_rx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if west_light != null:
		west_light.light_color = Color(1.0, 0.2, 0.2) if is_blast_doors_closed else Color(0.2, 0.9, 0.3)

	# Animate East Blast Door
	var east_door_n := get_node_or_null("BlastDoorsEast/BlastDoorNorth") as CSGBox3D
	var east_door_s := get_node_or_null("BlastDoorsEast/BlastDoorSouth") as CSGBox3D
	var east_light := get_node_or_null("BlastDoorsEast/BlastDoorConsole/ConsoleLight") as OmniLight3D
	if east_door_n != null and east_door_s != null:
		tween.parallel().tween_property(east_door_n, "position:x", side_lx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(east_door_s, "position:x", side_rx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if east_light != null:
		east_light.light_color = Color(1.0, 0.2, 0.2) if is_blast_doors_closed else Color(0.2, 0.9, 0.3)

	_play_door_sfx()

	tween.tween_callback(func() -> void:
		is_animating_doors = false
		print("GateRoom: All SGC Blast doors %s." % ("SEALED" if is_blast_doors_closed else "OPENED"))
	)


func _play_door_sfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists("res://audio/sfx_door_hydraulic.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_door_hydraulic.wav")
		audio.max_distance = 60.0
		audio.unit_size = 14.0
		add_child(audio)
		audio.global_position = Vector3(0, 2.5, 22.0)
		audio.finished.connect(audio.queue_free)
		audio.play()


func toggle_observation_shutters(force_closed: Variant = null) -> void:
	if not multiplayer.is_server():
		return
	var closed: bool = force_closed if force_closed is bool else not is_observation_shutters_closed
	if multiplayer.has_multiplayer_peer():
		sync_observation_shutters.rpc(closed)
	else:
		sync_observation_shutters(closed)


@rpc("authority", "call_local", "reliable")
func sync_observation_shutters(force_closed: bool) -> void:
	if is_animating_observation_shutters:
		return

	var target_state: bool = not is_observation_shutters_closed
	if force_closed != null and force_closed is bool:
		if is_observation_shutters_closed == (force_closed as bool):
			return
		target_state = force_closed as bool

	is_observation_shutters_closed = target_state
	is_animating_observation_shutters = true
	observation_shutters_toggled.emit(is_observation_shutters_closed)

	# Target Y: 7.35m when lowered (closed over glass), 10.75m when retracted (open above ceiling)
	var target_y: float = 7.4 if is_observation_shutters_closed else 10.1

	var shutters: CSGBox3D = find_child("BriefingBlastShutters", true, false) as CSGBox3D
	var tween: Tween = create_tween()
	if shutters != null:
		tween.tween_property(shutters, "position:y", target_y, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	_play_door_sfx()

	tween.tween_callback(func() -> void:
		is_animating_observation_shutters = false
		print("GateRoom: Observation Lounge blast shutters %s." % ("LOWERED (SEALED)" if is_observation_shutters_closed else "RAISED (OPEN)"))
	)


func _start_foothold_defense() -> void:
	if mission_id == SGCNetworkManager.MISSION_SGC_UAT:
		if hud != null: hud.update_objective("UAT BASE: EXPLORE SUBLEVELS 28 / 27 / 26 — NO HOSTILE ACTIVATION", Color(0.4, 0.9, 1.0))
		return
	if wave_manager == null:
		return
	print("GateRoom: STAGING PHASE: Operatives resupply at Armory before incursion...")
	if hud != null:
		hud.update_objective("STAGE AT ARMORY: COLLECT MUNITIONS & TACTICAL GEAR", Color(0.4, 0.9, 1.0))

	# 6.0-second Armory staging period for operatives to gather munitions
	var timer := get_tree().create_timer(6.0)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_trigger_base_scramble()
	)


func _trigger_base_scramble() -> void:
	if mission_id == SGCNetworkManager.MISSION_SGC_UAT: return
	print("GateRoom: KLAXON SOUNDS! RED ALERT! UNSCHEDULED OFFWORLD ACTIVATION!")
	set_emergency_lights(true)

	# Automatically seal observation lounge blast shutters on red alert klaxon
	if not is_observation_shutters_closed:
		toggle_observation_shutters(true)

	# Scramble Airmen to Gate Room
	if allies_container != null:
		for child in allies_container.get_children():
			var airman := child as SGCAirmanAIScript
			if airman != null:
				airman.scramble_to_gate_room()

	if wave_manager != null and is_instance_valid(wave_manager):
		wave_manager.start_wave_defense()


func _spawn_all_players() -> void:
	var spawn_points := spawns_container.get_children()
	var spawn_index: int = 0
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager

	# Spawn host player first (if not dedicated server)
	if net == null or not net.is_dedicated_server:
		var host_class: String = SGCNetworkManager.CLASS_SG3_HEAVY
		if net != null and net.peers.has(1):
			host_class = net.peers[1].get("class_id", net.selected_class_id)
		_spawn_player(1, host_class, spawn_points[spawn_index % spawn_points.size()].global_position)
		spawn_index += 1

	# Spawn connected client peers
	if net != null:
		for peer_id: int in net.peers:
			if peer_id == 1 or not net.mission_ready_peers.has(peer_id):
				continue
			var peer_data: Dictionary = net.peers[peer_id]
			var p_class: String = peer_data.get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY)
			var spawn_pos: Vector3 = spawn_points[spawn_index % spawn_points.size()].global_position
			_spawn_player(peer_id, p_class, spawn_pos)
			spawn_index += 1


func _spawn_player(peer_id: int, p_class_id: String, spawn_pos: Vector3) -> void:
	if players_container.has_node(str(peer_id)):
		return
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("GateRoom: Failed to load player scene at %s" % PLAYER_SCENE_PATH)
		return

	var player_instance := player_scene.instantiate() as PlayerController3D
	player_instance.name = str(peer_id)
	player_instance.position = spawn_pos
	player_instance.class_id = p_class_id

	players_container.add_child(player_instance, true)
	print("GateRoom: Spawned player %d (%s) at %s" % [peer_id, p_class_id, str(spawn_pos)])


func _on_peer_connected_during_mission(peer_id: int) -> void:
	if not multiplayer.is_server() or players_container.has_node(str(peer_id)) or not multiplayer.get_peers().has(peer_id):
		return
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null or not net.peers.has(peer_id):
		# Registration and scene-ready messages may cross on the first connection.
		return
	var points: Array[Node] = spawns_container.get_children()
	var profile: String = net.peers[peer_id].get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY)
	_spawn_player(peer_id, profile, (points[peer_id % points.size()] as Node3D).global_position)
	if net.is_dedicated_server and wave_manager != null and not wave_manager.defense_started:
		_start_foothold_defense()


func _on_peer_disconnected(peer_id: int) -> void:
	var player_node := players_container.get_node_or_null(str(peer_id))
	if player_node != null:
		print("GateRoom: Removing disconnected player %d" % peer_id)
		player_node.queue_free()
	call_deferred("_check_squad_status")


@rpc("any_peer", "call_remote", "reliable")
func request_room_snapshot() -> void:
	if not multiplayer.is_server():
		return
	sync_room_snapshot.rpc_id(
		multiplayer.get_remote_sender_id(),
		is_blast_doors_closed,
		is_observation_shutters_closed,
		is_emergency_active,
		mission_result,
		is_control_window_closed
	)


@rpc("authority", "call_remote", "reliable")
func sync_room_snapshot(
	doors: bool, shutters: bool, alarm: bool, result: int, control_closed: bool = false
) -> void:
	sync_control_window(control_closed)
	is_animating_doors = false
	is_animating_observation_shutters = false
	sync_blast_doors(doors)
	sync_observation_shutters(shutters)
	set_emergency_lights(alarm)
	if result >= 0:
		sync_mission_result(result == 1)


func toggle_control_window() -> void:
	if not multiplayer.is_server() or is_control_window_animating:
		return
	if multiplayer.has_multiplayer_peer():
		sync_control_window.rpc(not is_control_window_closed)
	else:
		sync_control_window(not is_control_window_closed)


@rpc("authority", "call_local", "reliable")
func sync_control_window(closed: bool) -> void:
	if is_control_window_animating or closed == is_control_window_closed:
		return
	is_control_window_closed = closed
	is_control_window_animating = true
	control_window_toggled.emit(closed)
	var shutter := find_child("ControlBlastShutters", true, false) as Node3D
	var tween := create_tween()
	if shutter != null:
		tween.tween_property(shutter, "position:y", 1.9 if closed else -0.8, 1.2)
	tween.tween_callback(func() -> void: is_control_window_animating = false)
