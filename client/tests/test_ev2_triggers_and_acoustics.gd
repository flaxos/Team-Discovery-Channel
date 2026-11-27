extends SceneTree
## EV-2 remaining & acoustics suite:
## - Data/topology validation for room_entered, alert_searching, lock_door, enable_objective, show_notice, initially_enabled.
## - Runtime triggers: room entry (standing vs downed), deferred lock_door when occupied, TA-3 nav reroute,
##   dormant enable_objective insertion + interactable gating + monotonic sync_state, alert_searching, retry reset, result freeze.
## - LevelAcoustics: same-room prop transparency, wall/door attenuation, opening door propagation, MissionWorld isolation.
const INFILTRATION_DEF := "res://resources/missions/goauld_infiltration.tres"
const ALPHA_SITE_DEF := "res://resources/missions/tauri_alpha_site.tres"
const BOARDING_DEF := "res://resources/missions/goauld_mothership_boarding.tres"
const MOTHERSHIP_OBJ_DEF := "res://resources/missions/goauld_mothership_objective.tres"
const Fixture = preload("res://tests/support/mission_events_fixture.gd")

var net: SGCNetworkManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame


func copy_def(source: MissionDefinition) -> MissionDefinition:
	var copy := source.duplicate() as MissionDefinition
	copy.objectives = []
	for obj: MissionObjective in source.objectives:
		copy.objectives.append(obj.duplicate() as MissionObjective)
	copy.triggers = []
	for trig: MissionTrigger in source.triggers:
		copy.triggers.append(trig.duplicate() as MissionTrigger)
	return copy


func make_trigger(id: StringName, condition: String, action: String) -> MissionTrigger:
	var trig := MissionTrigger.new()
	trig.id = id
	trig.condition = condition
	trig.action = action
	return trig


func validate_data() -> void:
	var infiltration := load(INFILTRATION_DEF) as MissionDefinition
	var alpha := load(ALPHA_SITE_DEF) as MissionDefinition
	var boarding := load(BOARDING_DEF) as MissionDefinition
	var objective_ship := load(MOTHERSHIP_OBJ_DEF) as MissionDefinition
	assert(infiltration.validate().is_empty())
	assert(alpha.validate().is_empty(), str(alpha.validate()))
	assert(boarding.validate().is_empty(), str(boarding.validate()))

	# Valid authored room_entered -> show_notice triggers on Alpha Site and Mothership Boarding.
	assert(alpha.triggers.size() == 1 and alpha.triggers[0].condition == "room_entered" and alpha.triggers[0].action == "show_notice")
	assert(boarding.triggers.size() == 1 and boarding.triggers[0].condition == "room_entered" and boarding.triggers[0].action == "show_notice")

	# Room trigger validation errors.
	var copy := copy_def(alpha)
	copy.triggers[0].objective_id = &"reach_command"
	assert(str(copy.validate()).contains("Room trigger cannot also name an objective"))

	copy = copy_def(alpha)
	copy.triggers[0].room = &"nonexistent_room"
	assert(str(copy.validate()).contains("Unknown trigger room"))

	copy = copy_def(infiltration)
	copy.triggers[0].room = &"generator"
	assert(str(copy.validate()).contains("Only room_entered triggers may name a room"))

	# Alert searching validation errors.
	copy = copy_def(infiltration)
	var alert_t := make_trigger(&"alert_notice", "alert_searching", "show_notice")
	alert_t.notice = "HOSTILES SEARCHING"
	copy.triggers.append(alert_t)
	assert(copy.validate().is_empty(), str(copy.validate()))
	alert_t.objective_id = &"sabotage_generator"
	assert(str(copy.validate()).contains("Alert trigger cannot also name an objective"))
	alert_t.objective_id = &""
	alert_t.action = "release_door"
	alert_t.security_id = &"cmd_command"
	assert(str(copy.validate()).contains("Alert trigger cannot release doors"))

	# Enable objective validation errors.
	copy = copy_def(infiltration)
	copy.objectives[1].initially_enabled = false
	var en := make_trigger(&"enable_records", "room_entered", "enable_objective")
	en.room = &"cmd_antechamber"
	en.target_objective_id = &"download_records"
	en.notice = "RECORDS CONSOLE ONLINE"
	copy.triggers.append(en)
	assert(copy.validate().is_empty(), str(copy.validate()))

	var missing_en := copy_def(infiltration)
	missing_en.objectives[1].initially_enabled = false
	assert(str(missing_en.validate()).contains("Disabled objective has no enable trigger"))

	copy.objectives[2].initially_enabled = false
	assert(str(copy.validate()).contains("Final extraction objective must start enabled"))
	copy.objectives[2].initially_enabled = true

	en.target_objective_id = &"extract"
	assert(str(copy.validate()).contains("Cannot dynamically enable extraction objective"))
	en.target_objective_id = &"sabotage_generator"
	assert(str(copy.validate()).contains("Target objective is already initially enabled"))
	en.target_objective_id = &"missing_obj"
	assert(str(copy.validate()).contains("Unknown target objective"))

	var self_en := make_trigger(&"self_en", "objective_completed", "enable_objective")
	self_en.objective_id = &"download_records"
	self_en.target_objective_id = &"download_records"
	var self_copy := copy_def(infiltration)
	self_copy.objectives[1].initially_enabled = false
	self_copy.triggers.append(self_en)
	assert(str(self_copy.validate()).contains("Objective cannot enable itself"))

	# Show notice validation errors.
	var notice_copy := copy_def(alpha)
	notice_copy.triggers[0].notice = "  "
	assert(str(notice_copy.validate()).contains("Notice trigger needs a non-empty notice"))
	notice_copy.triggers[0].notice = "VALID NOTICE"
	notice_copy.triggers[0].target_objective_id = &"reach_command"
	assert(str(notice_copy.validate()).contains("Notice trigger cannot target doors or objectives"))

	# Lock door validation errors + topology soft-lock check.
	var lock_copy := copy_def(objective_ship)
	lock_copy.triggers.clear()
	var lock_bridge := make_trigger(&"lock_bridge", "room_entered", "lock_door")
	lock_bridge.room = &"corridor_engineering"
	lock_bridge.security_id = &"bridge_blast_door"
	lock_copy.triggers.append(lock_bridge)
	assert(str(lock_copy.validate()).contains("Lock trigger permanently blocks objective: override_bridge_helm"))

	var dual_copy := copy_def(infiltration)
	var lock_cmd := make_trigger(&"lock_cmd", "room_entered", "lock_door")
	lock_cmd.room = &"checkpoint"
	lock_cmd.security_id = &"cmd_command"
	dual_copy.triggers.append(lock_cmd)
	assert(str(dual_copy.validate()).contains("Security door cannot both lock and release"))

	# Valid lock_door when no objective lies solely behind the locked door.
	var valid_lock := copy_def(infiltration)
	valid_lock.objective_variants = []
	valid_lock.objectives = [valid_lock.objectives[0], valid_lock.objectives[2]]
	valid_lock.triggers = [lock_cmd]
	assert(valid_lock.validate().is_empty(), str(valid_lock.validate()))


