class_name TacticalHUD
extends CanvasLayer
## In-game Tactical HUD for Project SGC.
## Displays operative vitals, weapon ammo, wave status, Helldivers-style DHD chords, and extraction victory.

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")

class CrosshairControl extends Control:
	var hud: TacticalHUD = null

	func _draw() -> void:
		if hud != null:
			hud._draw_crosshair(self)

# Node References
@onready var health_bar: ProgressBar = $VitalsPanel/VBox/HealthBar
@onready var health_label: Label = $VitalsPanel/VBox/HealthBar/HealthLabel
@onready var operative_label: Label = $VitalsPanel/VBox/OperativeLabel
@onready var stun_label: Label = $VitalsPanel/VBox/StunLabel

@onready var ammo_panel: PanelContainer = $AmmoPanel if has_node("AmmoPanel") else null
@onready var weapon_name_label: Label = $AmmoPanel/VBox/WeaponNameLabel
@onready var ammo_label: Label = $AmmoPanel/VBox/AmmoLabel
@onready var slot_label: Label = $AmmoPanel/VBox/SlotLabel
@onready var gadget_label: Label = $AmmoPanel/VBox/GadgetLabel

@onready var heat_container: VBoxContainer = $AmmoPanel/VBox/HeatContainer if has_node("AmmoPanel/VBox/HeatContainer") else null
@onready var heat_bar: ProgressBar = $AmmoPanel/VBox/HeatContainer/HeatBar if has_node("AmmoPanel/VBox/HeatContainer/HeatBar") else null
@onready var heat_label: Label = $AmmoPanel/VBox/HeatContainer/HeatBar/HeatLabel if has_node("AmmoPanel/VBox/HeatContainer/HeatBar/HeatLabel") else null
@onready var heat_warning_label: Label = $AmmoPanel/VBox/HeatContainer/HeatWarningLabel if has_node("AmmoPanel/VBox/HeatContainer/HeatWarningLabel") else null
@onready var crosshair_overlay: Control = $CrosshairOverlay if has_node("CrosshairOverlay") else null

@onready var wave_label: Label = $TopBanner/VBox/WaveLabel
@onready var enemies_label: Label = $TopBanner/VBox/EnemiesLabel
@onready var objective_label: Label = $TopBanner/VBox/ObjectiveLabel

@onready var dhd_panel: PanelContainer = $DHDPanel
@onready var dhd_title: Label = $DHDPanel/VBox/DHDTitle
@onready var glyph_container: HBoxContainer = $DHDPanel/VBox/GlyphContainer

@onready var victory_modal: PanelContainer = $VictoryModal
@onready var restart_btn: Button = $VictoryModal/VBox/RestartBtn if has_node("VictoryModal/VBox/RestartBtn") else null
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
@onready var pause_restart_btn: Button = $PauseMenu/VBox/RestartBtn if has_node("PauseMenu/VBox/RestartBtn") else null
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
var current_sector_id: String = ""
var vignette_pulse_time: float = 0.0
var flash_alpha: float = 0.0
var mission_seconds: float = 0.0
var total_kills: int = 0
var is_mission_ended: bool = false

# Crosshair and Heat Gauge Variables
var crosshair_override_pos: Vector2 = Vector2.ZERO
var crosshair_color: Color = Color(0.2, 0.95, 1.0, 0.9)
var crosshair_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.6)
var current_bound_weapon: WeaponBase = null
var heat_pulse_time: float = 0.0


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

	# Tactical 4-Pip Crosshair Overlay initialization
	if crosshair_overlay == null:
		var cho := CrosshairControl.new()
		cho.name = "CrosshairOverlay"
		cho.hud = self
		cho.set_anchors_preset(Control.PRESET_FULL_RECT)
		cho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cho)
		crosshair_overlay = cho
	else:
		crosshair_overlay.set_script(CrosshairControl)
		(crosshair_overlay as CrosshairControl).hud = self

	# Energy Weapon Heat Gauge initialization
	_ensure_heat_ui_exists()
	if heat_container != null:
		heat_container.visible = false

	objective_label.text = "DEFEND SGC LEVEL 28 - HOLD THE RAMP"

	if restart_btn != null:
		restart_btn.pressed.connect(_on_restart_pressed)
	if return_btn != null:
		return_btn.pressed.connect(_on_return_pressed)
	if resume_btn != null:
		resume_btn.pressed.connect(toggle_pause_menu)
	if pause_restart_btn != null:
		pause_restart_btn.pressed.connect(_on_restart_pressed)
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
	if pause_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if local_player != null and local_player.is_aiming_down_sights:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


