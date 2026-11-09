extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	var model := Model.new()
	var room := load("res://resources/level_modules/Room04Chamber.tres") as LevelModuleDefinition
	model.restore(model.placed(room, Vector2.ZERO, 0))
	model.restore(model.placed(room, Vector2(0, 8), 0))
	model.restore(model.configured(&"room_001", LevelPresetCatalogue.preset("cargo")))
	model.restore(model.configured(&"room_002", LevelPresetCatalogue.preset("jaffa_barracks")))
	for item in model.layout.instances:
		item.theme = load("res://resources/level_themes/neutral.tres")
	model.layout.connections[0].state = "security_door"
	model.layout.connections[0].security_id = &"uat.access"
	assert(LevelLayoutValidator.validate(model.layout).is_empty())
	assert(ResourceSaver.save(model.layout, "res://resources/levels/room_presets_demo.tres") == OK)
	print("PASS saved two-room preset test fixture")
	quit()
