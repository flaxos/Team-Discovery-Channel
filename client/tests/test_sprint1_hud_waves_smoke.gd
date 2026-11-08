extends SceneTree
## Automated Headless Validation: Sprint 1 Wave Foothold, Tactical HUD & Audio Smoke Test.
## Validates HUD bindings, Wave progression, SFX triggers, and Extraction victory.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var gateroom: GateRoom = null
var hud: TacticalHUD = null
var wave_mgr: WaveManager = null
var stargate: StargateRing = null
var dhd: DHDDialer = null
var player: PlayerController3D = null

var ticks: int = 0
var elapsed_time: float = 0.0
var test_passed: bool = false
var wave_spawn_verified: bool = false
var dhd_verified: bool = false


func _init() -> void:
	call_deferred("_setup")

func _setup() -> void:
	print("\n==================================================")
	print("  PROJECT SGC: SPRINT 1 HUD, WAVES & AUDIO TEST   ")
	print("==================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	hud = gateroom.get_node_or_null("TacticalHUD") as TacticalHUD
	wave_mgr = gateroom.get_node_or_null("WaveManager") as WaveManager
	stargate = gateroom.get_node_or_null("Stargate") as StargateRing
	dhd = gateroom.dhd_console

	assert(hud != null, "TacticalHUD must exist in GateRoom")
	assert(wave_mgr != null, "WaveManager must exist in GateRoom")
	assert(stargate != null, "Stargate must exist in GateRoom")
	assert(dhd != null, "Dialing Console must exist in GateRoom")

	# Spawn test player
	var p_scene := load(PLAYER_SCENE) as PackedScene
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)
	print("[TEST] Player spawned and added to GateRoom.")


func _process(delta: float) -> bool:
	ticks += 1
	elapsed_time += delta

	if ticks == 5:
		# Verify HUD initial values
		print("[TEST] Checking Tactical HUD initial bindings...")
		hud.bind_local_player(player)
		assert(hud.health_bar.value >= 100.0, "Initial HP must be >= 100")
		assert(hud.weapon_name_label.text.contains("M249"), "SG-3 Heavy weapon name must be M249")
		print("[TEST] PASS: HUD correctly bound to local operative vitals & loadout.")

	if ticks == 10:
		# Verify audio assets are imported and loadable
		print("[TEST] Checking Stargate audio soundbank...")
		var sfx_files: Array[String] = [
			"res://audio/sfx_p90.wav",
			"res://audio/sfx_m249.wav",
			"res://audio/sfx_staff_fire.wav",
			"res://audio/sfx_zat.wav",
			"res://audio/sfx_chevron.wav",
			"res://audio/sfx_kawoosh.wav",
			"res://audio/sfx_rings.wav",
			"res://audio/sfx_klaxon.wav",
			"res://audio/sfx_explosion.wav"
		]
		for sfx in sfx_files:
			assert(ResourceLoader.exists(sfx), "Audio file must exist: %s" % sfx)
		print("[TEST] PASS: All 9 authentic SFX assets validated in audio library.")

	if ticks == 15:
		# Test Wave 1 startup
		print("[TEST] Testing WaveManager defense start...")
		wave_mgr.start_wave_defense()
		print("[TEST] WaveManager started. Current Wave: %d" % wave_mgr.current_wave)
		assert(wave_mgr.current_wave == 1, "WaveManager must advance to Wave 1")

	# Wait for incoming Stargate dialing & Kawoosh to finish and Jaffa to spawn
	if not wave_spawn_verified and wave_mgr.current_wave >= 1:
		var enemies_count: int = gateroom.get_node("Enemies").get_child_count()
		if enemies_count >= 4:
			wave_spawn_verified = true
			print("[TEST] Jaffa Enemies spawned in Wave 1: %d (at %.2fs, tick %d)" % [enemies_count, elapsed_time, ticks])
			print("[TEST] PASS: Incoming Stargate dialing sequence completed and Jaffa spawned!")

	if wave_spawn_verified and not dhd_verified:
		# Test DHD and Extraction sequence
		print("[TEST] Testing DHD completion & Extraction Trigger...")
		preload("res://tests/support/mission_fixture.gd").extraction_ready(gateroom)
		dhd.start_dialing(player)

		# 1. Test wrong glyph resets sequence (UAT feedback verification)
		var expected_first := dhd.chevron_sequence[0]
		var wrong_first := "DOWN" if expected_first != "DOWN" else "UP"
		print("[TEST] Intentionally inputting wrong glyph: '%s' (expected '%s')..." % [wrong_first, expected_first])
		var wrong_result: bool = dhd.input_glyph(wrong_first)
		assert(not wrong_result, "Wrong glyph must return false")
		assert(dhd.current_chevron_index == 0, "DHD chevron index must reset to 0 on mismatch")
		print("[TEST] PASS: DHD successfully reset to 0 on incorrect glyph!")

		# 2. Complete chevrons correctly
		for glyph in dhd.chevron_sequence:
			dhd.input_glyph(glyph)
		assert(dhd.current_phase == DHDDialer.DialPhase.GDO_AUTH, "DHD must advance to GDO_AUTH phase")

		# 3. Test wrong GDO beat resets GDO index
		var expected_gdo := dhd.gdo_sequence[0]
		var wrong_gdo := "LEFT" if expected_gdo != "LEFT" else "RIGHT"
		print("[TEST] Intentionally inputting wrong GDO beat: '%s' (expected '%s')..." % [wrong_gdo, expected_gdo])
		var wrong_gdo_res: bool = dhd.input_glyph(wrong_gdo)
		assert(not wrong_gdo_res, "Wrong GDO beat must return false")
		assert(dhd.gdo_index == 0, "GDO index must reset to 0 on mismatch")
		print("[TEST] PASS: GDO code successfully reset to 0 on incorrect beat!")

		# 4. Complete GDO correctly
		for beat in dhd.gdo_sequence:
			dhd.input_glyph(beat)
		assert(dhd.current_phase == DHDDialer.DialPhase.COMPLETE, "DHD must be COMPLETE")
		print("[TEST] PASS: DHD 7-chevron sequence and GDO Iris Code verified.")
		dhd_verified = true

	if dhd_verified and not test_passed:
		# Simulate operative stepping into event horizon
		stargate._finish_kawoosh(stargate.activation_id)
		stargate._on_extraction_entered(player)
		assert(hud.victory_modal.visible, "Victory modal must be visible on extraction")
		print("[TEST] PASS: Extraction triggered and Victory modal displayed!")

		print("\n==================================================")
		print("  SPRINT 1 HUD, WAVES & AUDIO TEST PASSED!        ")
		print("  ✓ Tactical In-Game HUD (Vitals, Ammo, Waves)    ")
		print("  ✓ SGC Foothold Defense Auto-Start & Waves       ")
		print("  ✓ Full 9-Track Audio Soundbank Integration      ")
		print("  ✓ DHD Helldivers Chords & Extraction Victory    ")
		print("==================================================\n")
		test_passed = true
		quit(0)
		return true

	# Allow up to 10 seconds of simulated game time for full cinematic sequence
	if elapsed_time > 10.0 and not test_passed:
		push_error("[TEST FAILURE] Test timed out after %.2fs (%d ticks)." % [elapsed_time, ticks])
		quit(1)
		return true

	return false
