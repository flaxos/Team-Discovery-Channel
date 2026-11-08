class_name KeybindingsModal
extends Control
## SGC Cheyenne Mountain Tactical Field Manual & Keybindings Terminal.
## Displays categorized tactical combat, movement, squad, and camera controls
## with an authentic NORAD/Cheyenne Mountain phosphor CRT aesthetic.

signal closed

const HEADER_TITLE: String = "CHEYENNE MOUNTAIN COMPLEX // TACTICAL FIELD MANUAL & CONTROLS"
const CLOSE_BUTTON_TEXT: String = "[ CLOSE / RESUME MISSION ]"

const CATEGORY_COMBAT: String = "COMBAT & WEAPON CONTROLS"
const CATEGORY_MOVEMENT: String = "MOVEMENT & STANCE CONTROLS"
const CATEGORY_SQUAD: String = "SQUAD TACTICS & CAMERA CONTROLS"

const CONTROLS_DATA: Dictionary = {
	CATEGORY_COMBAT: [
		{"action": "Aim Down Sights (ADS / Wildlands Shoulder View)", "key": "[Right Mouse Button (Hold)]"},
		{"action": "Fire Primary / Sidearm", "key": "[Left Mouse Button]"},
		{"action": "Reload Weapon", "key": "[R]"},
		{"action": "Switch Primary / Secondary", "key": "[1] / [2]"},
		{"action": "Deploy Ballistic Shield", "key": "[4]"},
		{"action": "Throw M18 Smoke Grenade", "key": "[5]"},
		{"action": "Tactical C4 Timer Mode (Remote / 5s / 10s / 30s)", "key": "[T]"},
		{"action": "Deploy .50 Cal Tripod", "key": "[G]"},
	],
	CATEGORY_MOVEMENT: [
		{"action": "Move Operative", "key": "[W] [A] [S] [D]"},
		{"action": "Toggle Crouch / Duck Behind Cover", "key": "[C]"},
		{"action": "Tactical Sprint", "key": "[Shift (Hold)]"},
		{"action": "Drag Downed Ally / Corpse", "key": "[G (Hold near body)]"},
		{"action": "Interact / Mount .50 Cal / Repair Iris / Re-Armor", "key": "[E]"},
	],
	CATEGORY_SQUAD: [
		{"action": "Squad Command Radial Wheel", "key": "[Q] or [Mouse 4 (Hold)]"},
		{"action": "Quick Squad Context Ping", "key": "[Q] or [Middle Mouse (Tap)]"},
		{"action": "360 Tactical Orbit / Camera Pan", "key": "[Middle Mouse + Drag] or [Alt + Mouse]"},
		{"action": "Field Manual / Pause Menu", "key": "[ESC] or [F1]"},
	],
}

@onready var backdrop: ColorRect = %Backdrop if has_node("%Backdrop") else null
@onready var terminal_panel: PanelContainer = %TerminalPanel if has_node("%TerminalPanel") else null
@onready var title_label: Label = %TitleLabel if has_node("%TitleLabel") else null
@onready var combat_container: VBoxContainer = %CombatContainer if has_node("%CombatContainer") else null
@onready var movement_container: VBoxContainer = %MovementContainer if has_node("%MovementContainer") else null
@onready var squad_container: VBoxContainer = %SquadContainer if has_node("%SquadContainer") else null
@onready var close_button: Button = %CloseButton if has_node("%CloseButton") else null

var is_modal_open: bool = false
var animate_transitions: bool = true
var _fade_tween: Tween = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		animate_transitions = false

	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	if title_label != null:
		title_label.text = HEADER_TITLE

	_build_ui()


func _build_ui() -> void:
	if combat_container != null and combat_container.get_child_count() == 0:
		_populate_category(combat_container, CATEGORY_COMBAT)

	if movement_container != null and movement_container.get_child_count() == 0:
		_populate_category(movement_container, CATEGORY_MOVEMENT)

	if squad_container != null and squad_container.get_child_count() == 0:
		_populate_category(squad_container, CATEGORY_SQUAD)
		var directive := _create_directive_panel()
		squad_container.add_child(directive)