func _on_restart_pressed() -> void:
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = false
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_mission_ended = false
	var err := get_tree().reload_current_scene()
	if err != OK or get_tree().current_scene == null or get_tree().current_scene.scene_file_path == "":
		get_tree().change_scene_to_file("res://scenes/main/GateRoom.tscn")


func _on_return_pressed() -> void:
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = false
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_mission_ended = false
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.disconnect_game()
	var err := get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	if err != OK:
		get_tree().change_scene_to_file("res://scenes/main/Lobby.tscn")


func update_sector_display(sector_id: String) -> void:
	current_sector_id = sector_id
	if operative_label != null and local_player != null:
		var class_names: Dictionary = {
			SGCNetworkManager.CLASS_SG3_HEAVY: "SG-3 HEAVY",
			SGCNetworkManager.CLASS_CARTER_TECH: "TECH (CARTER)",
			SGCNetworkManager.CLASS_ONEILL_RECON: "RECON (O'NEILL)",
			SGCNetworkManager.CLASS_TEALC_JAFFA: "JAFFA (TEAL'C)"
		}
		var c_name: String = class_names.get(local_player.class_id, "OPERATIVE")
		var sec_name: String = sector_id.replace("_", " ")
		operative_label.text = "%s [%s] • %s" % [local_player.player_callsign, c_name, sec_name]


func bind_local_player(player: PlayerController3D) -> void:
	local_player = player
	if local_player == null or not is_inside_tree() or operative_label == null:
		return

	# Operative profile
	var class_names: Dictionary = {
		SGCNetworkManager.CLASS_SG3_HEAVY: "SG-3 HEAVY SUPPORT",
		SGCNetworkManager.CLASS_CARTER_TECH: "TECH SPECIALIST (CARTER)",
		SGCNetworkManager.CLASS_ONEILL_RECON: "POINTMAN RECON (O'NEILL)",
		SGCNetworkManager.CLASS_TEALC_JAFFA: "ALLIED JAFFA (TEAL'C)"
	}
	var c_name: String = class_names.get(player.class_id, "SGC OPERATIVE")
	if current_sector_id != "":
		operative_label.text = "%s [%s] • %s" % [player.player_callsign, c_name, current_sector_id.replace("_", " ")]
	else:
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
	if not player.player_died.is_connected(_on_local_player_died):
		player.player_died.connect(_on_local_player_died)
	if not player.revive_progress_changed.is_connected(_on_revive_progress_changed):
		player.revive_progress_changed.connect(_on_revive_progress_changed)

	# Active weapon
	_update_weapon_display()


func _process(delta: float) -> void:
	if not is_mission_ended:
		mission_seconds += delta
	heat_pulse_time += delta * 6.0
	if local_player != null:
		if operative_label != null and (operative_label.text == "" or operative_label.text.begins_with("OPERATIVE [")):
			bind_local_player(local_player)
		_update_weapon_display()
	_update_damage_vignette(delta)
	if crosshair_overlay != null:
		crosshair_overlay.queue_redraw()


func _on_health_downed() -> void:
	if local_player != null:
		_on_local_player_downed(local_player.peer_id)


func _on_health_revived() -> void:
	if local_player != null:
		_on_local_player_revived(local_player.peer_id)


