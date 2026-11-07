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
@onready var damage_vignette: TextureRect = $DamageVignette if has_node("DamageVignette") else null

@onready var downed_label: Label = $VitalsPanel/VBox/DownedLabel if has_node("VitalsPanel/VBox/DownedLabel") else null
@onready var revive_bar: ProgressBar = $VitalsPanel/VBox/ReviveProgressBar if has_node("VitalsPanel/VBox/ReviveProgressBar") else null
@onready var revive_label: Label = $VitalsPanel/VBox/ReviveProgressBar/ReviveLabel if has_node("VitalsPanel/VBox/ReviveProgressBar/ReviveLabel") else null

@onready var pause_menu: PanelContainer = $PauseMenu if has_node("PauseMenu") else null
@onready var master_slider: HSlider = $PauseMenu/VBox/MasterSlider if has_node("PauseMenu/VBox/MasterSlider") else null
@onready var master_label: Label = $PauseMenu/VBox/MasterLabel if has_node("PauseMenu/VBox/MasterLabel") else null
@onready var sfx_slider: HSlider = $PauseMenu/VBox/SFXSlider if has_node("PauseMenu/VBox/SFXSlider") else null
@onready var sfx_label: Label = $PauseMenu/VBox/SFXLabel if has_node("PauseMenu/VBox/SFXLabel") else null
@onready var ambience_slider: HSlider = $PauseMenu/VBox/AmbienceSlider if has_node("PauseMenu/VBox/AmbienceSlider") else null
@onready var ambience_label: Label = $PauseMenu/VBox/AmbienceLabel if has_node("PauseMenu/VBox/AmbienceLabel") else null
@onready var resume_btn: Button = $PauseMenu/VBox/ResumeBtn if has_node("PauseMenu/VBox/ResumeBtn") else null
@onready var lobby_btn: Button = $PauseMenu/VBox/LobbyBtn if has_node("PauseMenu/VBox/LobbyBtn") else null

@onready var debrief_title: Label = $VictoryModal/VBox/Title if has_node("VictoryModal/VBox/Title") else null
@onready var debrief_subtitle: Label = $VictoryModal/VBox/Subtitle if has_node("VictoryModal/VBox/Subtitle") else null
@onready var stat_time: Label = $VictoryModal/VBox/StatsContainer/StatTime if has_node("VictoryModal/VBox/StatsContainer/StatTime") else null
@onready var stat_kills: Label = $VictoryModal/VBox/StatsContainer/StatKills if has_node("VictoryModal/VBox/StatsContainer/StatKills") else null
@onready var stat_waves: Label = $VictoryModal/VBox/StatsContainer/StatWaves if has_node("VictoryModal/VBox/StatsContainer/StatWaves") else null
@onready var stat_chevrons: Label = $VictoryModal/VBox/StatsContainer/StatChevrons if has_node("VictoryModal/VBox/StatsContainer/StatChevrons") else null
@onready var stat_status: Label = $VictoryModal/VBox/StatsContainer/StatStatus if has_node("VictoryModal/VBox/StatsContainer/StatStatus") else null

var local_player: PlayerController3D = null
var current_dhd: DHDDialer = null
var vignette_pulse_time: float = 0.0
var flash_alpha: float = 0.0
var mission_seconds: float = 0.0
var total_kills: int = 0
var is_mission_ended: bool = false


