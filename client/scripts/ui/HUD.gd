class_name TacticalHUD
extends CanvasLayer
## In-game Tactical HUD for Project SGC.
## Displays operative vitals, weapon ammo, wave status, Helldivers-style DHD chords, and extraction victory.

# Node References
@onready var health_bar: ProgressBar = $VitalsPanel/VBox/HealthBar
@onready var health_label: Label = $VitalsPanel/VBox/HealthBar/HealthLabel
@onready var operative_label: Label = $VitalsPanel/VBox/OperativeLabel
@onready var stun_label: Label = $VitalsPanel/VBox/StunLabel

@onready var weapon_name_label: Label = $AmmoPanel/VBox/WeaponNameLabel
@onready var ammo_label: Label = $AmmoPanel/VBox/AmmoLabel
@onready var slot_label: Label = $AmmoPanel/VBox/SlotLabel
@onready var gadget_label: Label = $AmmoPanel/VBox/GadgetLabel

@onready var wave_label: Label = $TopBanner/VBox/WaveLabel
@onready var enemies_label: Label = $TopBanner/VBox/EnemiesLabel
@onready var objective_label: Label = $TopBanner/VBox/ObjectiveLabel

@onready var dhd_panel: PanelContainer = $DHDPanel
@onready var dhd_title: Label = $DHDPanel/VBox/DHDTitle
@onready var glyph_container: HBoxContainer = $DHDPanel/VBox/GlyphContainer

@onready var victory_modal: PanelContainer = $VictoryModal
@onready var return_btn: Button = $VictoryModal/VBox/ReturnBtn if has_node("VictoryModal/VBox/ReturnBtn") else null

var local_player: PlayerController3D = null
var current_dhd: DHDDialer = null


func _ready() -> void:
	dhd_panel.visible = false
	victory_modal.visible = false
	stun_label.visible = false
	objective_label.text = "DEFEND SGC LEVEL 28 - HOLD THE RAMP"
	if return_btn != null:
		return_btn.pressed.connect(_on_return_pressed)
	if local_player != null:
		bind_local_player(local_player)


func _on_return_pressed() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.disconnect_from_session()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func bind_local_player(player: PlayerController3D) -> void:
	local_player = player
	if local_player == null or not is_inside_tree() or operative_label == null:
		return
		return

	# Operative profile
	var class_names: Dictionary = {
		SGCNetworkManager.CLASS_SG3_HEAVY: "SG-3 HEAVY SUPPORT",
		SGCNetworkManager.CLASS_CARTER_TECH: "TECH SPECIALIST (CARTER)",
		SGCNetworkManager.CLASS_ONEILL_RECON: "POINTMAN RECON (O'NEILL)",
		SGCNetworkManager.CLASS_TEALC_JAFFA: "ALLIED JAFFA (TEAL'C)"
	}
	var c_name: String = class_names.get(player.class_id, "SGC OPERATIVE")
	operative_label.text = "%s [%s]" % [player.player_callsign, c_name]

	# Health component
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		if not health.health_changed.is_connected(_on_health_changed):
			health.health_changed.connect(_on_health_changed)
		if not health.stunned.is_connected(_on_player_stunned):
			health.stunned.connect(_on_player_stunned)
		if not health.recovered_from_stun.is_connected(_on_player_recovered):
			health.recovered_from_stun.connect(_on_player_recovered)
		_on_health_changed(health.current_health, health.max_health)

	# Active weapon
	_update_weapon_display()


func _process(_delta: float) -> void:
	if local_player != null:
		if operative_label != null and (operative_label.text == "" or operative_label.text.begins_with("OPERATIVE [")):
			bind_local_player(local_player)
		_update_weapon_display()


func _update_weapon_display() -> void:
	if local_player == null or local_player.current_weapon == null:
		return

	var weapon: WeaponBase = local_player.current_weapon
	weapon_name_label.text = weapon.display_name.to_upper()
	var slot_text: String = "[1] PRIMARY" if local_player.active_slot == 1 else "[2] SIDEARM"
	slot_label.text = slot_text

	if weapon.is_reloading:
		ammo_label.text = "RELOADING..."
	else:
		ammo_label.text = "%d / %d" % [weapon.current_ammo, weapon.reserve_ammo]

	# Gadget display
	if local_player.class_id == SGCNetworkManager.CLASS_SG3_HEAVY:
		gadget_label.text = "[G] BROWNING .50 CAL TRIPOD"
	elif local_player.class_id == SGCNetworkManager.CLASS_ONEILL_RECON:
		var has_c4: bool = local_player.active_c4 != null and is_instance_valid(local_player.active_c4)
		gadget_label.text = "[G] DETONATE C4 SATCHEL" if has_c4 else "[G] DEPLOY C4 SATCHEL"
	else:
		gadget_label.text = "[G] TACTICAL SATCHEL"


func _on_health_changed(cur: float, max_h: float) -> void:
	health_bar.max_value = max_h
	health_bar.value = cur
	health_label.text = "%d / %d" % [int(cur), int(max_h)]


func _on_player_stunned(duration_s: float) -> void:
	stun_label.visible = true
	stun_label.text = "⚡ ELECTRICAL STUN: %.0fs ⚡" % duration_s


