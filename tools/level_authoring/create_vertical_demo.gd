extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")


func _init() -> void:
	var model := Model.new()
	model.restore(model.deck_changed("upper", 4))
	for pose: Array in [
		["Room14Ramp4m", Vector2(0, 0), 0],
		["Room03TJunction", Vector2(0, -8), 1],
		["Room15TransportChamber", Vector2(-8, -8), 1],
		["Room16HangarShell", Vector2(-40, -8), 1]
	]:
		var candidate := model.placed(
			load("res://resources/level_modules/" + pose[0] + ".tres"), pose[1], pose[2]
		)
		assert(model.accepted(candidate), str(model.errors))
		model.restore(candidate)
	model.active_deck = &"upper"
	model.restore(
		model.placed(load("res://resources/level_modules/Room01Straight.tres"), Vector2(0, 16), 0)
	)
	model.layout.entry_instance = &"room_002"
	model.layout.destination_instance = &"room_005"
	assert(LevelLayoutValidator.validate(model.layout).is_empty())
	assert(model.layout.connections.size() == 4)
	assert(ResourceSaver.save(model.layout, "res://resources/levels/vertical_kit_demo.tres") == OK)
	print("PASS saved five-instance vertical kit demo")
	quit()
