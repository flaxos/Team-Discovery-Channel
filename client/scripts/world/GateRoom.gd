class_name GateRoom
extends Node3D
## SGC Level 28 Gate Room Arena & Stargate Ramp.
## Coordinates player spawning via MultiplayerSpawner, defensive sandbags, and gate status.

const PLAYER_SCENE_PATH: String = "res://scenes/entities/Player.tscn"

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

var is_blast_doors_closed: bool = false
var is_animating_doors: bool = false

signal blast_doors_toggled(closed: bool)


func _ready() -> void:
	# Configure spawner
	if spawner != null:
		spawner.spawn_path = NodePath("../Players")
		if spawner.get_spawnable_scene_count() == 0:
			spawner.add_spawnable_scene(PLAYER_SCENE_PATH)

	# Connect players container to bind HUD
	if players_container != null:
		players_container.child_entered_tree.connect(_on_player_child_entered)

	# Connect WaveManager and DHD to HUD
	if hud != null:
		if wave_manager != null:
			wave_manager.wave_started.connect(hud.on_wave_started)
			wave_manager.jaffa_count_changed.connect(hud.on_jaffa_count_changed)
			wave_manager.wave_cleared.connect(func(w: int) -> void:
				hud.on_wave_cleared(w, wave_manager.intermission_duration_s)
			)
			wave_manager.all_waves_defeated.connect(hud.on_all_waves_defeated)
		if dhd_console != null:
			hud.bind_dhd(dhd_console)
		if stargate_mesh != null:
			stargate_mesh.player_extracted.connect(_on_player_extracted)

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	# If host / server in an active game session, spawn all registered players and start waves
	if net != null and net.is_server:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawn_all_players()
		_start_foothold_defense()


func _on_player_child_entered(node: Node) -> void:
	var player := node as PlayerController3D
	if player != null and hud != null:
		# Check if local player
		var local_id := multiplayer.get_unique_id()
		if player.name == str(local_id) or (local_id == 1 and player.name == "1"):
			hud.bind_local_player(player)


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

	# Spawn host player first
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


func _on_peer_disconnected(peer_id: int) -> void:
	var player_node := players_container.get_node_or_null(str(peer_id))
	if player_node != null:
		print("GateRoom: Removing disconnected player %d" % peer_id)
		player_node.queue_free()