func _on_local_player_died(pid: int) -> void:
	var gateroom := get_tree().root.find_child("GateRoom", true, false)
	if gateroom != null and gateroom.has_method("_check_squad_status"):
		gateroom.call_deferred("_check_squad_status", pid)
	elif not is_mission_ended:
		show_defeat()


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

	if weapon.uses_heat:
		if heat_container != null:
			heat_container.visible = true
		_bind_energy_weapon(weapon)
		_update_heat_gauge(weapon)
		if weapon.is_overheated:
			ammo_label.text = "VENTING..."
			ammo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			ammo_label.text = "%d%% HEAT" % int(weapon.current_heat)
			ammo_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2) if (weapon.is_plasma or weapon.weapon_id == "staff_weapon") else Color(0.3, 0.85, 1.0))
	else:
		if heat_container != null:
			heat_container.visible = false
		ammo_label.add_theme_color_override("font_color", Color.WHITE)
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


func _ensure_heat_ui_exists() -> void:
	if heat_container != null:
		return
	if ammo_panel == null:
		return
	var vbox := ammo_panel.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return

	heat_container = VBoxContainer.new()
	heat_container.name = "HeatContainer"
	heat_container.visible = false
	heat_container.add_theme_constant_override("separation", 2)

	if gadget_label != null:
		vbox.add_child(heat_container)
		vbox.move_child(heat_container, gadget_label.get_index())
	else:
		vbox.add_child(heat_container)

	heat_bar = ProgressBar.new()
	heat_bar.name = "HeatBar"
	heat_bar.custom_minimum_size = Vector2(0, 16)
	heat_bar.max_value = 100.0
	heat_bar.value = 0.0
	heat_bar.show_percentage = false
	heat_container.add_child(heat_bar)

	heat_label = Label.new()
	heat_label.name = "HeatLabel"
	heat_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	heat_label.text = "HEAT: 0%"
	heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heat_label.add_theme_font_size_override("font_size", 11)
	heat_bar.add_child(heat_label)

	heat_warning_label = Label.new()
	heat_warning_label.name = "HeatWarningLabel"
	heat_warning_label.text = "OVERHEATING / VENTING..."
	heat_warning_label.visible = false
	heat_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_warning_label.add_theme_font_size_override("font_size", 11)
	heat_warning_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	heat_container.add_child(heat_warning_label)


func _bind_energy_weapon(weapon: WeaponBase) -> void:
	if current_bound_weapon == weapon:
		return
	if current_bound_weapon != null and is_instance_valid(current_bound_weapon):
		if current_bound_weapon.heat_changed.is_connected(_on_weapon_heat_changed):
			current_bound_weapon.heat_changed.disconnect(_on_weapon_heat_changed)
	current_bound_weapon = weapon
	if weapon != null and weapon.uses_heat:
		if not weapon.heat_changed.is_connected(_on_weapon_heat_changed):
			weapon.heat_changed.connect(_on_weapon_heat_changed)


func _on_weapon_heat_changed(cur_heat: float, overheated: bool) -> void:
	if current_bound_weapon != null:
		_apply_heat_state(cur_heat, overheated, current_bound_weapon)


func _update_heat_gauge(weapon: WeaponBase) -> void:
	_apply_heat_state(weapon.current_heat, weapon.is_overheated, weapon)


func _apply_heat_state(cur_heat: float, overheated: bool, weapon: WeaponBase) -> void:
	if heat_bar != null:
		heat_bar.max_value = 100.0
		heat_bar.value = cur_heat

		# Authentic orange (Staff) or blue (Zat) heat meter
		var fill_sb: StyleBoxFlat = null
		if heat_bar.has_theme_stylebox_override("fill"):
			fill_sb = heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		elif heat_bar.has_theme_stylebox("fill"):
			fill_sb = heat_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		if fill_sb == null:
			fill_sb = StyleBoxFlat.new()
			fill_sb.corner_radius_top_left = 4
			fill_sb.corner_radius_top_right = 4
			fill_sb.corner_radius_bottom_right = 4
			fill_sb.corner_radius_bottom_left = 4

		if weapon.is_zat or weapon.weapon_id == "zat":
			# Electric Goa'uld blue arc
			var base_blue := Color(0.2, 0.75, 1.0, 1.0)
			fill_sb.bg_color = base_blue.lerp(Color(0.55, 0.35, 1.0, 1.0), cur_heat / 100.0)
		else:
			# Liquid Naquadah fiery orange plasma
			var base_orange := Color(1.0, 0.55, 0.1, 1.0)
			fill_sb.bg_color = base_orange.lerp(Color(1.0, 0.2, 0.08, 1.0), cur_heat / 100.0)

		heat_bar.add_theme_stylebox_override("fill", fill_sb)

	if heat_label != null:
		heat_label.text = "HEAT: %d%%" % int(cur_heat)

	if heat_warning_label != null:
		if overheated:
			heat_warning_label.visible = true
			heat_warning_label.text = "OVERHEATING / VENTING..."
			var flash_bright: bool = (int(heat_pulse_time) % 2) == 0
			heat_warning_label.modulate = Color(1.0, 0.15, 0.15, 1.0) if flash_bright else Color(1.0, 0.55, 0.55, 0.3)
		else:
			heat_warning_label.visible = false