func start_mission() -> ModularMission:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var room := main.current_gate_room as ModularMission
		if room != null and room.is_started:
			assert(room.setup_errors.is_empty(), str(room.setup_errors))
			Fixture.stand_down(room)
			return room
		await frames(1)
	assert(false, "Mission did not start")
	return null


func spawn_direct_mission(def: MissionDefinition, suffix: String) -> ModularMission:
	var scene := load("res://scenes/mission/GoauldInfiltrationMission.tscn") as PackedScene
	var room := scene.instantiate() as ModularMission
	room.name = "EV2Mission_%s" % suffix
	room.definition = def
	root.add_child(room)
	while not room.is_started:
		await physics_frame
	assert(room.setup_errors.is_empty(), str(room.setup_errors))
	Fixture.stand_down(room)
	return room


func build_dynamic_def() -> MissionDefinition:
	var src := load(INFILTRATION_DEF) as MissionDefinition
	var def := copy_def(src)
	def.patrols = []
	def.reinforcements = []
	def.objective_variants = []
	def.airman_support = false
	def.objectives[1].initially_enabled = false
	var enable_trig := make_trigger(&"antechamber_enables_records", "room_entered", "enable_objective")
	enable_trig.room = &"cmd_antechamber"
	enable_trig.target_objective_id = &"download_records"
	enable_trig.notice = "COMMAND UPLINK ACTIVATED"
	var search_trig := make_trigger(&"searching_notice", "alert_searching", "show_notice")
	search_trig.notice = "HOSTILES SWEEPING COMPOUND"
	def.triggers.append(enable_trig)
	def.triggers.append(search_trig)
	assert(def.validate().is_empty(), str(def.validate()))
	return def


