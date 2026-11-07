class_name Nameplate3D
extends Node3D
## In-World 3D Operative Nameplate & Emergency Bleedout Beacon.
## Displays callsign, class specialization badge, 3D health status bar,
## and a pulsing high-visibility bleedout beacon (with no_depth_test) when downed.

@onready var callsign_label: Label3D = $CallsignLabel if has_node("CallsignLabel") else null
@onready var health_label: Label3D = $HealthLabel if has_node("HealthLabel") else null
@onready var downed_beacon: Label3D = $DownedBeacon if has_node("DownedBeacon") else null

var target_player: CharacterBody3D = null
var health_component: HealthComponent = null
var is_local_player: bool = false
var pulse_timer: float = 0.0


func _ready() -> void:
	if downed_beacon != null:
		downed_beacon.visible = false
		downed_beacon.no_depth_test = true
		downed_beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	if callsign_label != null:
		callsign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	if health_label != null:
		health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func setup(player: CharacterBody3D, is_local: bool) -> void:
	target_player = player
	is_local_player = is_local
	health_component = player.get("health_component") as HealthComponent

	if health_component != null:
		health_component.health_changed.connect(_on_health_changed)
		health_component.downed.connect(_on_downed)
		health_component.revived.connect(_on_revived)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.current_health, health_component.max_health)

	var callsign: String = str(player.get("player_callsign"))
	var p_class: String = str(player.get("class_id"))
	var class_info: Dictionary = SGCNetworkManager.CLASS_PROFILES.get(p_class, {})
	var class_name_str: String = class_info.get("name", "OPERATIVE").to_upper()
	set_callsign(callsign, class_name_str)

	# If local player, hide nameplate to keep crosshairs clean, but allow downed beacon
	if is_local_player:
		if callsign_label != null:
			callsign_label.visible = false
		if health_label != null:
			health_label.visible = false


func set_callsign(callsign: String, class_title: String) -> void:
	if callsign_label != null:
		callsign_label.text = "%s [%s]" % [callsign.to_upper(), class_title]


func _on_health_changed(cur_hp: float, max_hp: float) -> void:
	if health_label == null or max_hp <= 0.0:
		return

	var ratio: float = clampf(cur_hp / max_hp, 0.0, 1.0)
	var bar_segments: int = 10
	var filled_segments: int = int(round(ratio * bar_segments))

	var bar_str: String = ""
	for i in range(bar_segments):
		if i < filled_segments:
			bar_str += "█"
		else:
			bar_str += "░"

	health_label.text = "[%s] %d%%" % [bar_str, int(ratio * 100)]

	if ratio > 0.5:
		health_label.modulate = Color(0.2, 0.95, 0.35)
	elif ratio > 0.25:
		health_label.modulate = Color(1.0, 0.8, 0.15)
	else:
		health_label.modulate = Color(1.0, 0.2, 0.2)


func _on_downed() -> void:
	if downed_beacon != null:
		downed_beacon.visible = true
		downed_beacon.text = "⚠️ DOWNED - HOLD [E] TO REVIVE (20s) ⚠️"
	if health_label != null:
		health_label.modulate = Color(1.0, 0.2, 0.2)
		health_label.text = "[BLEEDING OUT]"


func _on_revived() -> void:
	if downed_beacon != null:
		downed_beacon.visible = false
	if health_component != null:
		_on_health_changed(health_component.current_health, health_component.max_health)


func _on_died() -> void:
	if downed_beacon != null:
		downed_beacon.visible = false
	if health_label != null:
		health_label.modulate = Color(0.6, 0.1, 0.1)
		health_label.text = "[K.I.A. - OPERATIVE ELIMINATED]"


func _process(delta: float) -> void:
	if health_component != null and health_component.is_downed and downed_beacon != null and downed_beacon.visible:
		pulse_timer += delta * 6.0
		var pulse: float = sin(pulse_timer) * 0.5 + 0.5
		# Flash between alert crimson and high-visibility neon amber
		downed_beacon.modulate = Color(1.0, 0.15 + pulse * 0.65, 0.1)

		var seconds_left: int = int(ceil(health_component.bleedout_timer))
		downed_beacon.text = "⚠️ DOWNED - HOLD [E] TO REVIVE (%ds) ⚠️" % maxi(0, seconds_left)
