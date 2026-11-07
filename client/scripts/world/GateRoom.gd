class_name GateRoom
extends Node3D
## SGC Level 28 Gate Room Arena & Stargate Ramp.
## Coordinates player spawning via MultiplayerSpawner, dedicated server pawnless host,
## mid-mission operative joins, defensive sandbags, gate status, and emergency alert lighting.

const PLAYER_SCENE_PATH: String = "res://scenes/entities/Player.tscn"

# Sector identifiers for SGC Sublevels 28 & 27
const SECTOR_GATE_ROOM: String = "GATE_ROOM"
const SECTOR_CONTROL_ROOM: String = "CONTROL_ROOM"
const SECTOR_FALLBACK_HALLWAY: String = "FALLBACK_HALLWAY"
const SECTOR_CONNECTOR_TUNNEL: String = "CONNECTOR_TUNNEL"
const SECTOR_ROUND_HALLWAY: String = "ROUND_HALLWAY"
const SECTOR_ARMORY: String = "ARMORY"
const SECTOR_LABORATORY: String = "LABORATORY"
const SECTOR_ELEVATOR_LOBBY: String = "ELEVATOR_LOBBY"

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
@onready var dhd_console: DHDDialer = $DHDConsole if has_node("DHDConsole") else null
@onready var hud: TacticalHUD = $TacticalHUD if has_node("TacticalHUD") else null
@onready var door_left: CSGBox3D = $BlastDoors/BlastDoorLeft if has_node("BlastDoors/BlastDoorLeft") else null
@onready var door_right: CSGBox3D = $BlastDoors/BlastDoorRight if has_node("BlastDoors/BlastDoorRight") else null
@onready var console_light: OmniLight3D = $BlastDoors/BlastDoorConsole/ConsoleLight if has_node("BlastDoors/BlastDoorConsole/ConsoleLight") else null
@onready var emergency_lights_container: Node3D = $EmergencyLights if has_node("EmergencyLights") else null

var is_blast_doors_closed: bool = false
var is_animating_doors: bool = false
var is_emergency_active: bool = false
var emergency_strobe_timer: float = 0.0
var player_sectors: Dictionary = {}

signal blast_doors_toggled(closed: bool)
signal sector_changed(player_id: int, old_sector: String, new_sector: String)


func _ready() -> void:
	# Configure spawner
	if spawner != null:
		spawner.spawn_path = NodePath("../Players")
		if spawner.get_spawnable_scene_count() == 0:
			spawner.add_spawnable_scene(PLAYER_SCENE_PATH)

	# Connect players container to bind HUD
	if players_container != null:
		players_container.child_entered_tree.connect(_on_player_child_entered)

	# Connect WaveManager and DHD to HUD and emergency lighting
	if wave_manager != null:
		wave_manager.wave_started.connect(func(w: int, c: int) -> void:
			if hud != null:
				hud.on_wave_started(w, c)
			if w == 3:
				set_emergency_lights(true)
			else:
				set_emergency_lights(false)
		)
		wave_manager.jaffa_count_changed.connect(func(rem: int, cur: int) -> void:
			if hud != null:
				hud.on_jaffa_count_changed(rem, cur)
		)
		wave_manager.wave_cleared.connect(func(w: int) -> void:
			if hud != null:
				hud.on_wave_cleared(w, wave_manager.intermission_duration_s)
		)
		wave_manager.all_waves_defeated.connect(func() -> void:
			if hud != null:
				hud.on_all_waves_defeated()
			set_emergency_lights(false)
		)

	if dhd_console != null and hud != null:
		hud.bind_dhd(dhd_console)
	if stargate_mesh != null:
		stargate_mesh.player_extracted.connect(_on_player_extracted)

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	# If host / server in an active game session, spawn all registered players and start waves
	if net != null and net.is_server:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.peer_connected.connect(_on_peer_connected_during_mission)
		_spawn_all_players()

		# If dedicated server without clients yet, wait for first client before starting foothold defense
		if not net.is_dedicated_server or net.peers.size() > 1:
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
				var cur_sec: String = get_current_sector(player.global_position)
				var prev_sec: String = player_sectors.get(pid, "")
				if cur_sec != prev_sec:
					player_sectors[pid] = cur_sec
					sector_changed.emit(pid, prev_sec, cur_sec)
					print("GateRoom: Operative %s entered sector: %s" % [player.name, cur_sec])
					if hud != null:
						var local_id := 1
						if multiplayer != null and multiplayer.has_multiplayer_peer():
							local_id = multiplayer.get_unique_id()
						if player.name == str(local_id) or (local_id == 1 and player.name == "1"):
							hud.update_sector_display(cur_sec)