func test_runtime_triggers() -> void:
	var def := build_dynamic_def()
	var room := await spawn_direct_mission(def, "dyn")
	var player := room.players_container.get_node("1") as PlayerController3D
	player.set_physics_process(false)
	var records_station := room.level.get_node("cmd_command").find_child("MissionInteract", true, false) as MissionInteractable
	assert(records_station != null)
	assert(not records_station.is_in_group("interactable") and not records_station.prompt.visible, "Dormant console starts hidden")
	assert(room.objectives.index == 0 and room.objectives.enabled_count() == 2)
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 1/2"))

	# Step away from the gate extraction circle before completing objective 0, otherwise skipping dormant download_records immediately extracts!
	Fixture.place(player, room.level.marker(&"generator", &"entry"))
	await frames(2)

	# Complete objective 0 (sabotage_generator): dormant objective 1 is skipped cleanly!
	assert(room.objectives.complete_interaction(def.objectives[0]))
	assert(room.objectives.index == 2, "Extraction becomes active while download_records remains dormant")
	assert(not room.events.fired.has("antechamber_enables_records"))
	assert(not records_station.is_in_group("interactable"))
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 2/2"))

	# Downed operative inside cmd_antechamber must NOT fire room_entered (keep a standing anchor outside gate extract so squad wipe / extract does not conclude).
	var anchor := (load("res://scenes/entities/Player.tscn") as PackedScene).instantiate() as PlayerController3D
	anchor.name = "StandingAnchor"
	anchor.peer_id = 99
	room.players_container.add_child(anchor)
	anchor.set_physics_process(false)
	anchor.global_position = room.level.marker(&"checkpoint", &"entry") + Vector3(0, 0.05, 0)
	player.health_component.bleedout_timer = 30.0
	player.health_component.is_downed = true
	Fixture.place(player, room.level.marker(&"cmd_antechamber", &"entry"))
	await frames(4)
	assert(not room.events.fired.has("antechamber_enables_records"), "Downed operative cannot trigger room_entered")

	# Standing operative fires room_entered once -> enables download_records dynamically & shifts active index to 1!
	player.health_component.is_downed = false
	player.health_component.bleedout_timer = 0.0
	anchor.queue_free()
	await frames(4)
	assert(room.events.fired.has("antechamber_enables_records"), "Standing operative fires room_entered")
	assert(room.objectives.is_objective_enabled(1) and room.objectives.index == 1, "Enabled dormant objective inserts as active index 1")
	assert(records_station.is_in_group("interactable") and records_station.prompt.visible, "Newly enabled console becomes active")
	assert(room.hud.objective_label.text.begins_with("OBJECTIVE 2/3"))
	assert(room.hud.squad_toast_label.text == "COMMAND UPLINK ACTIVATED")

	# Monotonic downgrade rejection: stale sync_state cannot undo enabled/completed objectives.
	room.objectives.sync_state(0, 1, 0)
	assert(room.objectives.is_objective_enabled(1) and room.objectives.is_objective_completed(0) and room.objectives.index == 1)

	# Repeated room entry does not re-fire one-shot notice.
	room.hud.squad_toast_label.text = "cleared"
	await frames(4)
	assert(room.hud.squad_toast_label.text == "cleared")

	# Alert searching trigger fires once on SEARCHING.
	room.alert.level_changed.emit(MissionAlert.Level.SEARCHING)
	assert(room.events.fired.has("searching_notice"))
	assert(room.hud.squad_toast_label.text == "HOSTILES SWEEPING COMPOUND")

	# Stop / result freeze prevents further room_entered triggers.
	var lock_def := copy_def(load(INFILTRATION_DEF) as MissionDefinition)
	lock_def.patrols = []
	lock_def.reinforcements = []
	lock_def.objective_variants = []
	lock_def.airman_support = false
	lock_def.objectives = [lock_def.objectives[0], lock_def.objectives[2]]
	var lock_cmd := make_trigger(&"lock_cmd", "room_entered", "lock_door")
	lock_cmd.room = &"checkpoint"
	lock_cmd.security_id = &"cmd_command"
	lock_cmd.notice = "COMMAND WING SEALED"
	lock_def.triggers = [lock_cmd]
	assert(lock_def.validate().is_empty(), str(lock_def.validate()))
	room.queue_free()
	await frames(3)

	var lock_room := await spawn_direct_mission(lock_def, "lock")
	var lp := lock_room.players_container.get_node("1") as PlayerController3D
	lp.set_physics_process(false)
	var cmd_door := Fixture.door(lock_room)
	assert(not cmd_door.locked, "lock_door starts unlocked")
	cmd_door.sync_open(true)
	assert(cmd_door.is_open)

	# Put an AI right inside doorway so _can_close() rejects immediate lock, testing _pending_locks retry!
	var blocker := (load("res://scenes/entities/JaffaGuard.tscn") as PackedScene).instantiate() as JaffaAI
	blocker.name = "DoorBlocker"
	lock_room.enemies.add_child(blocker)
	blocker.set_physics_process(false)
	blocker.global_position = cmd_door.global_position + Vector3(0, 0.05, 0)
	await frames(2)
	Fixture.place(lp, lock_room.level.marker(&"checkpoint", &"entry"))
	await frames(4)
	assert(not cmd_door.locked and not lock_room.events.fired.has("lock_cmd"), "lock_door defers while doorway is occupied")

	# Move blocker clear -> _pending_locks retries and locks door cleanly.
	blocker.global_position = lock_room.level.marker(&"gate", &"entry")
	await frames(4)
	assert(cmd_door.locked and lock_room.events.fired.has("lock_cmd"), "Deferred lock_door completes once doorway clears")
	assert(lock_room.hud.squad_toast_label.text == "COMMAND WING SEALED")

	var probe := CharacterBody3D.new()
	lock_room.level.add_child(probe)
	probe.global_position = lock_room.level.marker(&"cmd_antechamber", &"entry")
	var nav := LevelNavigator.new(probe, lock_room.level)
	nav.next_position(lock_room.level.marker(&"cmd_command", &"entry"), 1.0 / 60.0)
	assert(nav.status == "blocked_door", "TA-3 sees door locked by lock_door trigger")

	lock_room.queue_free()
	await frames(3)


