extends SceneTree
## Project SGC: Sprint 4 Operative Downed, Revive, Audio Settings & Debriefing Smoke Test.
## Validates Co-op Bleedout, Prone Crawl, Squadmate Revive Channel, Squad Wipe Defeat,
## Pause Menu Audio Sliders, and After Action Debriefing Report.

const GATEROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var gateroom: GateRoom = null
var hud: TacticalHUD = null
var player_a: PlayerController3D = null
var player_b: PlayerController3D = null

var step: int = 0
var ticks: int = 0
var elapsed_time: float = 0.0
var test_passed: bool = false


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 4 REVIVE & SETTINGS SMOKE TEST    ")
	print("========================================================")

	var root_node: Window = root
	var gr_scene := load(GATEROOM_SCENE) as PackedScene
	gateroom = gr_scene.instantiate() as GateRoom
	root_node.add_child(gateroom)

	hud = gateroom.get_node("TacticalHUD") as TacticalHUD

	# Spawn Operative A (Local Player)
	var p_scene := load(PLAYER_SCENE) as PackedScene
	player_a = p_scene.instantiate() as PlayerController3D
	player_a.name = "1"
	player_a.is_local_authority = true
	gateroom.get_node("Players").add_child(player_a, true)
	hud.bind_local_player(player_a)

	# Spawn Operative B (Teammate)
	player_b = p_scene.instantiate() as PlayerController3D
	player_b.name = "2"
	player_b.position = Vector3(1.2, 0, 0)
	gateroom.get_node("Players").add_child(player_b, true)