func get_current_sector(pos: Vector3) -> String:
	# ==========================================
	# SUBLEVEL 27 SECTORS (Y >= 4.5m)
	# ==========================================
	if pos.y >= 4.5:
		# General Hammond's Office (X: 27 to 38, Z: -11 to 3)
		if pos.x >= 26.5 and pos.x <= 38.0 and pos.z >= -11.0 and pos.z <= 3.0:
			return SECTOR_GENERALS_OFFICE

		# Briefing Room & Gate Overlook (X: 12 to 27, Z: -13 to 5)
		if pos.x >= 12.0 and pos.x <= 27.0 and pos.z >= -13.0 and pos.z <= 5.0:
			return SECTOR_BRIEFING_ROOM

		# Security Operations Station (X: 12 to 27, Z: -22 to -12.5)
		if pos.x >= 12.0 and pos.x <= 27.0 and pos.z >= -22.0 and pos.z <= -12.5:
			return SECTOR_SECURITY_STATION

		# Upper Secure Corridor (X: 26.5 to 38, Z: -21 to -10.5)
		if pos.x >= 26.5 and pos.x <= 38.0 and pos.z >= -21.0 and pos.z <= -10.5:
			return SECTOR_UPPER_CORRIDOR

		# Level 27 Upper Elevator Lobby (X: 16 to 36, Z: 9 to 27)
		if pos.x >= 16.0 and pos.x <= 36.0 and pos.z >= 9.0 and pos.z <= 27.0:
			return SECTOR_UPPER_ELEVATOR_LOBBY

		return "LEVEL_27_MEZZANINE"

	# ==========================================
	# SUBLEVEL 28 SECTORS (Y < 4.5m)
	# ==========================================
	# Priority 1: Control Room Mezzanine (raised balcony Y >= 0.3)
	if pos.x >= 13.5 and pos.x <= 26.5 and pos.z >= -12.5 and pos.z <= 4.5 and pos.y >= 0.3:
		return SECTOR_CONTROL_ROOM

	# Priority 2: Armory (X: 35 to 54, Z: 27 to 45)
	if pos.x >= 34.5 and pos.x <= 54.0 and pos.z >= 27.0 and pos.z <= 45.0:
		return SECTOR_ARMORY

	# Priority 3: Laboratory (X: 16.5 to 35.5, Z: 45 to 66)
	if pos.x >= 16.5 and pos.x <= 35.5 and pos.z >= 45.0 and pos.z <= 66.0:
		return SECTOR_LABORATORY

	# Priority 4: Elevator Lobby (X: 16.5 to 35.5, Z: 9.5 to 26.5)
	if pos.x >= 16.5 and pos.x <= 35.5 and pos.z >= 9.5 and pos.z <= 26.5:
		return SECTOR_ELEVATOR_LOBBY

	# Priority 5: Round Hallway Rotunda (X: 17 to 35, Z: 26.5 to 45)
	if pos.x >= 17.0 and pos.x <= 35.0 and pos.z >= 26.5 and pos.z <= 45.0:
		return SECTOR_ROUND_HALLWAY

	# Priority 6: East Connector Tunnel (X: 5.0 to 17.5, Z: 32.0 to 40.0)
	if pos.x >= 5.0 and pos.x <= 17.5 and pos.z >= 32.0 and pos.z <= 40.0:
		return SECTOR_CONNECTOR_TUNNEL

	# Priority 7: Fallback Defensive Hallway (X: -5.5 to 5.5, Z: 21.5 to 42.5)
	if pos.x >= -5.5 and pos.x <= 5.5 and pos.z >= 21.5 and pos.z <= 42.5:
		return SECTOR_FALLBACK_HALLWAY

	# Priority 8: Main Gate Room Arena (X: -18.5 to 18.5, Z: -22.5 to 22.5)
	if pos.x >= -18.5 and pos.x <= 18.5 and pos.z >= -22.5 and pos.z <= 22.5:
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
			var local_id := multiplayer.get_unique_id()
			if player.name == str(local_id) or (local_id == 1 and player.name == "1"):
				hud.bind_local_player(player)


