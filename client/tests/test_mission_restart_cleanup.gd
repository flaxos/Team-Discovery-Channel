extends SceneTree
## Scene retries must retire the old gate lifecycle and collision world.
func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var net: SGCNetworkManager = root.get_node("NetworkManager") as SGCNetworkManager
	net.is_dedicated_server = true
	net.mission_started = false
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.mission_started, "Dedicated direct initialization must mark its mission active")
	net.is_dedicated_server = false
	main._load_gate_room()
	var previous: GateRoom = main.current_gate_room as GateRoom
	var manager: WaveManager = previous.wave_manager
	main._load_gate_room()
	assert(manager.mission_ended, "Replacing the world must terminate its mission lifecycle")
	assert(not previous.is_inside_tree(), "Old world must detach before replacement takes multiplayer paths")
	assert(main.world_container.get_child_count() == 1, "Retry must not duplicate collision worlds")
	assert(main.current_gate_room != previous and main.current_gate_room.name == "GateRoom", "Replacement must retain canonical network node path")
	await process_frame
	assert(not is_instance_valid(previous), "Old world must be freed after retry")
	main._load_lobby()
	assert(main.world_container.get_child_count() == 0, "Returning to the lobby must retire gameplay world")
	main.queue_free()
	await process_frame
	net.mission_started = false
	print("PASS retry lifecycle termination, world replacement and lobby cleanup")
	quit(0)
