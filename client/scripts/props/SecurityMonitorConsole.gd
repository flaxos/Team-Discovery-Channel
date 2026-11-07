class_name SecurityMonitorConsole
extends Node3D
## SGC Level 27 Security Station CCTV Surveillance Console.
## Allows operatives to cycle through 4 live camera feeds across Sublevel 28 & Sublevel 27.

signal cctv_entered(player: PlayerController3D)
signal cctv_cycled(feed_index: int, feed_name: String)
signal cctv_exited(player: PlayerController3D)

const FEEDS: Array[Dictionary] = [
	{
		"name": "CAM 01: GATE ROOM ARENA",
		"position": Vector3(0.0, 8.5, 6.0),
		"target": Vector3(0.0, 4.0, -15.0),
		"fov": 65.0
	},
	{
		"name": "CAM 02: CONTROL ROOM MEZZANINE",
		"position": Vector3(6.0, 4.0, 19.0),
		"target": Vector3(0.0, 1.5, 12.0),
		"fov": 60.0
	},
	{
		"name": "CAM 03: SUBLEVEL 28 ARMORY",
		"position": Vector3(50.0, 5.0, 29.0),
		"target": Vector3(44.0, 0.5, 36.0),
		"fov": 70.0
	},
	{
		"name": "CAM 04: SUBLEVEL 27 BRIEFING ROOM",
		"position": Vector3(-6.0, 8.5, 20.0),
		"target": Vector3(0.0, 5.5, 14.0),
		"fov": 65.0
	}
]

var active_player: PlayerController3D = null
var current_feed_index: int = 0
var console_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("interactable")
	_setup_visual_indicator()


func _setup_visual_indicator() -> void:
	console_light = OmniLight3D.new()
	console_light.name = "ConsoleLight"
	console_light.position = Vector3(0, 0.8, 0)
	console_light.light_color = Color(0.2, 0.7, 1.0)  # CCTV screen blue
	console_light.light_energy = 1.6
	console_light.omni_range = 3.5
	add_child(console_light)


func _process(_delta: float) -> void:
	if active_player != null:
		# Auto-exit CCTV if operative moves away or presses Escape
		if not is_instance_valid(active_player) or active_player.global_position.distance_to(global_position) > 3.8 or Input.is_action_just_pressed("ui_cancel"):
			exit_cctv()


func interact(player: PlayerController3D) -> void:
	if player == null:
		return

	if active_player == null:
		# Enter CCTV surveillance mode
		active_player = player
		current_feed_index = 0
		_show_feed(current_feed_index)
		cctv_entered.emit(player)
		print("SecurityMonitorConsole: Operative %d entered CCTV surveillance mode." % player.peer_id)
	elif active_player == player:
		# Cycle to next camera feed
		cycle_feed()


func cycle_feed() -> void:
	if active_player == null:
		return
	current_feed_index = (current_feed_index + 1) % FEEDS.size()
	_show_feed(current_feed_index)


func _show_feed(idx: int) -> void:
	if active_player == null:
		return
	var feed: Dictionary = FEEDS[idx]
	var cam_pos: Vector3 = feed["position"]
	var cam_target: Vector3 = feed["target"]
	var cam_fov: float = feed["fov"]

	active_player.set_cctv_camera(cam_pos, cam_target, cam_fov)
	cctv_cycled.emit(idx, feed["name"])
	print("SecurityMonitorConsole: Switched to [%s]" % feed["name"])


func exit_cctv() -> void:
	if active_player != null:
		var p := active_player
		active_player = null
		p.clear_cctv_camera()
		cctv_exited.emit(p)
		print("SecurityMonitorConsole: Operative %d exited CCTV mode." % p.peer_id)