func _check_squad_status(_id: int = 0) -> void:
	if players_container == null or players_container.get_child_count() == 0:
		return
	var any_standing: bool = false
	for p in players_container.get_children():
		var player := p as PlayerController3D
		if player != null and player.health_component != null:
			if not player.health_component.is_dead and not player.health_component.is_downed:
				any_standing = true
				break

	if not any_standing:
		print("GateRoom: SQUAD WIPED! All operatives neutralized.")
		if hud != null:
			hud.show_defeat()


func _on_player_extracted(_player: Node) -> void:
	if hud != null:
		hud.show_victory()


func toggle_blast_doors() -> void:
	if is_animating_doors:
		return
	is_blast_doors_closed = not is_blast_doors_closed
	is_animating_doors = true
	blast_doors_toggled.emit(is_blast_doors_closed)

	var target_lx := -1.5 if is_blast_doors_closed else -4.8
	var target_rx := 1.5 if is_blast_doors_closed else 4.8

	if console_light != null:
		console_light.light_color = Color(1.0, 0.2, 0.2) if is_blast_doors_closed else Color(0.2, 0.9, 0.3)

	var tween := create_tween()
	if door_left != null and door_right != null:
		tween.tween_property(door_left, "position:x", target_lx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(door_right, "position:x", target_rx, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	_play_door_sfx()

	tween.tween_callback(func() -> void:
		is_animating_doors = false
		print("GateRoom: Blast doors %s." % ("SEALED" if is_blast_doors_closed else "OPENED"))
	)


func _play_door_sfx() -> void:
	if ResourceLoader.exists("res://audio/sfx_door_hydraulic.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_door_hydraulic.wav")
		audio.max_distance = 60.0
		audio.unit_size = 14.0
		add_child(audio)
		audio.global_position = Vector3(0, 2.5, 22.0)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _start_foothold_defense() -> void:
	if wave_manager == null:
		return
	# 3-second preparation time before Stargate alarms sound
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func() -> void:
		if wave_manager != null and is_instance_valid(wave_manager):
			wave_manager.start_wave_defense()
	)


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
			if peer_id == 1:
				continue
			var peer_data: Dictionary = net.peers[peer_id]
			var p_class: String = peer_data.get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY)
			var spawn_pos: Vector3 = spawn_points[spawn_index % spawn_points.size()].global_position
			_spawn_player(peer_id, p_class, spawn_pos)
			spawn_index += 1


func _spawn_player(peer_id: int, p_class_id: String, spawn_pos: Vector3) -> void:
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
	if not multiplayer.is_server():
		return
	print("GateRoom: Peer %d connected during active mission." % peer_id)
	var timer := get_tree().create_timer(0.2)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
		var p_class: String = SGCNetworkManager.CLASS_SG3_HEAVY
		if net != null and net.peers.has(peer_id):
			p_class = net.peers[peer_id].get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY)
		var spawn_points := spawns_container.get_children()
		var spawn_pos: Vector3 = spawn_points[peer_id % spawn_points.size()].global_position
		_spawn_player(peer_id, p_class, spawn_pos)

		if net != null and net.is_dedicated_server and wave_manager != null and not wave_manager.is_wave_active and wave_manager.current_wave == 0:
			_start_foothold_defense()
	)


func _on_peer_disconnected(peer_id: int) -> void:
	var player_node := players_container.get_node_or_null(str(peer_id))
	if player_node != null:
		print("GateRoom: Removing disconnected player %d" % peer_id)
		player_node.queue_free()
	_check_squad_status()
