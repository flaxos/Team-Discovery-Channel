extends SceneTree


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func run() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	assert(
		(
			net.parse_cli_arguments(PackedStringArray(["--mission", "sgc_uat"])).get("mission")
			== SGCNetworkManager.MISSION_SGC_UAT
		)
	)
	net.parse_cli_arguments(PackedStringArray(["--mission", "unknown"]))
	assert(net.selected_mission_id == SGCNetworkManager.MISSION_SGC_UAT)
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	var lobby := main.current_lobby as LobbyUI
	assert(lobby.mission_option_button.item_count == 3)
	lobby._on_mission_selected(1)
	assert(net.selected_mission_id == SGCNetworkManager.MISSION_SGC_UAT)
	assert(lobby.difficulty_option_button.disabled)
	assert("No automatic hostile" in lobby.mission_description_label.text)
	for control: Control in [
		lobby.mission_option_button,
		lobby.mission_description_label,
		lobby.host_button,
		lobby.roster_list,
		lobby.keybindings_button
	]:
		assert(
			root.get_visible_rect().encloses(control.get_global_rect()),
			"Mission controls must fit lobby viewport: " + str(control.name)
		)
	assert(not net.set_mission("unknown"))
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	var room := main.current_gate_room as GateRoom
	assert(room.mission_id == SGCNetworkManager.MISSION_SGC_UAT)
	assert(room.scene_file_path == "res://scenes/main/SGCUATBase.tscn")
	var map := room.get_node("SGCMap") as SGCMap
	if not map.ready_for_navigation:
		await map.navigation_ready
	assert(map.definition.region(&"STAGING").floor_number == 26)
	assert(room.get_node("Players").get_child_count() == 1)
	room._trigger_base_scramble()
	room.wave_manager.start_wave_defense()
	room.wave_manager.start_next_wave()
	await frames(1800)
	assert(room.get_node("Enemies").get_child_count() == 0)
	assert(not room.wave_manager.defense_started and not room.wave_manager.is_wave_active)
	assert(room.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(not room.is_emergency_active)
	assert(net.request_restart_game())
	await frames(5)
	room = main.current_gate_room as GateRoom
	assert(room.mission_id == SGCNetworkManager.MISSION_SGC_UAT)
	assert(not room.wave_manager.hostile_gate_activation_enabled)
	# Switch to a fresh defense session and prove its activation path remains enabled.
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._clear_gate_room()
	net.disconnect_game()
	assert(net.set_mission(SGCNetworkManager.MISSION_SGC_DEFENSE))
	assert(net.host_game(0) == OK)
	net.mission_started = true
	main._load_gate_room()
	room = main.current_gate_room as GateRoom
	assert(room.wave_manager.hostile_gate_activation_enabled)
	room._trigger_base_scramble()
	assert(room.wave_manager.defense_started)
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS mission menu, real UAT dispatch, 30s quiet gate, retry and defense activation")
	await preload("res://tests/support/finish.gd").success(self)