## Computes current operative stance multiplier for spread & crosshair calculation.
func get_stance_multiplier() -> float:
	if local_player == null:
		return 1.0

	# 1. Mounted on .50 cal tripod / deployed: 99% laser accuracy pinpoint
	if local_player.mounted_turret != null and is_instance_valid(local_player.mounted_turret):
		return 0.01

	var mult: float = 1.0

	# ADS precision zoom
	if local_player.is_aiming_down_sights:
		mult *= 0.5

	# Crouched stance vs moving stance
	if local_player.is_crouching:
		mult *= 0.5
	elif local_player.velocity.length() > 2.0:
		# Moving / running penalty
		mult *= 1.8
	else:
		# Standing still: crisp close cluster
		mult *= 0.75

	return mult


func get_current_weapon_spread() -> float:
	if local_player != null and local_player.current_weapon != null:
		return local_player.current_weapon.current_spread_deg
	return 2.0


func get_effective_spread() -> float:
	return get_current_weapon_spread() * get_stance_multiplier()


func get_crosshair_gap() -> float:
	var eff_spread: float = get_effective_spread()
	var is_mounted: bool = (local_player != null and local_player.mounted_turret != null and is_instance_valid(local_player.mounted_turret))
	if is_mounted or eff_spread < 0.1:
		return 2.0
	# Proportional to current_spread_deg * stance_multiplier
	return clampf(eff_spread * 6.0, 2.0, 120.0)


func _draw() -> void:
	if crosshair_overlay != null:
		crosshair_overlay.queue_redraw()


