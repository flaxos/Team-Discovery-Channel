extends SceneTree
## EV-2 chunk 1: real generator interaction earns one security release; no direct event
## completion or manufactured snapshot is used to establish the positive result.
const Fixture = preload("res://tests/support/mission_events_fixture.gd")
const DEFINITION := "res://resources/missions/goauld_infiltration.tres"
var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func definition_copy(source: MissionDefinition) -> MissionDefinition:
	# Godot 4.4 does not deep-duplicate resources inside typed arrays reliably.
	var copy := source.duplicate() as MissionDefinition
	copy.triggers = []
	for trigger in source.triggers:
		copy.triggers.append(trigger.duplicate() as MissionTrigger)
	return copy


func validate_data() -> void:
	var source := load(DEFINITION) as MissionDefinition
	assert(source.validate().is_empty())
	var copy := definition_copy(source)
	copy.triggers[0].security_id = &"Door_002"
	assert(str(copy.validate()).contains("one named security door"), "Generated node names are not door IDs")
	copy = definition_copy(source)
	copy.triggers[0].objective_id = &"missing"
	assert(str(copy.validate()).contains("Unknown trigger objective"))
	copy = definition_copy(source)
	copy.triggers[0].objective_id = &"download_records"
	assert(str(copy.validate()).contains("Mission doors block objective"), "Reject a console behind its own lock")
	copy = definition_copy(source)
	copy.triggers.append(copy.triggers[0])
	assert(str(copy.validate()).contains("Duplicate/empty mission trigger id"))
	assert(str(copy.validate()).contains("multiple release triggers"))
	copy = definition_copy(source)
	copy.triggers[0].id = &""
	assert(str(copy.validate()).contains("Duplicate/empty mission trigger id"))
	copy = definition_copy(source)
	copy.triggers[0].objective_id = &"extract"
	assert(str(copy.validate()).contains("precede extraction"))
	copy = definition_copy(source)
	copy.triggers.append(null)
	assert(str(copy.validate()).contains("Null mission trigger"))
	assert(source.validate().is_empty(), "Validation probes leave the authored resource untouched")
	assert((load("res://resources/missions/modular_extraction_uat.tres") as MissionDefinition).triggers.is_empty())


func mission(previous: int = 0) -> ModularMission:
	for i in range(600):
		var room := main.current_gate_room as ModularMission
		if room != null and room.get_instance_id() != previous and room.is_started:
			assert(room.setup_errors.is_empty(), str(room.setup_errors))
			assert(room.level.last_errors.is_empty(), str(room.level.last_errors))
			Fixture.stand_down(room)
			return room
		await physics_frame
	assert(false, "Mission did not start")
	return null


func run() -> void:
	validate_data()
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	var player := room.players_container.get_node("1") as PlayerController3D
	var door := Fixture.door(room)
	assert(door != null and door.locked and not door.is_open)
	assert(room.events.fired.is_empty())
	# TA-3 sees the live lock, while the generator remains reachable from insertion.
	var probe := CharacterBody3D.new()
	room.level.add_child(probe)
	probe.global_position = room.level.marker(&"cmd_antechamber", &"entry")
	var navigator := LevelNavigator.new(probe, room.level)
	navigator.next_position(room.level.marker(&"cmd_command", &"entry"), 1.0 / 60.0)
	assert(navigator.status == "blocked_door", "Command access waits for generator sabotage")
	probe.global_position = room.level.marker(&"gate", &"entry")
	var to_generator := LevelNavigator.new(probe, room.level)
	to_generator.next_position(room.level.marker(&"generator", &"entry"), 1.0 / 60.0)
	assert(to_generator.status == "moving", "The release console remains reachable")
	var station := Fixture.console(room)
	station.interact(player)
	await frames(2)
	assert(door.locked and room.objectives.index == 0, "Out-of-reach interaction earns nothing")
	var spot := Fixture.console_spot(room)
	assert(spot != Vector3.INF)
	Fixture.place(player, spot)
	player.health_component.is_downed = true
	station.interact(player)
	assert(door.locked and room.events.fired.is_empty(), "Downed operatives cannot release security")
	player.health_component.is_downed = false
	station.interact(player)
	await frames(2)
	assert(room.objectives.index == 1 and not door.locked)
	assert(room.events.fired == PackedStringArray([Fixture.ID]))
	assert(room.hud.squad_toast_label.text == room.definition.triggers[0].notice)
	var unlocked := LevelNavigator.new(probe, room.level)
	probe.global_position = room.level.marker(&"cmd_antechamber", &"entry")
	unlocked.next_position(room.level.marker(&"cmd_command", &"entry"), 1.0 / 60.0)
	assert(unlocked.status == "moving", "TA-3 can use the released doorway")
	# Repeated setup/signal delivery cannot relock a released stage or replay its notice.
	room.hud.squad_toast_label.text = "unchanged"
	assert(room.events.start().is_empty())
	room.events._on_objective_changed(room.objectives.index)
	assert(not door.locked and room.hud.squad_toast_label.text == "unchanged")
	var previous := room.get_instance_id()
	assert(net.request_restart_game())
	room = await mission(previous)
	door = Fixture.door(room)
	assert(door.locked and room.events.fired.is_empty() and room.objectives.index == 0,
		"Retry restores the original mission gate")
	room.conclude(false)
	assert(not room.events.active)
	room.objectives.sync_state(1)
	assert(door.locked and room.events.fired.is_empty(), "No action after the result is final")
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS mission events: validation, earned release, live navigation, one-shot, result freeze and retry")
	await preload("res://tests/support/finish.gd").success(self)