func _ready() -> void:
	dhd_panel.visible = false
	victory_modal.visible = false
	stun_label.visible = false
	if downed_label != null:
		downed_label.visible = false
	if revive_bar != null:
		revive_bar.visible = false
	if pause_menu != null:
		pause_menu.visible = false

	objective_label.text = "DEFEND SGC LEVEL 28 - HOLD THE RAMP"

	if return_btn != null:
		return_btn.pressed.connect(_on_return_pressed)
	if resume_btn != null:
		resume_btn.pressed.connect(toggle_pause_menu)
	if lobby_btn != null:
		lobby_btn.pressed.connect(_on_return_pressed)

	# Audio volume sliders
	if master_slider != null:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if ambience_slider != null:
		ambience_slider.value_changed.connect(_on_ambience_slider_changed)

	if local_player != null:
		bind_local_player(local_player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		toggle_pause_menu()


func toggle_pause_menu() -> void:
	if pause_menu == null or is_mission_ended:
		return
	pause_menu.visible = not pause_menu.visible


func _on_master_slider_changed(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		if value <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if master_label != null:
		master_label.text = "MASTER VOLUME: %d%%" % int(value * 100.0)


func _on_sfx_slider_changed(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		if value <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if sfx_label != null:
		sfx_label.text = "SFX VOLUME: %d%%" % int(value * 100.0)


func _on_ambience_slider_changed(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Ambience")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Klaxons / Ambience")
	if bus_idx != -1:
		if value <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if ambience_label != null:
		ambience_label.text = "AMBIENCE & KLAXONS: %d%%" % int(value * 100.0)


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
		if not health.damage_taken.is_connected(_on_player_damage_taken):
			health.damage_taken.connect(_on_player_damage_taken)
		if not health.bleedout_tick.is_connected(_on_bleedout_tick):
			health.bleedout_tick.connect(_on_bleedout_tick)
		if not health.downed.is_connected(_on_health_downed):
			health.downed.connect(_on_health_downed)
		if not health.revived.is_connected(_on_health_revived):
			health.revived.connect(_on_health_revived)
		_on_health_changed(health.current_health, health.max_health)

	if not player.player_downed.is_connected(_on_local_player_downed):
		player.player_downed.connect(_on_local_player_downed)
	if not player.player_revived.is_connected(_on_local_player_revived):
		player.player_revived.connect(_on_local_player_revived)
	if not player.revive_progress_changed.is_connected(_on_revive_progress_changed):
		player.revive_progress_changed.connect(_on_revive_progress_changed)

	# Active weapon
	_update_weapon_display()


func _process(delta: float) -> void:
	if not is_mission_ended:
		mission_seconds += delta
	if local_player != null:
		if operative_label != null and (operative_label.text == "" or operative_label.text.begins_with("OPERATIVE [")):
			bind_local_player(local_player)
		_update_weapon_display()
	_update_damage_vignette(delta)


func _on_health_downed() -> void:
	if local_player != null:
		_on_local_player_downed(local_player.peer_id)


func _on_health_revived() -> void:
	if local_player != null:
		_on_local_player_revived(local_player.peer_id)


func _on_local_player_downed(_peer_id: int) -> void:
	if downed_label != null:
		downed_label.visible = true
		downed_label.text = "⚠️ DOWNED! BLEEDING OUT (20s) ⚠️"


func _on_local_player_revived(_peer_id: int) -> void:
	if downed_label != null:
		downed_label.visible = false


func _on_bleedout_tick(seconds_left: float) -> void:
	if downed_label != null and local_player != null and local_player.health_component != null and local_player.health_component.is_downed:
		downed_label.visible = true
		downed_label.text = "⚠️ DOWNED! BLEEDING OUT (%ds) ⚠️" % int(ceil(seconds_left))


func _on_revive_progress_changed(progress: float) -> void:
	if revive_bar != null:
		if progress > 0.0:
			revive_bar.visible = true
			revive_bar.value = progress * 100.0
			if revive_label != null:
				revive_label.text = "REVIVING SQUADMATE... (%d%%)" % int(progress * 100.0)
		else:
			revive_bar.visible = false


func _on_player_damage_taken(amount: float, _source: Node, _type: String) -> void:
	flash_alpha = clampf(amount * 0.02, 0.25, 0.8)


func _update_damage_vignette(delta: float) -> void:
	if damage_vignette == null:
		return

	var health_ratio: float = 1.0
	if local_player != null and local_player.health_component != null and local_player.health_component.max_health > 0.0:
		health_ratio = local_player.health_component.current_health / local_player.health_component.max_health

	var target_alpha: float = 0.0
	if health_ratio < 0.30:
		vignette_pulse_time += delta * 5.0
		var pulse: float = (sin(vignette_pulse_time) + 1.0) * 0.5
		var urgency: float = 1.0 - (health_ratio / 0.30)
		target_alpha = lerpf(0.35, 0.85, urgency) * lerpf(0.7, 1.0, pulse)

	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - 3.5 * delta)
		target_alpha = maxf(target_alpha, flash_alpha)

	damage_vignette.modulate.a = target_alpha


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
		if local_player.turret_cooldown > 0.0:
			gadget_label.text = "[G] .50 CAL COOLDOWN (%ds)" % int(ceil(local_player.turret_cooldown))
			gadget_label.modulate = Color(0.7, 0.7, 0.7)
		else:
			gadget_label.text = "[G] DEPLOY .50 CAL TRIPOD"
			gadget_label.modulate = Color(0.4, 0.9, 0.5)
	elif local_player.class_id == SGCNetworkManager.CLASS_ONEILL_RECON:
		var has_c4: bool = local_player.active_c4 != null and is_instance_valid(local_player.active_c4)
		if has_c4:
			gadget_label.text = "[G] DETONATE C4 SATCHEL"
			gadget_label.modulate = Color(1.0, 0.4, 0.2)
		elif local_player.c4_charges_remaining > 0:
			gadget_label.text = "[G] THROW C4 (%d LEFT)" % local_player.c4_charges_remaining
			gadget_label.modulate = Color(0.4, 0.9, 0.5)
		else:
			gadget_label.text = "[G] C4 DEPLETED (0/3)"
			gadget_label.modulate = Color(0.7, 0.7, 0.7)
	else:
		gadget_label.text = "[G] TACTICAL SATCHEL"

	# Append Claymore indicator
	var claymore_str := "  |  [3] CLAYMORE (%d/2)" % local_player.claymore_charges
	gadget_label.text += claymore_str


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
	var hostile_type := "JAFFA SHOCK GUARDS" if wave_num == 3 else "JAFFA GUARDS"
	enemies_label.text = "HOSTILES: %d %s" % [enemy_count, hostile_type]
	match wave_num:
		1:
			objective_label.text = "FOOTHOLD IN PROGRESS - REPEL STARGATE RAMP INVASION!"
		2:
			objective_label.text = "FLANKING ASSAULT DETECTED - WATCH TRANSPORT RINGS!"
		3:
			objective_label.text = "⚠️ OVERWHELMING ASSAULT! FALL BACK BEHIND BLAST DOORS & SEAL CHOKE POINT!"
		_:
			objective_label.text = "DEFEND SGC LEVEL 28 - HOLD THE RAMP"


func on_jaffa_count_changed(enemies_remaining: int, wave_num: int) -> void:
	total_kills += 1
	wave_label.text = "WAVE %d / 3" % wave_num
	var hostile_type := "JAFFA SHOCK GUARDS" if wave_num == 3 else "JAFFA GUARDS"
	enemies_label.text = "HOSTILES: %d %s" % [enemies_remaining, hostile_type]


func on_wave_cleared(wave_num: int, intermission_s: float) -> void:
	wave_label.text = "WAVE %d CLEARED!" % wave_num
	enemies_label.text = "HOSTILES ELIMINATED"
	objective_label.text = "INTERMISSION: %.0fs UNTIL NEXT ASSAULT" % intermission_s


func on_all_waves_defeated() -> void:
	wave_label.text = "ALL WAVES CLEARED!"
	enemies_label.text = "SGC LEVEL 28 SECURED"
	objective_label.text = "ALL WAVES CLEARED! SGC LEVEL 28 SECURED! DIAL DHD & OPEN IRIS FOR EXTRACTION!"


# --- DHD Dialing Mini-Game ---
func bind_dhd(dhd: DHDDialer) -> void:
	current_dhd = dhd
	if current_dhd == null:
		return

	if not current_dhd.dialing_engaged.is_connected(_on_dhd_engaged):
		current_dhd.dialing_engaged.connect(_on_dhd_engaged)
		current_dhd.chevron_advanced.connect(_on_chevron_advanced)
		current_dhd.phase_changed.connect(_on_dhd_phase_changed)
		current_dhd.gdo_beat_advanced.connect(_on_gdo_beat_advanced)
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
	if dhd_panel != null:
		dhd_panel.visible = true
	_render_glyphs()


func _on_chevron_advanced(_cur: int, _total: int) -> void:
	_render_glyphs()


func _on_dhd_phase_changed(_new_phase: DHDDialer.DialPhase) -> void:
	_render_glyphs()


func _on_gdo_beat_advanced(_cur_beat: int, _total_beats: int) -> void:
	_render_glyphs()


func _on_gdo_verified() -> void:
	_render_glyphs()


func _on_dhd_completed() -> void:
	if dhd_panel != null:
		dhd_panel.visible = true
	if dhd_title != null:
		dhd_title.text = "IRIS OPENED! STEP THROUGH EVENT HORIZON TO EXTRACT!"
		dhd_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_render_glyphs()
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dhd_panel) and current_dhd != null and current_dhd.current_phase == DHDDialer.DialPhase.COMPLETE:
			dhd_panel.visible = false
	)


