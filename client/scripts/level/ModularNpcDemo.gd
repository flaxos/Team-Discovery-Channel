class_name ModularNpcDemo
extends Node3D
## Bounded NPC navigation demonstration on the canonical integrated fixture.
## The host spawns and drives the production Jaffa and airman controllers; clients only
## receive spawner/synchroniser state. Containers are deliberately not named Enemies/Allies,
## so the two factions do not acquire each other and the routes stay repeatable.
signal started
const JAFFA := "res://scenes/entities/JaffaGuard.tscn"
const AIRMAN := "res://scenes/entities/SGCAirman.tscn"
const PATROL: Array[StringName] = [
	&"wide_junction", &"wide_elbow", &"wide_straight", &"width_adapter", &"hub"
]
## Seconds before the host releases the locked security door; 0 keeps it locked.
@export var unlock_after: float = 30.0
var jaffa: JaffaAI
var runner: SGCAirmanAI
var sentry: SGCAirmanAI
var security_door: ModularDoor
var is_started := false
@onready var level: LevelAssembly = $Level
@onready var hostiles: Node3D = $Hostiles
@onready var friendlies: Node3D = $Friendlies
var status_label: Label


func _ready() -> void:
	if not level.ready_for_navigation:
		await level.navigation_ready
	for i in range(level.layout.connections.size()):
		if level.layout.connections[i].security_id == &"crew_quarters":
			security_door = level.get_node("Door_%03d" % i) as ModularDoor
	if DisplayServer.get_name() != "headless":
		_add_overview()
	if multiplayer.is_server():
		_begin()
	is_started = true
	started.emit()


func spawn(scene: String, parent: Node3D, room: StringName, marker: StringName) -> CharacterBody3D:
	var actor := load(scene).instantiate() as CharacterBody3D
	actor.position = parent.to_local(level.marker(room, marker)) + Vector3(0, 0.05, 0)
	parent.add_child(actor, true)
	return actor


func _begin() -> void:
	jaffa = spawn(JAFFA, hostiles, PATROL[0], &"patrol") as JaffaAI
	var route: Array[Vector3] = []
	for room in PATROL:
		route.append(level.marker(room, &"patrol"))
	jaffa.start_patrol(route)
	runner = spawn(AIRMAN, friendlies, &"entry", &"entry") as SGCAirmanAI
	runner.airman_callsign = "RUNNER"
	runner.order_move_to(
		level.marker(level.layout.destination_instance, level.layout.destination_marker)
	)
	sentry = spawn(AIRMAN, friendlies, &"stores_approach", &"entry") as SGCAirmanAI
	sentry.airman_callsign = "SENTRY"
	security_door.set_locked(true)
	sentry.order_move_to(level.marker(&"barracks", &"entry"))
	if unlock_after > 0.0:
		get_tree().create_timer(unlock_after, false, true).timeout.connect(
			func() -> void: security_door.set_locked(false)
		)


func report() -> Dictionary:
	if jaffa == null:
		return {}
	return {
		"jaffa": "%s, waypoint %d, laps %d" % [jaffa.navigator.status, jaffa.patrol_index, jaffa.patrol_laps],
		"runner": runner.navigator.status,
		"sentry": sentry.navigator.status,
		"security_door": "locked" if security_door.locked else "unlocked",
	}


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.is_server() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L and security_door != null:
			security_door.set_locked(not security_door.locked)


func _process(_delta: float) -> void:
	if status_label != null and jaffa != null:
		var values := report()
		status_label.text = (
			"Jaffa patrol: %s\nRunner to command (upper deck): %s\nSentry to barracks: %s\nSecurity door: %s   [L] lock/unlock"
			% [values.jaffa, values.runner, values.sentry, values.security_door]
		)


func _add_overview() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.06, 0.08)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)
	# Cutaway is view-only; ceiling collision and the navigation bake are untouched.
	for item in level.layout.instances:
		for mesh in level.get_node(str(item.id) + "/Visuals").get_children():
			if str(mesh.name).begins_with("Roof"):
				mesh.hide()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 58
	camera.far = 500
	add_child(camera)
	camera.position = Vector3(4, 80, 30)
	camera.look_at(Vector3(-2, 0, 6))
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(16, 12)
	layer.add_child(status_label)
