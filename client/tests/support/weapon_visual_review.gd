extends SceneTree
## Review captures of a weapon visual held by a real operative in a hosted mission (AP-1d).
## Needs a display (Forward+), not --headless:
##
##   DISPLAY=:0 godot --path client --script res://tests/support/weapon_visual_review.gd -- --mission sgc_uat --weapon m9
##   DISPLAY=:0 godot --path client --script res://tests/support/weapon_visual_review.gd -- --mission goauld_infiltration --weapon m9
##
## Writes build/asset-review/<weapon>/<mission>-*.png: the game camera, aiming down sights, a
## close view with the D-015 matte finish the game uses, and the same view with metallic 1 to
## show the source metallic map. Evidence for owner art review, not acceptance.


func _init() -> void:
	call_deferred("run")


func option(name: String, fallback: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(name)
	return arguments[index + 1] if index >= 0 and index + 1 < arguments.size() else fallback


func capture(path: String, frames: int = 20) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var mission := option("--mission", SGCNetworkManager.MISSION_SGC_UAT)
	var weapon_id := option("--weapon", "m9")
	net.selected_mission_id = mission
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await process_frame
	if net.host_game(0) != OK:
		quit(1)
		return
	net.request_start_game()
	var player: PlayerController3D = null
	for i in range(1800):
		await process_frame
		for world in main.worlds():
			var players := world.get_node_or_null("Players")
			if players != null and players.has_node("1"):
				player = players.get_node("1") as PlayerController3D
		if player != null and player.camera != null:
			break
	if player == null:
		push_error("No operative spawned in " + mission)
		quit(1)
		return
	root.size = Vector2i(1440, 900)
	await create_timer(3.0).timeout
	player.active_slot = 2 if weapon_id in ["m9", "zat"] else 1
	player._equip_weapon_by_id(weapon_id)
	var output := ProjectSettings.globalize_path("res://../build/asset-review").path_join(weapon_id)
	DirAccess.make_dir_recursive_absolute(output)
	var prefix := output.path_join(mission)
	await capture(prefix + "-game-camera.png")
	Input.action_press("aim")
	await capture(prefix + "-aim.png", 40)
	Input.action_release("aim")
	await capture(prefix + "-after-aim.png", 20)
	# Weapons face -Z; frame the held gun from its front right.
	var gun := player.current_weapon
	var close := Camera3D.new()
	close.fov = 40.0
	gun.add_child(close)
	close.position = Vector3(0.36, 0.08, -0.30)
	close.look_at(gun.to_global(Vector3(0.0, -0.03, -0.07)))
	close.current = true
	await capture(prefix + "-close.png")
	for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var material := mi.get_surface_override_material(s) as StandardMaterial3D
			if material != null:
				# Shared by every copy of this weapon; this helper quits right after.
				material.metallic = 1.0
	await capture(prefix + "-close-source-metallic.png")
	print("Weapon review frames: ", output, " weapon=", gun.weapon_id, " imported=",
		gun.has_node("WeaponModel/ImportedGLB"))
	main.queue_free()
	await process_frame
	await preload("res://tests/support/finish.gd").success(self)
