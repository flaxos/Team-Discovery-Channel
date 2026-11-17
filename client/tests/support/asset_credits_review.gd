extends SceneTree
## Real GPU evidence for the lobby credit/complete licence views; no game is hosted.


func _init() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../build/asset-review/credits")
	DirAccess.make_dir_recursive_absolute(folder)
	assert(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	var lobby := (load("res://scenes/main/Lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await capture("lobby.png")
	(lobby.get_node("%AssetCreditsButton") as Button).pressed.emit()
	await capture("credits.png")
	var dialog := lobby.get_node("AssetCreditsDialog") as AssetCreditsDialog
	dialog.selector.select(1)
	dialog.selector.item_selected.emit(1)
	await capture("licence.png")
	dialog.get_ok_button().pressed.emit()
	await capture("closed.png")
	lobby.queue_free()
	await process_frame
	print("Asset credits GPU review: PASS")
	await preload("res://tests/support/finish.gd").success(self)
