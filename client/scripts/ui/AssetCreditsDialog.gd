class_name AssetCreditsDialog
extends AcceptDialog
## Exported resource generated from the maintained repository attribution/licence sources.

const DATA := preload("res://resources/asset_credits.tres")
var content: TextEdit
var selector: OptionButton


func _ready() -> void:
	title = "Community credits & licences"
	min_size = Vector2i(560, 320)
	get_ok_button().text = "Close"
	var layout := VBoxContainer.new()
	layout.name = "CreditsContent"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_top = 12
	layout.offset_right = -16
	layout.offset_bottom = -52
	add_child(layout)
	selector = OptionButton.new()
	selector.name = "DocumentSelector"
	selector.add_item("Asset credits")
	selector.set_item_metadata(0, "")
	var licenses: Dictionary = DATA.get_meta("licenses", {})
	for filename: String in licenses:
		selector.add_item(filename.trim_suffix(".txt"))
		selector.set_item_metadata(selector.item_count - 1, filename)
	layout.add_child(selector)
	content = TextEdit.new()
	content.name = "DocumentText"
	content.editable = false
	content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_font_size_override("font_size", 15)
	content.add_theme_color_override("font_readonly_color", Color(0.88, 0.92, 0.96))
	layout.add_child(content)
	selector.item_selected.connect(show_document)
	show_document(0)


func show_document(index: int) -> void:
	var key := str(selector.get_item_metadata(index))
	var licenses: Dictionary = DATA.get_meta("licenses", {})
	content.text = str(DATA.get_meta("attributions", "")) if key.is_empty() else str(licenses.get(key, ""))
	content.scroll_vertical = 0
	content.set_caret_line(0)


func open() -> void:
	popup_centered_ratio(0.85)
	selector.grab_focus()