func _populate_category(container: VBoxContainer, category_name: String) -> void:
	var items: Array = CONTROLS_DATA.get(category_name, [])
	for idx: int in range(items.size()):
		var item: Dictionary = items[idx]
		var action_text: String = item.get("action", "")
		var key_text: String = item.get("key", "")
		var row: Control = _create_binding_row(action_text, key_text, idx)
		container.add_child(row)


func _create_binding_row(action_text: String, key_text: String, index: int) -> Control:
	var row := PanelContainer.new()
	row.name = "BindingRow_%d" % index
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.12, 0.15, 0.75)
	row_style.border_width_left = 3
	row_style.border_color = Color(0.18, 0.85, 0.65, 0.5)
	row_style.content_margin_left = 10.0
	row_style.content_margin_top = 6.0
	row_style.content_margin_right = 10.0
	row_style.content_margin_bottom = 6.0
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_right = 3
	row_style.corner_radius_bottom_left = 3
	row.add_theme_stylebox_override("panel", row_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var action_label := Label.new()
	action_label.name = "ActionLabel"
	action_label.text = action_text
	action_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98, 1.0))
	action_label.add_theme_font_size_override("font_size", 12)
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(action_label)

	var badge_align := HBoxContainer.new()
	badge_align.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(badge_align)

	var badge := PanelContainer.new()
	badge.name = "KeyBadge"
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.20, 0.22, 0.95)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.25, 0.9, 0.75, 0.8)
	badge_style.content_margin_left = 8.0
	badge_style.content_margin_top = 3.0
	badge_style.content_margin_right = 8.0
	badge_style.content_margin_bottom = 3.0
	badge_style.corner_radius_top_left = 3
	badge_style.corner_radius_top_right = 3
	badge_style.corner_radius_bottom_right = 3
	badge_style.corner_radius_bottom_left = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	badge_align.add_child(badge)

	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.text = key_text
	key_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.85, 1.0))
	key_label.add_theme_font_size_override("font_size", 11)
	badge.add_child(key_label)

	return row


func _create_directive_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "DirectivePanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.10, 0.13, 0.85)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.75, 0.85, 0.6)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 8.0
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "DirectiveTitle"
	title.text = "CHEYENNE MOUNTAIN TACTICAL DIRECTIVE:"
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.95))
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	var body := Label.new()
	body.name = "DirectiveBody"
	body.text = "• Maintain continuous 360° situational awareness.\n• Coordinate squad focus-fire with Radial Wheel [Q].\n• Deploy Ballistic Shield [4] & Smoke [5] during Iris breach.\n• Press [ESC] or [F1] to return to active combat."
	body.add_theme_color_override("font_color", Color(0.70, 0.80, 0.90, 0.85))
	body.add_theme_font_size_override("font_size", 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	return panel


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_F1:
				close_modal(animate_transitions)
				get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	close_modal(animate_transitions)


func open_modal(animated: bool = true) -> void:
	is_modal_open = true
	visible = true

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if animated and animate_transitions and is_inside_tree():
		modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0


func close_modal(animated: bool = true) -> void:
	is_modal_open = false

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if animated and animate_transitions and is_inside_tree():
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fade_tween.tween_callback(func() -> void:
			visible = false
			closed.emit()
		)
	else:
		modulate.a = 0.0
		visible = false
		closed.emit()


# Query helpers for testing and external UI inspection
func get_categories() -> Array[String]:
	var list: Array[String] = []
	for k: String in CONTROLS_DATA.keys():
		list.append(k)
	return list


func get_bindings_for_category(category_name: String) -> Array:
	return CONTROLS_DATA.get(category_name, [])


func get_action_names(category_name: String) -> Array[String]:
	var list: Array[String] = []
	var entries: Array = CONTROLS_DATA.get(category_name, [])
	for entry: Dictionary in entries:
		list.append(entry.get("action", ""))
	return list


func get_key_labels(category_name: String) -> Array[String]:
	var list: Array[String] = []
	var entries: Array = CONTROLS_DATA.get(category_name, [])
	for entry: Dictionary in entries:
		list.append(entry.get("key", ""))
	return list
