extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {}
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg in ["--layout", "--output", "--nav-output"]:
			if index + 1 >= args.size() or args[index + 1].begins_with("--"):
				fail(PackedStringArray(["Missing value for " + arg]))
				return
			index += 1
			options[arg] = args[index]
		elif arg not in ["--validate", "--build"]:
			fail(PackedStringArray(["Unknown option: " + arg]))
			return
		index += 1
	var path := "res://resources/levels/modular_smoke.tres"
	if "--layout" in args:
		path = str(options["--layout"])
	var resource := load(path) as LevelLayout
	var errors := LevelLayoutValidator.validate(resource)
	if not errors.is_empty():
		fail(errors)
		return
	var level := LevelAssembly.new()
	level.layout = resource
	root.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	if not level.last_errors.is_empty():
		fail(level.last_errors)
		return
	var route := level.local_path(
		level.marker(resource.entry_instance, resource.entry_marker),
		level.marker(resource.destination_instance, resource.destination_marker)
	)
	if (
		route.is_empty()
		or (
			route[-1].distance_to(
				level.marker(resource.destination_instance, resource.destination_marker)
			)
			> 0.5
		)
	):
		fail(PackedStringArray(["Entry to destination navigation disconnected"]))
		return
	if "--build" in args:
		if not "--output" in args or not "--nav-output" in args:
			fail(PackedStringArray(["Build requires --output and --nav-output"]))
			return
		var output: String = options["--output"]
		var nav_output: String = options["--nav-output"]
		if (
			not (output.begins_with("res://scenes/level/") or output.begins_with("user://"))
			or not (
				nav_output.begins_with("res://resources/levels/")
				or nav_output.begins_with("user://")
			)
		):
			fail(
				PackedStringArray(
					["Outputs must stay in modular scene/resource directories or user://"]
				)
			)
			return
		if ResourceSaver.save(level.navigation.navigation_mesh, nav_output) != OK:
			fail(PackedStringArray(["Cannot save navigation"]))
			return
		level.navigation.owner = level
		var scene := PackedScene.new()
		if scene.pack(level) != OK:
			fail(PackedStringArray(["Cannot pack assembly"]))
			return
		if ResourceSaver.save(scene, output) != OK:
			fail(PackedStringArray(["Cannot save build outputs"]))
			return
	print("PASS modular build and navigation")
	await preload("res://tests/support/finish.gd").success(self)


func fail(errors: PackedStringArray) -> void:
	for error in errors:
		push_error(error)
	quit(1)