func _draw_crosshair(ci: Control) -> void:
	if ci == null or not is_inside_tree() or is_mission_ended:
		return
	if pause_menu != null and pause_menu.visible:
		return
	if local_player != null and local_player.health_component != null and local_player.health_component.is_dead:
		return

	var v_size: Vector2 = ci.get_viewport_rect().size
	if v_size == Vector2.ZERO:
		v_size = Vector2(1280, 720)

	var aim_pos: Vector2 = Vector2.ZERO
	if crosshair_override_pos != Vector2.ZERO:
		aim_pos = crosshair_override_pos
	elif local_player != null and local_player.is_aiming_down_sights:
		aim_pos = v_size * 0.5
	elif local_player != null and local_player.camera != null and local_player.current_aim_target != Vector3.ZERO:
		if not local_player.camera.is_position_behind(local_player.current_aim_target):
			aim_pos = local_player.camera.unproject_position(local_player.current_aim_target)
		else:
			aim_pos = ci.get_viewport().get_mouse_position()
	else:
		aim_pos = ci.get_viewport().get_mouse_position()

	if aim_pos == Vector2.ZERO or aim_pos.x < 0.0 or aim_pos.y < 0.0 or aim_pos.x > v_size.x or aim_pos.y > v_size.y:
		aim_pos = v_size * 0.5

	var is_mounted: bool = (local_player != null and local_player.mounted_turret != null and is_instance_valid(local_player.mounted_turret))
	var gap: float = get_crosshair_gap()
	var pip_len: float = 3.0 if is_mounted else 7.0
	var pip_width: float = 2.0

	var draw_col: Color = crosshair_color
	if is_mounted:
		# Laser pinpoint accuracy indicator
		draw_col = Color(0.2, 1.0, 0.45, 0.95)

	# 1. Center pinpoint dot
	ci.draw_circle(aim_pos, 1.5, draw_col)

	# 2. Render 4 pips: Top, Bottom, Left, Right around center/aim target
	# Top pip
	ci.draw_line(Vector2(aim_pos.x, aim_pos.y - gap - pip_len), Vector2(aim_pos.x, aim_pos.y - gap), crosshair_shadow_color, pip_width + 2.0)
	ci.draw_line(Vector2(aim_pos.x, aim_pos.y - gap - pip_len), Vector2(aim_pos.x, aim_pos.y - gap), draw_col, pip_width)

	# Bottom pip
	ci.draw_line(Vector2(aim_pos.x, aim_pos.y + gap), Vector2(aim_pos.x, aim_pos.y + gap + pip_len), crosshair_shadow_color, pip_width + 2.0)
	ci.draw_line(Vector2(aim_pos.x, aim_pos.y + gap), Vector2(aim_pos.x, aim_pos.y + gap + pip_len), draw_col, pip_width)

	# Left pip
	ci.draw_line(Vector2(aim_pos.x - gap - pip_len, aim_pos.y), Vector2(aim_pos.x - gap, aim_pos.y), crosshair_shadow_color, pip_width + 2.0)
	ci.draw_line(Vector2(aim_pos.x - gap - pip_len, aim_pos.y), Vector2(aim_pos.x - gap, aim_pos.y), draw_col, pip_width)

	# Right pip
	ci.draw_line(Vector2(aim_pos.x + gap, aim_pos.y), Vector2(aim_pos.x + gap + pip_len, aim_pos.y), crosshair_shadow_color, pip_width + 2.0)
	ci.draw_line(Vector2(aim_pos.x + gap, aim_pos.y), Vector2(aim_pos.x + gap + pip_len, aim_pos.y), draw_col, pip_width)


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
	wave_label.text = "WAVE %d / 4" % wave_num if wave_num == 4 else "WAVE %d / 3" % wave_num
	var hostile_type := "JAFFA SHOCK GUARDS" if (wave_num == 3 or wave_num == 4) else "JAFFA GUARDS"
	enemies_label.text = "HOSTILES: %d %s" % [enemy_count, hostile_type]
	match wave_num:
		1:
			objective_label.text = "FOOTHOLD IN PROGRESS - REPEL STARGATE RAMP INVASION!"
		2:
			objective_label.text = "FLANKING ASSAULT DETECTED - WATCH TRANSPORT RINGS!"
		3:
			objective_label.text = "⚠️ OVERWHELMING ASSAULT! FALL BACK BEHIND BLAST DOORS & SEAL CHOKE POINT!"
		4:
			objective_label.text = "🚨 MULTI-SECTOR CLIMAX INCURSION! DEFEND GATE ROOM, ARMORY & LEVEL 27!"
		_:
			objective_label.text = "DEFEND SGC LEVEL 28 - HOLD THE RAMP"


func on_jaffa_count_changed(enemies_remaining: int, wave_num: int) -> void:
	total_kills += 1
	wave_label.text = "WAVE %d / 4" % wave_num if wave_num == 4 else "WAVE %d / 3" % wave_num
	var hostile_type := "JAFFA SHOCK GUARDS" if (wave_num == 3 or wave_num == 4) else "JAFFA GUARDS"
	enemies_label.text = "HOSTILES: %d %s" % [enemies_remaining, hostile_type]


func on_wave_cleared(wave_num: int, intermission_s: float) -> void:
	wave_label.text = "WAVE %d CLEARED!" % wave_num
	enemies_label.text = "HOSTILES ELIMINATED"
	objective_label.text = "INTERMISSION: %.0fs UNTIL NEXT ASSAULT" % intermission_s


func on_all_waves_defeated() -> void:
	wave_label.text = "ALL WAVES CLEARED!"
	enemies_label.text = "SGC LEVEL 28 SECURED"
	objective_label.text = "ALL WAVES CLEARED! SGC LEVEL 28 SECURED! DIAL DHD & OPEN IRIS FOR EXTRACTION!"