func test_acoustics_contract() -> void:
	net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION)
	main.current_lobby._on_start_game_pressed()
	var room := await start_mission()
	var player := room.players_container.get_node("1") as PlayerController3D
	player.set_physics_process(false)
	for e in room.enemies.get_children():
		e.queue_free()
	await frames(2)

	var jaffa_scene := load("res://scenes/entities/JaffaGuard.tscn") as PackedScene
	var jaffa := jaffa_scene.instantiate() as JaffaAI
	jaffa.name = "AcousticsSentry"
	var door := Fixture.door(room)
	door.sync_security_state(false, false)
	var ante_spot := room.level.marker(&"cmd_antechamber", &"entry")
	var cmd_spot := room.level.marker(&"cmd_command", &"entry")
	room.enemies.add_child(jaffa)
	jaffa.global_position = ante_spot + Vector3(0, 0.05, 0)
	jaffa.start_patrol([ante_spot])
	await frames(2)

	# 1. Closed ModularDoor attenuates by CLOSED_DOOR_ATTENUATION vs open ModularDoor.
	var closed_rep := LevelAcoustics.analyze(room.get_world_3d(), room.level, cmd_spot, jaffa.global_position)
	assert(int(closed_rep["closed_door_count"]) >= 1 or float(closed_rep["corridor_effective"]) > float(closed_rep["direct"]))
	door.sync_security_state(true, false)
	var open_rep := LevelAcoustics.analyze(room.get_world_3d(), room.level, cmd_spot, jaffa.global_position)
	assert(is_equal_approx(float(open_rep["effective"]) + LevelAcoustics.CLOSED_DOOR_ATTENUATION, float(closed_rep["effective"])) or float(open_rep["effective"]) < float(closed_rep["effective"]) - 1.0,
		"Opening ModularDoor reduces effective acoustic distance (%s vs %s)" % [open_rep["effective"], closed_rep["effective"]])

	# Threshold noise: blocked when door is closed, heard when door is open!
	var threshold_radius := (float(open_rep["effective"]) + float(closed_rep["effective"])) * 0.5
	door.sync_security_state(false, false)
	await frames(2)
	jaffa.hear(cmd_spot, threshold_radius, player)
	assert(not jaffa.investigating, "Closed door blocks borderline noise")
	door.sync_security_state(true, false)
	await frames(2)
	jaffa.hear(cmd_spot, threshold_radius, player)
	assert(jaffa.investigating, "Opening door allows borderline noise to propagate")

	# 2. Same-room props do NOT muffle sound.
	var direct_same := LevelAcoustics.analyze(room.get_world_3d(), room.level, ante_spot + Vector3(1.5, 0, 0), jaffa.global_position)
	assert(is_equal_approx(float(direct_same["effective"]), float(direct_same["direct"])))
	assert(int(direct_same["wall_count"]) == 0)

	# 3. Cross-world MissionWorld isolation rejects noise from an unlinked world node.
	var other_world := Node3D.new()
	other_world.add_to_group(MissionWorld.GROUP)
	var alien_src := Node3D.new()
	other_world.add_child(alien_src)
	root.add_child(other_world)
	jaffa.investigating = false
	jaffa.perception.calm()
	jaffa.hear(ante_spot, 20.0, alien_src)
	assert(not jaffa.investigating, "Noise source from another MissionWorld is ignored")
	other_world.queue_free()

	main.queue_free()
	await frames(3)


func run() -> void:
	validate_data()
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	assert(net.host_game(0) == OK)

	await test_acoustics_contract()
	await test_runtime_triggers()

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	net.disconnect_game()
	await frames(2)
	print("PASS EV-2 general triggers & wall/door acoustics")
	await preload("res://tests/support/finish.gd").success(self)
