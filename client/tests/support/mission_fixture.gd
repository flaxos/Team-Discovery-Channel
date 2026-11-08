extends RefCounted
## These UI/console fixtures test an already-earned extraction window.
## test_gate_three_wave_extraction separately earns it through actual wave progression.
static func extraction_ready(world: Node) -> void:
	var waves: Node = world.get_node("WaveManager")
	waves.sequence_token += 1
	waves.is_wave_active = false
	waves.is_wormhole_open = false
	waves.is_intermission = false
	waves.pending_column_spawns = 0
	waves.mission_ended = false
	waves.completed_incursions = waves.target_activations
	waves.computer_upgraded = true
	waves.iris_repaired_under_fire = true
	world.get_node("Stargate").close_wormhole()
	var dialer: Node = world.dhd_console
	if dialer.has_method("set_buffer_corrupted"):
		dialer.set_buffer_corrupted(false)