func on_wormhole_timer_tick(seconds_left: float, _total_duration: float) -> void:
	if objective_label != null:
		var mins := int(seconds_left) / 60
		var secs := int(seconds_left) % 60
		objective_label.text = "INBOUND WORMHOLE: %02d:%02d [IRIS JAMMED OPEN] - HOLD GATE ROOM!" % [mins, secs]
		objective_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))


func on_intermission_tick(seconds_left: int) -> void:
	if objective_label != null:
		var mins := seconds_left / 60
		var secs := seconds_left % 60
		objective_label.text = "INTER-GATE RECHARGE: %02d:%02d - RESUPPLY AT ARMORY & HOLD CORRIDORS" % [mins, secs]
		objective_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))


func on_iris_malfunction() -> void:
	if wave_label != null:
		wave_label.text = "RED ALERT: IRIS MALFUNCTION!"
		wave_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	if objective_label != null:
		objective_label.text = "UNAUTHORIZED INCOMING WORMHOLE! TRINIUM IRIS JAMMED AT 0%!"


func update_iris_repair_stage(completed: int, stage_name: String, total_progress: float) -> void:
	if objective_label != null:
		var percent := int(round(total_progress * 100.0))
		if completed >= 3:
			objective_label.text = "TRINIUM IRIS SECURED (100%) - HOSTILE BREACH BLOCKED!"
			objective_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			objective_label.text = "IRIS REPAIR [%d/3 SAVED] (%d%%): %s" % [completed, percent, stage_name.to_upper()]
			objective_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))


func update_objective(text: String, color: Color = Color.WHITE) -> void:
	if objective_label != null:
		objective_label.text = text
		objective_label.add_theme_color_override("font_color", color)


func on_lab_patch_objective_started() -> void:
	if wave_label != null:
		wave_label.text = "DIALING BUFFER LOCKED!"
		wave_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	if objective_label != null:
		objective_label.text = "GOA'ULD VIRUS DETECTED! RETRIEVE CLEAN DIALING ROM FROM LEVEL 28 LAB!"
		objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


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

	var sgc := current_dhd as SGCDialingConsoleScript
	if sgc != null:
		if not sgc.buffer_lockout_triggered.is_connected(_on_buffer_lockout):
			sgc.buffer_lockout_triggered.connect(_on_buffer_lockout)
			sgc.patch_upload_progress.connect(_on_patch_progress)
			sgc.buffer_restored.connect(_on_buffer_restored)


func _on_buffer_lockout() -> void:
	if dhd_panel != null:
		dhd_panel.visible = true
	if dhd_title != null:
		dhd_title.text = "⚠️ BUFFER LOCKOUT: RETRIEVE CLEAN ROM FROM LAB ⚠️"
		dhd_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))


func _on_patch_progress(progress: float) -> void:
	if dhd_panel != null:
		dhd_panel.visible = true
	if dhd_title != null:
		dhd_title.text = "UPLOADING CLEAN DIALING ROM: %d%%" % int(progress * 100)
		dhd_title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))


func _on_buffer_restored() -> void:
	if dhd_title != null:
		dhd_title.text = "SGC DIALING COMPUTER READY - DIAL OUTBOUND"
		dhd_title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = true
	if debrief_title != null:
		debrief_title.text = "EXTRACTION SUCCESSFUL"
		debrief_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	if debrief_subtitle != null:
		debrief_subtitle.text = "SGC AFTER ACTION DEBRIEFING REPORT"
	if restart_btn != null:
		restart_btn.text = "RETRY MISSION"
	if return_btn != null:
		return_btn.text = "RETURN TO SGC BRIEFING"
	_populate_debrief_stats(true)


func show_defeat() -> void:
	is_mission_ended = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_menu != null:
		pause_menu.visible = false
	if victory_modal != null:
		victory_modal.visible = true
	if debrief_title != null:
		debrief_title.text = "MISSION FAILED - SGC OVERRUN"
		debrief_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	if debrief_subtitle != null:
		debrief_subtitle.text = "SGC LEVEL 28 BREACHED BY GOA'ULD FORCES"
	if restart_btn != null:
		restart_btn.text = "RETRY MISSION"
	if return_btn != null:
		return_btn.text = "RETURN TO SGC BRIEFING"
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
