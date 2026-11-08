extends SceneTree
func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(world)
	var waves: WaveManager = world.wave_manager
	var gate: StargateRing = world.stargate_mesh
	var dialer: DHDDialer = world.dhd_console
	var player := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "1"
	player.position = Vector3(0, 0.95, 15)
	world.players_container.add_child(player)
	player.set_physics_process(false)
	gate.kawoosh_duration_s = 0.05
	waves.wormhole_duration_s = 0.18
	waves.inter_gate_recharge_s = 0.2
	waves.rank_spawn_interval = 100
	waves.stream_spawn_interval = 100
	waves.set_difficulty(WaveManager.DifficultyTier.EASY)
	waves.start_wave_defense()
	for expected: int in range(1, 4):
		for _frame: int in range(300):
			await physics_frame
			if waves.is_wormhole_open:
				break
		assert(waves.is_wormhole_open and gate.current_state == StargateRing.GateState.ACTIVE, "Real inbound sequence must stabilize before combat")
		assert(gate.event_horizon_mesh.visible and waves.current_wave == expected, "Each required incursion must have a visible gate")
		assert(waves.enemies_alive >= 4 and world.get_node("Enemies").get_child_count() >= 2, "Each wave must field actual initial hostiles and pending ranks")
		assert(waves.pending_column_spawns > 0, "Fixture must exercise pending-rank cancellation")
		if expected < 3:
			dialer.start_dialing(player)
			assert(dialer.current_phase == DHDDialer.DialPhase.INACTIVE, "Early waves cannot be bypassed by a fast dial")
		for child: Node in world.get_node("Enemies").get_children():
			var enemy := child as JaffaAI
			if enemy != null and not enemy.health_component.is_dead:
				enemy.health_component.take_damage(99999, player, "test")
		for _frame: int in range(60):
			await physics_frame
			if waves.completed_incursions == expected:
				break
		assert(waves.completed_incursions == expected, "Actual hostile kills plus natural gate closure must earn each wave")
		assert(waves.pending_column_spawns == 0 and not gate.event_horizon_mesh.visible, "Expired gates must discard unspawned ranks and hide the horizon")
	assert(waves.requirements_met(), "Third actual cleared wave unlocks Easy")
	dialer.start_dialing(player)
	assert(waves.outbound_reserved, "Qualified player can reserve outbound during recharge")
	for _glyph: int in range(7):
		dialer.input_glyph(dialer.chevron_sequence[dialer.current_chevron_index])
	for _beat: int in range(4):
		dialer.input_glyph(dialer.gdo_sequence[dialer.gdo_index])
	for _frame: int in range(15):
		await physics_frame
	assert(gate.current_state == StargateRing.GateState.ACTIVE and gate.extraction_authorized, "Real third-wave progression permits authorized outbound aperture")
	var current_wave: int = waves.current_wave
	waves._physics_process(100.0)
	assert(waves.current_wave == current_wave and waves.pending_column_spawns == 0, "Outbound ownership excludes new incoming activations")
	waves.end_mission()
	world.queue_free()
	await process_frame
	print("PASS three real Easy incursions, kills, rank cancellation, early-dial exclusion and outbound extraction")
	quit(0)
