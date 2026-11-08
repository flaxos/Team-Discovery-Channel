extends RefCounted
## Retire fixture audio/worlds before engine shutdown; do not mask engine diagnostics.
static func success(tree: SceneTree) -> void:
	OS.delay_msec(250)
	for node: Node in tree.root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			node.stop()
			node.stream = null
	for node: Node in tree.root.get_children():
		if node.name not in ["NetworkManager", "KeybindingManager"]:
			if node.has_method("end_mission"):
				node.end_mission()
			node.queue_free()
	await tree.process_frame
	# The audio mixer is asynchronous even when fixed-fps tests run faster than realtime.
	OS.delay_msec(50)
	tree.quit(0)
