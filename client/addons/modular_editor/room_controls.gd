@tool
extends HFlowContainer
signal edit_requested(candidate: LevelLayout, title: String)
const Model = preload("model.gd")
var model: Model
var canvas: Control
var role_picker: OptionButton
var attachment_picker: OptionButton
var position_fields: Array[SpinBox] = []
var yaw: SpinBox
var disabled: CheckBox
var access_id: LineEdit
var locked: CheckBox


func _ready() -> void:
	var label := Label.new()
	label.text = "Room preset"
	add_child(label)
	role_picker = OptionButton.new()
	role_picker.add_item("None")
	role_picker.set_item_metadata(0, "")
	for id: String in LevelPresetCatalogue.PRESETS:
		role_picker.add_item(LevelPresetCatalogue.preset(id).label)
		role_picker.set_item_metadata(role_picker.item_count - 1, id)
	add_child(role_picker)
	button("Apply preset", apply_preset)
	attachment_picker = OptionButton.new()
	attachment_picker.custom_minimum_size.x = 140
	attachment_picker.item_selected.connect(show_attachment)
	add_child(attachment_picker)
	for axis: String in ["X", "Y", "Z"]:
		var field := SpinBox.new()
		field.min_value = -1000
		field.max_value = 1000
		field.step = .1
		field.prefix = axis
		field.suffix = "m"
		field.custom_minimum_size.x = 95
		add_child(field)
		position_fields.append(field)
	yaw = SpinBox.new()
	yaw.min_value = -360
	yaw.max_value = 360
	yaw.step = 90
	yaw.prefix = "Yaw"
	add_child(yaw)
	disabled = CheckBox.new()
	disabled.text = "Disable"
	add_child(disabled)
	button("Apply attachment", apply_attachment)
	button("Use default", reset_attachment)
	access_id = LineEdit.new()
	access_id.placeholder_text = "Security access ID"
	access_id.custom_minimum_size.x = 160
	add_child(access_id)
	locked = CheckBox.new()
	locked.text = "Initially locked"
	add_child(locked)
	button("Apply door access", apply_access)


func button(title: String, callback: Callable) -> void:
	var node := Button.new()
	node.text = title
	node.pressed.connect(callback)
	add_child(node)


func refresh() -> void:
	if role_picker == null:
		return
	var item := model.layout.instance(canvas.selected)
	var chosen := 0
	for i in range(1, role_picker.item_count):
		var id := str(role_picker.get_item_metadata(i))
		var preset := LevelPresetCatalogue.preset(id)
		role_picker.set_item_disabled(
			i, item == null or not str(item.module.id) in preset.compatible_modules
		)
		if item != null and item.room_preset != null and item.room_preset.id == StringName(id):
			chosen = i
	role_picker.select(chosen)
	var old := (
		attachment_picker.get_item_text(attachment_picker.selected)
		if attachment_picker.selected >= 0
		else ""
	)
	attachment_picker.clear()
	if item != null and item.room_preset != null:
		for attachment in item.room_preset.attachments:
			attachment_picker.add_item(str(attachment.id))
			if str(attachment.id) == old:
				attachment_picker.select(attachment_picker.item_count - 1)
	if attachment_picker.item_count > 0:
		show_attachment(attachment_picker.selected)
	access_id.text = ""
	locked.button_pressed = false
	if (
		canvas.selected_connection >= 0
		and canvas.selected_connection < model.layout.connections.size()
	):
		var edge := model.layout.connections[canvas.selected_connection]
		access_id.text = str(edge.security_id)
		locked.button_pressed = edge.initially_locked


func show_attachment(index: int) -> void:
	var item := model.layout.instance(canvas.selected)
	if item == null or item.room_preset == null or index < 0:
		return
	var attachment := item.room_preset.attachments[index]
	var pose := attachment.local_transform
	disabled.button_pressed = false
	for override in item.attachment_overrides:
		if override.id == attachment.id:
			pose = override.local_transform
			disabled.button_pressed = override.disabled
	for i in range(3):
		position_fields[i].set_value_no_signal(pose.origin[i])
	yaw.set_value_no_signal(rad_to_deg(pose.basis.get_euler().y))
	attachment_picker.tooltip_text = (
		"Local to equipment anchor: " + str(attachment.anchor)
		if attachment.anchor != &""
		else "Local to module origin"
	)
	disabled.tooltip_text = (
		"Required attachments cannot be disabled" if attachment.required else "Optional attachment"
	)


func apply_preset() -> void:
	if model.layout.instance(canvas.selected) == null:
		return
	var id := str(role_picker.get_item_metadata(role_picker.selected))
	edit_requested.emit(
		model.configured(canvas.selected, LevelPresetCatalogue.preset(id) if id != "" else null),
		"Change room preset"
	)


func apply_attachment() -> void:
	if attachment_picker.selected < 0:
		return
	var pose := Transform3D(
		Basis(Vector3.UP, deg_to_rad(yaw.value)),
		Vector3(position_fields[0].value, position_fields[1].value, position_fields[2].value)
	)
	edit_requested.emit(
		model.attachment_changed(
			canvas.selected,
			StringName(attachment_picker.get_item_text(attachment_picker.selected)),
			pose,
			disabled.button_pressed
		),
		"Edit room attachment"
	)


func reset_attachment() -> void:
	if attachment_picker.selected < 0:
		return
	edit_requested.emit(
		model.attachment_reset(
			canvas.selected, StringName(attachment_picker.get_item_text(attachment_picker.selected))
		),
		"Reset room attachment"
	)


func apply_access() -> void:
	if (
		canvas.selected_connection < 0
		or canvas.selected_connection >= model.layout.connections.size()
	):
		return
	var candidate := Model.copy(model.layout)
	var edge := candidate.connections[canvas.selected_connection]
	if edge.state != "security_door":
		model.errors = PackedStringArray(["Choose Security door for this connection first."])
		model.changed.emit()
		return
	edge.security_id = StringName(access_id.text.strip_edges())
	edge.initially_locked = locked.button_pressed
	edit_requested.emit(candidate, "Configure security door access")