func _on_dhd_cancelled() -> void:
	if dhd_panel != null:
		dhd_panel.visible = false


func _render_glyphs() -> void:
	if current_dhd == null or glyph_container == null or dhd_title == null:
		return

	# Immediately remove and free existing glyph buttons to prevent visual stacking
	for child in glyph_container.get_children():
		glyph_container.remove_child(child)
		child.queue_free()

	var arrow_symbols: Dictionary = {
		"UP": "⬆",
		"DOWN": "⬇",
		"LEFT": "⬅",
		"RIGHT": "➡"
	}

	if current_dhd.current_phase == DHDDialer.DialPhase.CHEVRONS:
		dhd_title.text = "SGC DIALING COMPUTER: 7-CHEVRON LOCK SEQUENCE"
		dhd_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
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
		dhd_title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
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
				btn.modulate = Color(1.0, 1.0, 0.2) # Active beat
			else:
				btn.modulate = Color(0.4, 0.4, 0.4) # Upcoming
			glyph_container.add_child(btn)

	elif current_dhd.current_phase == DHDDialer.DialPhase.COMPLETE:
		dhd_title.text = "IRIS OPENED! STEP INTO WORMHOLE TO EXTRACT!"
		dhd_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))


func show_victory() -> void:
	is_mission_ended = true
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = true
	if debrief_title != null:
		debrief_title.text = "EXTRACTION SUCCESSFUL"
		debrief_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_populate_debrief_stats(true)