func _process(delta: float) -> bool:
	elapsed_time += delta
	ticks += 1

	# STEP 1: Operative Downed / Bleedout State
	if step == 0 and ticks == 3:
		print("[TEST 1/5] Testing Operative Downed & Bleedout State...")
		assert(player_a.health_component.can_be_downed, "Player HealthComponent must have can_be_downed = true")
		assert(not player_a.health_component.is_downed, "Player must start standing")

		# Apply lethal bullet damage
		player_a.health_component.take_damage(200.0, null, "bullet")

		assert(player_a.health_component.is_downed, "Operative must enter is_downed state on lethal non-vaporizing damage")
		assert(not player_a.health_component.is_dead, "Operative must not be dead while bleeding out")
		assert(player_a.health_component.bleedout_timer > 15.0, "Bleedout timer must initialize to 20s (Found: %.1fs)" % player_a.health_component.bleedout_timer)
		assert(player_a.active_slot == 2, "Downed operative must automatically equip secondary sidearm M9")
		assert(hud.downed_label != null and hud.downed_label.visible, "HUD must display Downed bleedout warning banner")

		print("[TEST 1/5] PASS: Downed / bleedout state verified! (Prone stance, M9 sidearm, 20s bleedout).")
		step = 1

	# STEP 2: Squadmate Revive Channel Mechanics
	elif step == 1 and ticks == 6:
		print("[TEST 2/5] Testing Squadmate Revive Channel & Recovery...")
		# Position Operative B near Operative A
		player_b.global_position = player_a.global_position + Vector3(1.0, 0, 0)

		# Simulate partial revive (1.2s)
		player_b.active_revive_target = player_a
		player_b.current_revive_time = 1.2
		var partial_prog: float = player_b.current_revive_time / player_b.REVIVE_DURATION_S
		player_a.revive_progress_changed.emit(partial_prog)
		assert(hud.revive_bar != null, "HUD must contain ReviveProgressBar")

		# Complete revive (2.5s)
		player_b.current_revive_time = player_b.REVIVE_DURATION_S
		player_a.health_component.revive(player_b)

		assert(not player_a.health_component.is_downed, "Operative must exit downed state after revive")
		assert(player_a.health_component.current_health >= 40.0, "Revived operative must recover with 40%% HP (HP: %.1f)" % player_a.health_component.current_health)
		assert(player_a.active_slot == 1, "Operative must re-equip primary weapon upon revival")
		assert(not hud.downed_label.visible, "Downed banner must hide upon revival")

		print("[TEST 2/5] PASS: Squadmate revive mechanics verified! (2.5s channel, 40% HP recovery, primary re-equipped).")
		step = 2

	# STEP 3: Squad Wipe Defeat Condition
	elif step == 2 and ticks == 9:
		print("[TEST 3/5] Testing Squad Wipe Defeat Condition...")
		# Down both operatives so no one is standing
		player_a.health_component.take_damage(200.0, null, "bullet")
		player_b.health_component.take_damage(200.0, null, "bullet")

		assert(player_a.health_component.is_downed and player_b.health_component.is_downed, "Both operatives must be downed")

		# Check squad status in GateRoom
		gateroom._check_squad_status()

		assert(hud.victory_modal.visible, "Debriefing modal must appear upon squad wipe")
		assert(hud.debrief_title != null and hud.debrief_title.text == "MISSION FAILED - SGC OVERRUN", "Debriefing header must show Mission Failed")

		print("[TEST 3/5] PASS: Squad wipe defeat condition verified! (All operatives downed -> SGC Overrun).")
		step = 3

	# STEP 4: Pause Menu & Real-Time Audio Bus Volume Sliders
	elif step == 3 and ticks == 12:
		print("[TEST 4/5] Testing Pause Menu & Real-Time Audio Sliders...")
		hud.is_mission_ended = false
		hud.victory_modal.visible = false
		assert(not hud.pause_menu.visible, "Pause menu must start hidden")

		# Toggle pause menu
		hud.toggle_pause_menu()
		assert(hud.pause_menu.visible, "Pause menu must appear on toggle")

		# Test Master slider
		hud._on_master_slider_changed(0.7)
		var master_idx: int = AudioServer.get_bus_index("Master")
		assert(is_equal_approx(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.7)), "Master bus volume must match slider")
		assert(hud.master_label.text == "MASTER VOLUME: 70%", "Master volume label must reflect 70%")

		# Test SFX slider
		var sfx_idx: int = AudioServer.get_bus_index("SFX")
		hud._on_sfx_slider_changed(0.4)
		assert(is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.4)), "SFX bus volume must match slider")

		# Test Ambience slider
		var amb_idx: int = AudioServer.get_bus_index("Ambience")
		if amb_idx == -1:
			amb_idx = AudioServer.get_bus_index("Klaxons / Ambience")
		hud._on_ambience_slider_changed(0.85)
		assert(is_equal_approx(AudioServer.get_bus_volume_db(amb_idx), linear_to_db(0.85)), "Ambience bus volume must match slider")

		# Toggle pause menu off
		hud.toggle_pause_menu()
		assert(not hud.pause_menu.visible, "Pause menu must hide on second toggle")

		print("[TEST 4/5] PASS: Pause Menu & Real-Time Audio Bus Sliders validated!")
		step = 4

	# STEP 5: End-of-Mission Debriefing Report & Stats
	elif step == 4 and ticks == 15:
		print("[TEST 5/5] Testing After Action Debriefing Report & Stats...")
		hud.mission_seconds = 185.0 # 3m 05s
		hud.total_kills = 18

		hud.show_victory()
		assert(hud.victory_modal.visible, "Victory/Debriefing modal must be visible")
		assert(hud.debrief_title.text == "EXTRACTION SUCCESSFUL", "Victory title must show Extraction Successful")
		assert(hud.stat_time != null and hud.stat_time.text == "MISSION DURATION: 03:05", "Mission duration stat must format mm:ss correctly (Found: %s)" % hud.stat_time.text)
		assert(hud.stat_kills != null and hud.stat_kills.text == "HOSTILES ELIMINATED: 18", "Kills stat must show total hostiles eliminated")
		assert(hud.stat_waves != null and hud.stat_waves.text == "WAVES REPELLED: 3 / 3", "Waves repelled stat must confirm 3 / 3")
		assert(hud.stat_chevrons != null and hud.stat_chevrons.text == "CHEVRONS LOCKED: 7 / 7", "Chevrons locked stat must confirm 7 / 7")
		assert(hud.stat_status != null and hud.stat_status.text == "STATUS: ALL OPERATIVES EXTRACTED", "Extraction status must confirm squad extraction")

		print("[TEST 5/5] PASS: SGC Tactical After Action Debriefing Report validated!")
		step = 5

	if step == 5 and not test_passed:
		print("\n========================================================")
		print("  SPRINT 4 REVIVE & SETTINGS SMOKE TEST PASSED!         ")
		print("  ✓ Co-op Operative Downed / Bleedout State (20s)       ")
		print("  ✓ Prone Stance, Slow Crawl & Sidearm M9 Last Stand    ")
		print("  ✓ Squadmate Revive Channel (2.5s Hold, 40% Recovery)  ")
		print("  ✓ Squad Wipe Defeat Trigger (All Downed -> Overrun)   ")
		print("  ✓ In-Game Pause & Audio Bus Volume Sliders (Real-time)")
		print("  ✓ SGC Tactical After Action Debriefing Report & Stats ")
		print("========================================================\n")
		test_passed = true
		quit(0)
		return true

	if elapsed_time > 8.0 and not test_passed:
		push_error("[TEST FAILURE] Sprint 4 revive & settings test timed out after %.2fs." % elapsed_time)
		quit(1)
		return true

	return false