func _on_player_recovered() -> void:
	stun_label.visible = false


# --- Wave Manager Signals ---
func on_wave_started(wave_num: int, enemy_count: int) -> void:
	wave_label.text = "WAVE %d / 3" % wave_num
	enemies_label.text = "HOSTILES: %d JAFFA GUARDS" % enemy_count
	objective_label.text = "FOOTHOLD IN PROGRESS - REPEL STARGATE INVASION!"


func on_jaffa_count_changed(enemies_remaining: int, wave_num: int) -> void:
	wave_label.text = "WAVE %d / 3" % wave_num
	enemies_label.text = "HOSTILES: %d JAFFA GUARDS" % enemies_remaining


func on_wave_cleared(wave_num: int, intermission_s: float) -> void:
	wave_label.text = "WAVE %d CLEARED!" % wave_num
	enemies_label.text = "HOSTILES ELIMINATED"
	objective_label.text = "INTERMISSION: %.0fs UNTIL NEXT ASSAULT" % intermission_s


func on_all_waves_defeated() -> void:
	wave_label.text = "ALL WAVES CLEARED!"
	enemies_label.text = "SGC LEVEL 28 SECURED"
	objective_label.text = "ACTIVATE SGC DIALING COMPUTER [E] TO STABILIZE IRIS & EXTRACT!"


# --- DHD Dialing Mini-Game ---
func bind_dhd(dhd: DHDDialer) -> void:
	current_dhd = dhd
	if current_dhd == null:
		return

	if not current_dhd.dialing_engaged.is_connected(_on_dhd_engaged):
		current_dhd.dialing_engaged.connect(_on_dhd_engaged)
		current_dhd.chevron_advanced.connect(_on_chevron_advanced)
		current_dhd.glyph_error.connect(_on_glyph_error)
		current_dhd.gdo_verified.connect(_on_gdo_verified)
		current_dhd.sequence_completed.connect(_on_dhd_completed)
		current_dhd.dialing_cancelled.connect(_on_dhd_cancelled)


func _on_glyph_error() -> void:
	dhd_title.text = "⚠️ CODE MISMATCH: SEQUENCE RESET! ⚠️"
	dhd_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	var tween := dhd_title.create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void:
		dhd_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	)
	_render_glyphs()


func _on_dhd_engaged(_player: Node) -> void:
	dhd_panel.visible = true
	_render_glyphs()


func _on_chevron_advanced(_cur: int, _total: int) -> void:
	_render_glyphs()


func _on_gdo_verified() -> void:
	_render_glyphs()


func _on_dhd_completed() -> void:
	dhd_panel.visible = true
	dhd_title.text = "IRIS OPENED! STEP THROUGH EVENT HORIZON TO EXTRACT!"
	_render_glyphs()


func _on_dhd_cancelled() -> void:
	dhd_panel.visible = false


func _render_glyphs() -> void:
	if current_dhd == null:
		return

	# Clear glyph container
	for child in glyph_container.get_children():
		child.queue_free()

	var arrow_symbols: Dictionary = {
		"UP": "⬆",
		"DOWN": "⬇",
		"LEFT": "⬅",
		"RIGHT": "➡"
	}

	if current_dhd.current_phase == DHDDialer.DialPhase.CHEVRONS:
		dhd_title.text = "SGC DIALING COMPUTER: 7-CHEVRON LOCK SEQUENCE"
		for i in range(current_dhd.chevron_sequence.size()):
			var glyph_key: String = current_dhd.chevron_sequence[i]
			var symbol: String = arrow_symbols.get(glyph_key, "?")
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(50, 50)
			btn.text = symbol
			btn.focus_mode = Control.FOCUS_NONE

			if i < current_dhd.current_chevron_index:
				# Locked chevron (Gold Naquadah)
				btn.modulate = Color(1.0, 0.75, 0.2)
			elif i == current_dhd.current_chevron_index:
				# Current chevron (Pulsing Cyan)
				btn.modulate = Color(0.2, 0.9, 1.0)
			else:
				# Upcoming
				btn.modulate = Color(0.4, 0.4, 0.4)
			glyph_container.add_child(btn)

	elif current_dhd.current_phase == DHDDialer.DialPhase.GDO_AUTH:
		dhd_title.text = "GDO IRIS AUTHORIZATION CODE (4 BEATS)"
		for i in range(current_dhd.gdo_sequence.size()):
			var glyph_key: String = current_dhd.gdo_sequence[i]
			var symbol: String = arrow_symbols.get(glyph_key, "?")
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(50, 50)
			btn.text = symbol
			btn.focus_mode = Control.FOCUS_NONE

			if i < current_dhd.gdo_index:
				btn.modulate = Color(0.2, 1.0, 0.4) # Green verified
			elif i == current_dhd.gdo_index:
				btn.modulate = Color(1.0, 1.0, 0.2)
			else:
				btn.modulate = Color(0.4, 0.4, 0.4)
			glyph_container.add_child(btn)

	elif current_dhd.current_phase == DHDDialer.DialPhase.COMPLETE:
		dhd_title.text = "EXTRACT NOW: STEP INTO WORMHOLE!"


func show_victory() -> void:
	victory_modal.visible = true