func show_defeat() -> void:
	is_mission_ended = true
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = true
	if debrief_title != null:
		debrief_title.text = "MISSION FAILED - SGC OVERRUN"
		debrief_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	if debrief_subtitle != null:
		debrief_subtitle.text = "SGC LEVEL 28 BREACHED BY GOA'ULD FORCES"
	_populate_debrief_stats(false)


func _populate_debrief_stats(is_victory: bool) -> void:
	var minutes := int(mission_seconds) / 60
	var seconds := int(mission_seconds) % 60
	if stat_time != null:
		stat_time.text = "MISSION DURATION: %02d:%02d" % [minutes, seconds]
	if stat_kills != null:
		stat_kills.text = "HOSTILES ELIMINATED: %d" % total_kills
	if stat_waves != null:
		stat_waves.text = "WAVES REPELLED: %s" % ("3 / 3" if is_victory else "PARTIAL")
	if stat_chevrons != null:
		stat_chevrons.text = "CHEVRONS LOCKED: %s" % ("7 / 7" if is_victory else "INCOMPLETE")
	if stat_status != null:
		stat_status.text = "STATUS: %s" % ("ALL OPERATIVES EXTRACTED" if is_victory else "SQUAD COMPROMISED")
		stat_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if is_victory else Color(1.0, 0.3, 0.3))
