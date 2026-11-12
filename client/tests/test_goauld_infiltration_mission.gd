extends SceneTree
## Goa'uld infiltration greybox mission (roadmap GI-1) through the production lobby, mission
## host and sentry controllers. The test places the operative and reads state. The quiet-route
## case moves the operative room by room along the service route, only into spots no sentry can
## currently see, and falls back a room when its own spot comes into view. It is an automated
## stand-in for a careful player, not proof that the route feels fair.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D
var probe: Node3D


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func launch(previous: int = 0) -> void:
	for i in range(600):
		var current := main.current_gate_room as ModularMission
		if current != null and current.get_instance_id() != previous:
			room = current
			break
		await frames(1)
	assert(room != null and room.get_instance_id() != previous and room.mission_id == MISSION)
	if not room.is_started:
		await room.started
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
	level = room.level
	player = room.players_container.get_node("1") as PlayerController3D
	probe = Node3D.new()
	room.add_child(probe)


func sentries() -> Array[JaffaAI]:
	var result: Array[JaffaAI] = []
	for enemy in room.enemies.get_children():
		var jaffa := enemy as JaffaAI
		if jaffa != null and jaffa.current_state != JaffaAI.State.DEAD:
			result.append(jaffa)
	return result


## No living sentry can see an operative standing at `spot` right now.
func unseen(spot: Vector3) -> bool:
	probe.global_position = spot
	for jaffa in sentries():
		if jaffa.perception.can_see(probe):
			return false
	return true


func highest_awareness() -> int:
	var highest := 0
	for jaffa in sentries():
		highest = maxi(highest, jaffa.awareness_level)
	return highest


## A floor spot within reach of a mission console.
func console_spot(room_id: StringName) -> Vector3:
	var console := level.get_node(str(room_id)).find_child("MissionInteract", true, false) as Node3D
	assert(console != null, "Mission console in " + str(room_id))
	var best := Vector3.INF
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var spot := NavigationServer3D.map_get_closest_point(level.navigation_map, console.global_position + offset)
		if spot.distance_to(console.global_position) < MissionInteractable.REACH - 0.3:
			if best == Vector3.INF or spot.distance_to(console.global_position) < best.distance_to(console.global_position):
				best = spot
	assert(best != Vector3.INF, "Reachable floor beside the console in " + str(room_id))
	return best


func use_console(room_id: StringName) -> void:
	var console := (
		level.get_node(str(room_id)).find_child("MissionInteract", true, false) as MissionInteractable
	)
	var before := room.objectives.index
	for i in range(30):
		console.interact(player)
		await frames(2)
		if room.objectives.index > before:
			return
	assert(false, "Console in %s did not complete its objective" % room_id)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	var lobby := main.current_lobby as LobbyUI
	assert(lobby.mission_option_button.item_count == 4)
	assert(lobby.mission_option_button.get_item_metadata(3) == MISSION)
	lobby._on_mission_selected(0)
	lobby._on_mission_selected(3)
	assert(net.selected_mission_id == MISSION and lobby.difficulty_option_button.disabled)
	assert(lobby.start_game_button.text == "LAUNCH INFILTRATION")
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	await launch()
	var definition := room.definition
	assert(definition.validate().is_empty())
	assert(level.layout.resource_path == "res://resources/levels/goauld_infiltration_01.tres")
	await frames(5)
	assert(room.hud.wave_label.text == definition.title, room.hud.wave_label.text)
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/3"))
	assert(sentries().size() == 6)
	for jaffa in sentries():
		assert(jaffa.profile == JaffaAI.Profile.SENTRY and jaffa.current_state == JaffaAI.State.PATROL)
	player.health_component.current_health = 1000000.0

	# --- Insertion: no sentry sees the spawn points while the patrols run.
	var entry := level.marker(level.layout.entry_instance, level.layout.entry_marker)
	assert(player.global_position.distance_to(entry) < 3.0)
	for i in range(60 * 6):
		await physics_frame
		for point: Node3D in room.spawns_container.get_children():
			assert(unseen(point.global_position), "A sentry can see the insertion point")
	assert(highest_awareness() == JaffaPerception.Level.UNAWARE)

	# --- Loud route: walking into the guarded checkpoint gets the operative noticed.
	place(player, level.marker(&"checkpoint", &"patrol"))
	var noticed := false
	for i in range(60 * 20):
		await physics_frame
		if highest_awareness() == JaffaPerception.Level.ALERTED:
			noticed = true
			break
	assert(noticed, "The checkpoint route is guarded")

	# --- Retry gives a calm compound.
	var old := room.get_instance_id()
	assert(net.request_restart_game())
	await launch(old)
	assert(room.objectives.index == 0 and room.mission_result == -1 and sentries().size() == 6)
	assert(highest_awareness() == JaffaPerception.Level.UNAWARE)
	player.health_component.current_health = 1000000.0

	# --- Quiet route: service corridor, stores and maintenance to the generator, unseen.
	var path: Array[Vector3] = [entry]
	for id: StringName in [&"service", &"service2", &"svc_adapter", &"stores", &"maint"]:
		path.append(level.marker(id, &"patrol"))
	path.append(console_spot(&"generator"))
	var step := 0
	var clear_for := 0
	var alerted := false
	place(player, path[0])
	for i in range(60 * 180):
		await physics_frame
		alerted = alerted or highest_awareness() == JaffaPerception.Level.ALERTED
		if step == path.size() - 1:
			break
		if not unseen(path[step]) and step > 0 and unseen(path[step - 1]):
			step -= 1
			place(player, path[step])
			clear_for = 0
			continue
		clear_for = clear_for + 1 if unseen(path[step]) and unseen(path[step + 1]) else 0
		if clear_for >= 15:
			step += 1
			place(player, path[step])
			clear_for = 0
	assert(step == path.size() - 1, "The quiet route reached the generator (step %d)" % step)
	assert(not alerted, "Nobody was alerted on the quiet route")
	assert(not room.objectives.inside(player, definition.objectives[2]))
	await use_console(&"generator")
	assert(room.objectives.index == 1 and room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))
	assert(highest_awareness() < JaffaPerception.Level.ALERTED)

	# --- The rest of the mission in order: command records upstairs, then the gate.
	place(player, console_spot(&"cmd_command"))
	await use_console(&"cmd_command")
	assert(room.objectives.index == 2 and room.hud.objective_label.text.begins_with("OBJECTIVE 3/3"))
	place(player, entry)
	for i in range(120):
		await physics_frame
		if room.mission_result >= 0:
			break
	assert(room.mission_result == 1 and room.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	for jaffa in sentries():
		assert(not jaffa.is_physics_processing(), "Sentries stand down at the result")

	# --- Failure path: the lone operative going down ends the mission.
	old = room.get_instance_id()
	assert(net.request_restart_game())
	await launch(old)
	player.health_component.take_damage(99999.0)
	for i in range(60):
		await physics_frame
		if room.mission_result >= 0:
			break
	assert(room.mission_result == 0 and room.hud.debrief_title.text == "MISSION FAILED")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS goa'uld infiltration: lobby launch, unseen insertion, guarded checkpoint, quiet route to the generator, objectives, extraction, retry and failure")
	await preload("res://tests/support/finish.gd").success(self)
