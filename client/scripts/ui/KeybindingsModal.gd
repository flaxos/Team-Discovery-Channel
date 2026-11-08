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

var CONTROLS_DATA: Dictionary = {}
var binding_buttons: Dictionary = {}
var awaiting_action: String = ""
var pending_event: InputEvent = null
var status_label: Label
var conflict_buttons: HBoxContainer
var capture_armed: bool = false

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

	for action: String in _bindings().ACTIONS:
		var info: Dictionary = _bindings().ACTIONS[action]
		if not CONTROLS_DATA.has(info.category):
			CONTROLS_DATA[info.category] = []
		CONTROLS_DATA[info.category].append({"action": info.label, "key": _bindings().binding_text(action), "id": action})
	_build_ui()
	_build_remapping_controls()
	_bindings().bindings_changed.connect(_refresh_bindings)
	_refresh_bindings()


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
		var row: Control = _create_binding_row(action_text, key_text, idx, item.get("id", ""))
		container.add_child(row)


func _create_binding_row(action_text: String, key_text: String, index: int, action_id: String = "") -> Control:
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

	var badge := Button.new()
	badge.name = "BindingButton"
	badge.text = key_text
	badge.tooltip_text = "Click to replace this action's bindings. ESC cancels."
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.add_theme_color_override("font_color", Color(0.35, 1.0, 0.85))
	badge.add_theme_font_size_override("font_size", 12)
	badge_align.add_child(badge)
	binding_buttons[action_id] = badge
	badge.pressed.connect(begin_capture.bind(action_id))

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
	body.text = "Hold squad command, flick to an order, then release to confirm. Mouse look stays active in TPS and ADS. ESC always cancels input capture or resumes the mission."
	body.add_theme_color_override("font_color", Color(0.70, 0.80, 0.90, 0.85))
	body.add_theme_font_size_override("font_size", 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	return panel


func _build_remapping_controls() -> void:
	var footer: Node = close_button.get_parent() if close_button != null else null
	if footer == null:
		return
	var main_box: Node = footer.get_parent()
	status_label = Label.new()
	status_label.name = "RebindingStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	main_box.add_child(status_label)
	main_box.move_child(status_label, footer.get_index())
	conflict_buttons = HBoxContainer.new()
	conflict_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(conflict_buttons)
	main_box.move_child(conflict_buttons, footer.get_index())
	for choice: String in ["swap", "replace", "cancel"]:
		var button := Button.new()
		button.text = choice.capitalize()
		button.pressed.connect(resolve_conflict.bind(choice))
		conflict_buttons.add_child(button)
	conflict_buttons.hide()
	var reset := Button.new()
	reset.name = "ResetDefaultsButton"
	reset.text = "RESET DEFAULTS"
	reset.pressed.connect(func() -> void:
		cancel_capture()
		var saved: bool = _bindings().reset_defaults()
		status_label.text = "Defaults restored." if saved else _bindings().last_error
	)
	footer.add_child(reset)


func _refresh_bindings() -> void:
	for action: String in binding_buttons:
		var button: Button = binding_buttons[action]
		button.text = _bindings().binding_text(action)
		button.modulate.a = 1.0
	for category: String in CONTROLS_DATA:
		for item: Dictionary in CONTROLS_DATA[category]:
			item.key = _bindings().binding_text(item.id)


func begin_capture(action: String) -> void:
	cancel_capture()
	awaiting_action = action
	binding_buttons[action].text = "PRESS KEY / MOUSE…"
	status_label.text = "Press an input for %s. ESC cancels." % _bindings().ACTIONS[action].label
	# Button.pressed is emitted on mouse release; defer to exclude that event.
	capture_armed = false
	call_deferred("_arm_capture")


func _arm_capture() -> void:
	capture_armed = not awaiting_action.is_empty()


func cancel_capture() -> void:
	awaiting_action = ""
	pending_event = null
	capture_armed = false
	if conflict_buttons != null:
		conflict_buttons.hide()
	_refresh_bindings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_capture()


func _process(_delta: float) -> void:
	if not awaiting_action.is_empty() and binding_buttons.has(awaiting_action):
		binding_buttons[awaiting_action].modulate.a = 0.75 + sin(Time.get_ticks_msec() * 0.008) * 0.25


func _input(event: InputEvent) -> void:
	if not visible or awaiting_action.is_empty():
		return
	if event is InputEventMouseMotion:
		return
	# While resolving a conflict, let GUI buttons receive clicks.
	if pending_event != null:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_capture()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if not capture_armed or not event.is_pressed() or (event is InputEventKey and event.echo):
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		cancel_capture()
		status_label.text = "Binding unchanged."
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	var error: String = _bindings().validate_event(awaiting_action, event)
	if not error.is_empty():
		status_label.text = error
		return
	pending_event = _bindings().decode_event(_bindings().event_data(event))
	var conflicts: Array[String] = _bindings().conflicts_for(awaiting_action, pending_event)
	if not conflicts.is_empty():
		var labels: PackedStringArray = []
		for conflict: String in conflicts:
			labels.append(_bindings().ACTIONS[conflict].label)
		status_label.text = "Already assigned: %s. Swap bindings, replace an alternate, or cancel." % ", ".join(labels)
		conflict_buttons.show()
	else:
		resolve_conflict("replace")


func resolve_conflict(choice: String) -> void:
	if choice == "cancel":
		cancel_capture()
		status_label.text = "Binding unchanged."
		return
	if pending_event == null:
		return
	if _bindings().rebind(awaiting_action, pending_event, choice):
		cancel_capture()
		status_label.text = "Binding saved."
	else:
		status_label.text = _bindings().last_error
		pending_event = null
		conflict_buttons.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	var escape: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	if escape or event.is_action_pressed("toggle_pause"):
		close_modal(animate_transitions)
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	close_modal(animate_transitions)


func open_modal(animated: bool = true) -> void:
	cancel_capture()
	_bindings().release_all()
	if status_label != null:
		status_label.text = "Click a binding to change it. ESC cancels / resumes."
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
	cancel_capture()
	_bindings().release_all()
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


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
