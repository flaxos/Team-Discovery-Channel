extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	room.wave_manager.set_physics_process(false)
	var hud := room.get_node("TacticalHUD") as TacticalHUD
	var dialer := room.find_child("SGCDialingConsole", true, false) as SGCDialingConsole
	hud.bind_dhd(dialer)
	var pawn := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	pawn.name = "1"
	room.get_node("Players").add_child(pawn)
	pawn.set_physics_process(false)
	pawn.position = dialer.global_position
	dialer.set_buffer_corrupted(true)
	dialer.start_dialing(pawn)
	assert(
		not hud.dhd_panel.visible and dialer.active_dialer == null,
		"Denied dialing must leave the full-screen panel closed"
	)
	assert(
		"ROM" in hud.objective_label.text and not pawn._is_ui_modal_open(),
		"Lockout must be a readable objective without locking gameplay"
	)
	pawn.is_carrying_patch_rom = true
	dialer.start_patch_upload(pawn)
	dialer.update_upload(2.5)
	assert(
		not hud.dhd_panel.visible and "25%" in hud.objective_label.text,
		"Patch progress must not force open the dialing panel"
	)
	dialer.cancel_patch_upload()
	assert(not hud.dhd_panel.visible, "Cancelled upload must leave no orphan panel")
	# Snapshot/remote progress messages must not reopen the panel either.
	dialer.sync_upload(NodePath(), false, 0.0, true)
	assert(not hud.dhd_panel.visible)
	dialer.set_buffer_corrupted(false)
	room.wave_manager.completed_incursions = 3
	room.wave_manager.computer_upgraded = true
	dialer.start_dialing(pawn)
	assert(
		dialer.active_dialer == pawn and hud.dhd_panel.visible,
		"A real approved dialing session must still open its panel"
	)
	dialer.cancel_dialing()
	assert(not hud.dhd_panel.visible, "Cancelling an approved session must dismiss its panel")
	print(
		"PASS lockout notification, upload/cancel/snapshot without orphan panels and normal dialing dismissal"
	)
	await preload("res://tests/support/finish.gd").success(self)
