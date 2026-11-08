extends SceneTree
var world: GateRoom
var gate: StargateRing
var waves: WaveManager
var dialer: SGCDialingConsole
var player: PlayerController3D

func _init() -> void:
	call_deferred("run_test")

func frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame

func run_test() -> void:
	world = load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(world)
	gate = world.get_node("Stargate") as StargateRing
	waves = world.get_node("WaveManager") as WaveManager
	waves.set_physics_process(false)
	dialer = world.dhd_console as SGCDialingConsole
	player = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "1"
	world.get_node("Players").add_child(player)
	player.set_physics_process(false)
	waves.set_difficulty(WaveManager.DifficultyTier.EASY)
	assert(waves.target_activations == 3, "Easy requires at least three incursions")
	dialer.start_dialing(player)
	assert(dialer.current_phase == DHDDialer.DialPhase.INACTIVE, "Fast staging dialout cannot bypass minimum waves")
	for count: int in range(3):
		waves.completed_incursions = count
		assert(not waves.requirements_met(), "Fewer than 3 waves cannot extract")
	waves.completed_incursions = 3
	assert(waves.requirements_met(), "Easy unlocks after three waves")
	waves.set_difficulty(WaveManager.DifficultyTier.MEDIUM)
	assert(not waves.requirements_met(), "Medium additionally requires computer upgrade")
	player.is_carrying_patch_rom = true
	dialer.start_patch_upload(player)
	assert(dialer.is_uploading_patch, "ROM holder can upgrade computer")
	assert(dialer.update_upload(10.1), "Upgrade requires the timed upload")
	assert(waves.requirements_met(), "Medium unlocks after minimum waves plus upgrade")
	waves.set_difficulty(WaveManager.DifficultyTier.HARD)
	assert(not waves.requirements_met(), "Hard additionally requires under-fire iris repair")
	var servo: IrisServoHousing = world.get_node("IrisServoHousing") as IrisServoHousing
	servo.start_repair(player)
	assert(not servo.is_repairing, "Hard cannot pre-stage iris repair during safe staging")
	gate.reserve_connection(true)
	gate.sync_trigger_kawoosh()
	gate._finish_kawoosh(gate.activation_id)
	waves.is_wormhole_open = true
	waves.is_wave_active = true
	waves.incursion_established = true
	waves.inbound_wormhole_timer = 38
	assert(gate.event_horizon_mesh.visible, "Stable incoming horizon stays visible")
	var extracted: Array[bool] = [false]
	gate.player_extracted.connect(func(_p: Node) -> void: extracted[0] = true)
	gate._on_extraction_entered(player)
	assert(not extracted[0], "Incoming wormholes cannot extract players")
	servo.start_repair(player)
	assert(servo.is_repairing, "Hard allows repair under incoming fire")
	for _stage: int in range(3):
		servo.update_repair(2.6)
	assert(waves.iris_repaired_under_fire, "Under-fire repair objective must be earned")
	assert(waves.requirements_met(), "Hard needs all cumulative objectives")
	waves.pending_column_spawns = 6
	waves.enemies_alive = 6
	gate.close_wormhole()
	assert(not waves.is_wormhole_open and waves.pending_column_spawns == 0, "Closure atomically clears incoming spawn queue")
	var before: int = world.get_node("Enemies").get_child_count()
	waves._spawn_ramp_reinforcements(2)
	waves._spawn_wave_jaffa(2)
	waves._spawn_next_column_rank()
	assert(world.get_node("Enemies").get_child_count() == before, "No spawner can create Jaffa with a closed gate")
	# Outbound reservation blocks recharge races immediately, not only after chevron 7.
	waves.is_wave_active = false
	dialer.start_dialing(player)
	assert(dialer.current_phase == DHDDialer.DialPhase.CHEVRONS, "Objectives grant dialing")
	assert(waves.outbound_reserved and gate.direction == StargateRing.GateDirection.OUTBOUND, "Dial start owns gate atomically")
	var wave: int = waves.current_wave
	waves.start_next_wave()
	assert(waves.current_wave == wave, "Incoming cannot steal an outbound reservation")
	for _glyph: int in range(7):
		dialer.input_glyph(dialer.chevron_sequence[dialer.current_chevron_index])
	gate._finish_kawoosh(gate.activation_id)
	assert(gate.event_horizon_mesh.visible and not gate.extraction_authorized, "Outbound horizon persists while GDO is pending")
	for _beat: int in range(4):
		dialer.input_glyph(dialer.gdo_sequence[dialer.gdo_index])
	assert(gate.extraction_authorized, "Successful GDO authorizes extraction")
	gate._on_extraction_entered(player)
	assert(extracted[0], "Authorized outbound wormhole can extract")
	waves.end_mission()
	# Closing during Kawoosh must kill the old stabilization callback.
	gate.reserve_connection(true)
	gate.sync_trigger_kawoosh()
	var stale: int = gate.activation_id
	gate.close_wormhole()
	gate._finish_kawoosh(stale)
	assert(gate.current_state == StargateRing.GateState.INACTIVE and not gate.event_horizon_mesh.visible, "Stale callbacks cannot reopen a closed gate")
	# Closing during inbound chevrons must not spawn after its awaited timers resume.
	waves.mission_ended = false
	waves.outbound_reserved = false
	waves.is_wave_active = false
	waves.start_next_wave()
	assert(not waves.is_iris_repaired and waves.iris_repaired_under_fire, "Later breaches re-jam physical iris without erasing Hard objective")
	waves.end_mission()
	await frames(180)
	assert(not gate.event_horizon_mesh.visible and world.get_node("Enemies").get_child_count() == before, "Mission end cancels pending sequence and all future spawning")
	world.queue_free()
	await process_frame
	print("PASS gate lifecycle, persistent horizon, spawn exclusion, three objective tiers and cancellation")
	quit(0)
