extends SceneTree
## Runs unchanged from a clean PCK too: no paths outside res://, accounts or network needed.


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var data := preload("res://resources/asset_credits.tres")
	var credits := str(data.get_meta("attributions", ""))
	for creator: String in ["Kenney", "Fabi_G", "emran.bayati", "Rotuma", "skaf13", "rossrobotics", "WillyG99", "Dimitrios Savva", "Rob Tuytel"]:
		assert(credits.contains(creator), "Distributed attribution for " + creator)
	assert(credits.contains("Modifications:") and credits.contains("Changes:"), "Modification notices retained")
	var licenses: Dictionary = data.get_meta("licenses", {})
	assert(licenses.has("CC-BY-4.0.txt") and licenses.has("CC0-1.0.txt"), "Full licences distributed")
	assert(str(licenses["CC-BY-4.0.txt"]).sha256_text() == "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411", "Exact full official CC BY text")
	assert(str(licenses["CC0-1.0.txt"]).sha256_text() == "a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499", "Exact full official CC0 text")
	var files: Array = data.get_meta("asset_files", [])
	assert(files.size() >= 7, "Every committed asset has credit coverage")
	for file: String in files:
		var resource_path := "res://" + file.trim_prefix("client/")
		assert(FileAccess.file_exists(resource_path) or ResourceLoader.exists(resource_path), "Credited asset packaged: " + file)
	var lobby := (load("res://scenes/main/Lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await process_frame
	var button := lobby.get_node("%AssetCreditsButton") as Button
	var dialog := lobby.get_node("AssetCreditsDialog") as AssetCreditsDialog
	assert(not dialog.visible, "Credits initially closed")
	button.pressed.emit()
	await process_frame
	assert(dialog.visible and dialog.content.text == credits, "Lobby button opens actual distributed credits")
	for index in range(1, dialog.selector.item_count):
		dialog.selector.select(index)
		dialog.selector.item_selected.emit(index)
		assert(dialog.content.text == licenses[dialog.selector.get_item_metadata(index)], "Full selectable licence text")
	dialog.get_ok_button().pressed.emit()
	await process_frame
	assert(not dialog.visible, "Close returns to lobby")
	print("test_asset_credits: PASS assets=", files.size(), " licences=", licenses.size())
	lobby.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)
