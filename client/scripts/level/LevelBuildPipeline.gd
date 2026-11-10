class_name LevelBuildPipeline
extends RefCounted


static func export(level: LevelAssembly, output: String, nav_output: String) -> PackedStringArray:
	output = output.simplify_path()
	nav_output = nav_output.simplify_path()
	if (
		not (output.begins_with("res://scenes/level/") or output.begins_with("user://"))
		or not (
			nav_output.begins_with("res://resources/levels/") or nav_output.begins_with("user://")
		)
	):
		return PackedStringArray(
			["Outputs must stay in modular scene/resource directories or user://"]
		)
	if not output.ends_with(".tscn") or not nav_output.get_extension() in ["res", "tres"]:
		return PackedStringArray(["Build output must be .tscn and navigation output .res/.tres"])
	# Export may replace derived outputs, never source layouts or reusable room scenes.
	if (
		output.begins_with("res://scenes/level/modules/")
		or (
			output
			in ["res://scenes/level/RoomPlaceholder.tscn", "res://scenes/level/ModularDoor.tscn"]
		)
	):
		return PackedStringArray(["Cannot overwrite reusable structural scenes"])
	if FileAccess.file_exists(nav_output) and not load(nav_output) is NavigationMesh:
		return PackedStringArray(
			["Navigation output would overwrite a source resource: " + nav_output]
		)
	var token := str(Time.get_ticks_usec())
	var scene_stage := output.get_basename() + ".pending_" + token + ".tscn"
	var nav_stage := (
		nav_output.get_basename() + ".pending_" + token + "." + nav_output.get_extension()
	)
	if ResourceSaver.save(level.navigation.navigation_mesh, nav_stage) != OK:
		return PackedStringArray(["Cannot save navigation"])
	level.layout = level.layout.duplicate(true) as LevelLayout
	level.navigation.owner = level
	var scene := PackedScene.new()
	if scene.pack(level) != OK or ResourceSaver.save(scene, scene_stage) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(nav_stage))
		return PackedStringArray(["Cannot pack/save assembly"])
	var targets: Array[String] = [nav_output, output]
	var staged: Array[String] = [nav_stage, scene_stage]
	var backups: Dictionary = {}
	var committed: Array[String] = []
	for target in targets:
		if FileAccess.file_exists(target):
			backups[target] = FileAccess.get_file_as_bytes(target)
	for i in range(targets.size()):
		if (
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(staged[i]),
				ProjectSettings.globalize_path(targets[i])
			)
			!= OK
		):
			for target in committed:
				if backups.has(target):
					var file := FileAccess.open(target, FileAccess.WRITE)
					if file != null:
						file.store_buffer(backups[target])
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
			for path in staged:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			return PackedStringArray(["Cannot publish build outputs; previous outputs restored"])
		committed.append(targets[i])
	return PackedStringArray()
