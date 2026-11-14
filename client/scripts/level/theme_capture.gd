extends SceneTree
## Review captures of a themed layout from inside its rooms, under the mission's own lighting.
## Needs a graphical display (not --headless):
##
##   godot --path client --script res://scripts/level/theme_capture.gd -- \
##       --layout res://resources/levels/goauld_infiltration_01.tres --output /tmp/captures
##
## Optional: --theme neutral forces another theme for a side-by-side; --shots a,b limits the
## set; --jaffa stands an alerted guard in the chamber and corridor. Each shot is a room, a camera position and a target, both in the room's own frame.
const SHOTS := {
	"corridor": [&"approach", Vector3(0, 1.7, 3.6), Vector3(0, 1.5, -4.0)],
	"corridor_wall": [&"approach", Vector3(1.1, 1.6, 1.5), Vector3(-1.5, 1.6, -1.0)],
	"corridor_lintel": [&"approach", Vector3(0.0, 1.7, -0.5), Vector3(0.0, 2.9, -3.9)],
	"chamber": [&"checkpoint", Vector3(-3.2, 1.9, 3.2), Vector3(1.5, 1.2, -2.0)],
	"chamber_door": [&"checkpoint", Vector3(0.0, 1.7, 1.0), Vector3(0.0, 1.9, -3.9)],
	"chamber_corner": [&"barracks", Vector3(1.0, 1.7, 1.0), Vector3(-3.8, 1.5, -3.8)],
	"cover": [&"stores", Vector3(-3.0, 1.9, -3.0), Vector3(1.0, 0.6, 1.0)],
	"palette_only": [&"inner", Vector3(-3.4, 1.7, 0.0), Vector3(4.0, 1.5, 0.0)],
}
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"


func _init() -> void:
	call_deferred("run")


func option(name: String, fallback: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(name)
	return arguments[index + 1] if index >= 0 and index + 1 < arguments.size() else fallback


func run() -> void:
	var layout := load(option("--layout", "res://resources/levels/goauld_infiltration_01.tres")) as LevelLayout
	var output := option("--output", "user://theme_captures")
	var forced := option("--theme", "")
	var wanted := option("--shots", "")
	if layout == null:
		push_error("Layout not found")
		quit(1)
		return
	if not forced.is_empty():
		layout = layout.duplicate(true) as LevelLayout
		layout.default_theme = StringName(forced)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var level := LevelAssembly.new()
	level.layout = layout
	root.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	if not level.last_errors.is_empty():
		push_error("Layout did not build: " + str(level.last_errors))
		quit(1)
		return
	# The same presentation a mission adds (ModularMission._add_presentation).
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.05, 0.06, 0.08)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	var palette := LevelThemeResolver.lighting(layout)
	if palette != null:
		settings.ambient_light_color = palette.ambient_color
		settings.ambient_light_energy = palette.ambient_energy
	var environment := WorldEnvironment.new()
	environment.environment = settings
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 75.0
	root.add_child(camera)
	camera.make_current()
	var suffix := "" if forced.is_empty() else "_" + forced
	if "--jaffa" in OS.get_cmdline_user_args():
		suffix += "_jaffa"
	# --jaffa: an alerted guard in the chamber and corridor shots, to judge whether he and
	# his marker stand out from the walls. He is a prop here: his own processing is off.
	if "--jaffa" in OS.get_cmdline_user_args():
		for place: Array in [[&"checkpoint", Vector3(1.2, 0.05, -1.5)], [&"approach", Vector3(0.4, 0.05, -1.5)]]:
			var room := level.get_node_or_null(str(place[0])) as Node3D
			if room == null:
				continue
			var guard := (load(JAFFA) as PackedScene).instantiate() as JaffaAI
			root.add_child(guard)
			guard.set_physics_process(false)
			guard.global_position = room.global_transform * (place[1] as Vector3)
			guard.awareness_level = JaffaPerception.Level.ALERTED
	for shot: String in SHOTS:
		if not wanted.is_empty() and not shot in wanted.split(","):
			continue
		var room := level.get_node_or_null(str(SHOTS[shot][0])) as Node3D
		if room == null:
			continue
		camera.global_position = room.global_transform * (SHOTS[shot][1] as Vector3)
		camera.look_at(room.global_transform * (SHOTS[shot][2] as Vector3))
		for i in range(6):
			await process_frame
		var path := "%s/%s%s.png" % [output, shot, suffix]
		root.get_texture().get_image().save_png(path)
		print("CAPTURE " + path)
	quit(0)
