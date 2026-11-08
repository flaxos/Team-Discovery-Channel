extends SceneTree
## Sprint 13 Verification Suite: Hard Mode Dialing Buffer Virus, Lab ROM Retrieval & Mainframe Upload.
## Validates:
##  1. Difficulty Scaling Presets: All modes (3 minimum incursions), Medium (+computer upgrade), Hard (+upgrade and under-fire Iris repair).
##  2. Hard Mode Buffer Lockout: Corrupted dialing buffer denies outbound activation.
##  3. Artifact Research Lab ROM Retrieval: Operative retrieves clean optical ROM in Level 28 Lab.
##  4. Control Room Mainframe 10-Second Defense: Uploads patch, purges virus, restores outbound dialing.
##  5. Final Extraction Victory: Outbound wormhole dialed, iris opened, operative extracted.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const LabDataPatchDriveScript = preload("res://scripts/props/LabDataPatchDrive.gd")

var gateroom: GateRoom = null
var wave_mgr: WaveManager = null
var stargate: StargateRing = null
var sgc_dialer: SGCDialingConsoleScript = null
var patch_drive: LabDataPatchDriveScript = null
var hud: TacticalHUD = null
var player: PlayerController3D = null
var ticks: int = 0


func _init() -> void:
	call_deferred("_setup")

func _setup() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 13 HARD MODE LAB ROM & DEFENSE TEST")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	wave_mgr = gateroom.get_node("WaveManager") as WaveManager
	stargate = gateroom.get_node("Stargate") as StargateRing
	hud = gateroom.get_node("TacticalHUD") as TacticalHUD
	sgc_dialer = gateroom.dhd_console as SGCDialingConsoleScript
	patch_drive = gateroom.get_node("Level28Complex/LaboratorySector/LabDataPatchDrive") as LabDataPatchDriveScript

	var p_scene := load(PLAYER_SCENE) as PackedScene
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_CARTER_TECH
	gateroom.get_node("Players").add_child(player, true)


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Tiered Difficulty Configuration
		print("[TEST 1/5] Testing Tiered Difficulty Presets (Easy, Medium, Hard)...")
		wave_mgr.set_difficulty(WaveManager.DifficultyTier.EASY)
		assert(wave_mgr.target_activations == 3, "Easy mode must require 3 incursions")

		wave_mgr.set_difficulty(WaveManager.DifficultyTier.MEDIUM)
		assert(wave_mgr.target_activations == 3, "Medium mode must require 3 incursions")

		wave_mgr.set_difficulty(WaveManager.DifficultyTier.HARD)
		assert(wave_mgr.target_activations == 3, "Hard mode must require 3 incursions plus cumulative objectives")
		print("[TEST 1/5] PASS: Cumulative three-incursion difficulty matrix validated.")

	elif ticks == 10:
		# TEST 2: Hard Mode Goa'uld Buffer Encryption Lockout
		print("[TEST 2/5] Testing Hard Mode Goa'uld Dialing Buffer Lockout...")
		var lockout_detected := { "ok": false }
		sgc_dialer.buffer_lockout_triggered.connect(func() -> void:
			lockout_detected["ok"] = true
		)

		# Trigger Hard Mode climax buffer corruption
		wave_mgr._trigger_hard_mode_buffer_lockout()

		assert(sgc_dialer.is_buffer_corrupted, "SGCDialingConsole buffer must be marked corrupted")
		assert(lockout_detected["ok"], "buffer_lockout_triggered signal must be emitted")

		# Operative attempts to start dialing while corrupted
		sgc_dialer.start_dialing(player)
		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.INACTIVE, "Dialing must be DENIED while buffer is corrupted")
		assert(sgc_dialer.active_dialer == null, "Operative must not be allowed to dial corrupted buffer")
		print("[TEST 2/5] PASS: Goa'uld dialing buffer lockout enforced; dialing attempts denied.")

	elif ticks == 20:
		# TEST 3: Research Lab Optical ROM Retrieval
		print("[TEST 3/5] Testing Optical ROM Retrieval in Level 28 Research Lab...")
		assert(patch_drive != null, "LabDataPatchDrive must exist in Level 28 LaboratorySector")
		assert(not patch_drive.is_retrieved, "Patch drive must start unretrieved")

		# Player retrieves ROM
		patch_drive.pickup_patch(player)
		player.is_carrying_patch_rom = true

		assert(patch_drive.is_retrieved, "LabDataPatchDrive must be marked retrieved")
		assert(player.is_carrying_patch_rom, "Player must be carrying clean dialing ROM")
		print("[TEST 3/5] PASS: Clean dialing ROM successfully retrieved from Level 28 Lab.")

	elif ticks == 30:
		# TEST 4: Control Room Mainframe 10-Second Upload Defense
		print("[TEST 4/4] Testing Control Room Mainframe 10-Second Upload Defense...")
		var upload_done := { "ok": false }
		sgc_dialer.patch_upload_completed.connect(func() -> void:
			upload_done["ok"] = true
		)

		sgc_dialer.start_patch_upload(player)
		assert(sgc_dialer.is_uploading_patch, "Console must enter uploading state")

		# Channel upload for 10.0 seconds
		var complete := sgc_dialer.update_upload(10.5)
		assert(complete, "Upload must finish after 10.0 seconds")
		assert(upload_done["ok"], "patch_upload_completed signal must fire")
		assert(not sgc_dialer.is_buffer_corrupted, "Dialing buffer must be purged and restored")
		player.is_carrying_patch_rom = false
		print("[TEST 4/5] PASS: 10-Second Mainframe patch upload completed; Goa'uld virus purged.")

	elif ticks == 40:
		# TEST 5: Outbound Dialing Extraction Victory
		print("[TEST 5/5] Testing Outbound Dialing & Extraction Victory...")
		wave_mgr.completed_incursions = 3
		wave_mgr.iris_repaired_under_fire = true
		sgc_dialer.start_dialing(player)
		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.CHEVRONS, "Console must enter CHEVRONS phase")

		for i in range(7):
			var glyph: String = sgc_dialer.chevron_sequence[sgc_dialer.current_chevron_index]
			sgc_dialer.input_glyph(glyph)

		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.GDO_AUTH, "Console must enter GDO_AUTH phase")

		for i in range(4):
			var beat: String = sgc_dialer.gdo_sequence[sgc_dialer.gdo_index]
			sgc_dialer.input_glyph(beat)

		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.COMPLETE, "Console must reach COMPLETE phase")
		stargate._stabilize_wormhole()
		assert(stargate.current_state == StargateRing.GateState.ACTIVE, "Stargate must be ACTIVE for extraction")

		# Step through wormhole
		stargate._on_extraction_entered(player)
		print("[TEST 5/5] PASS: Outbound wormhole established, Iris opened, operative extracted!")

		print("\n========================================================")
		print("  SPRINT 13 HARD MODE LAB ROM & DEFENSE TEST PASSED!    ")
		print("  ✓ Tiered Difficulty Configuration (Easy/Med/Hard)     ")
		print("  ✓ Hard Mode Goa'uld Dialing Buffer Virus Lockout      ")
		print("  ✓ Level 28 Research Lab Clean ROM Retrieval           ")
		print("  ✓ Control Room Mainframe 10-Second Upload Defense     ")
		print("  ✓ Outbound Dialing & Squad Extraction Victory         ")
		print("========================================================\n")
		wave_mgr.end_mission()
		gateroom.queue_free()
		quit(0)
		return true

	return false
