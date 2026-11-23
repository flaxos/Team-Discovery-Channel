extends "res://tests/test_four_player_join_multiplayer.gd"
## A remote Recon deploys before a replacement joins across travel and retry.

const RECON := 2
const DEPLOY_AT := Vector3(0.0, 0.05, 4.5)
const SHIELD_AT := Vector3(-1.15, 0.05, 4.4)
const CLAYMORE_AT := Vector3(0.04, 0.05, 3.95)
const SATCHEL_AT := Vector3(0.10, 0.12, 4.85)
const SMOKE_AT := Vector3(4.3, 0.12, 0.8)
const SPENT := [1, 1, 1, 0]
const FULL := [2, 2, 2, 1]


func run() -> void:
	if OS.get_cmdline_user_args().has("--capture-field-kit"):
		OS.set_environment("TDC_FIELD_KIT_CAPTURE", "1")
	if DisplayServer.get_name() != "headless":
		root.set_flag(Window.FLAG_NO_FOCUS, true)
	await super.run()


func port() -> int:
	# Graphical verification can run alongside the headless profile.
	var base_port := 19963 if OS.has_environment("TDC_FIELD_KIT_CAPTURE") else 19961
	return base_port + int(is_dedicated)


func client_script() -> String:
	return "res://tests/test_field_kit_join_multiplayer.gd"


func child_display_args(index: int) -> PackedStringArray:
	if index == replacement_slot() and OS.get_cmdline_user_args().has("--capture-field-kit"):
		return PackedStringArray(["--resolution", "1280x800", "--position", "40,45", "--audio-driver", "Dummy", "--verbose"])
	return super.child_display_args(index)


func replacement_slot() -> int:
	return 5 if is_dedicated else 4


func room() -> GateRoom:
	return main.current_gate_room as GateRoom


func deployments(world: GateRoom) -> Node3D:
	return world.get_node("FieldKitDeployments") as Node3D


func inventory(actor: PlayerController3D) -> Array:
	return [actor.claymore_charges, actor.c4_charges_remaining, actor.smoke_grenades_count, actor.deployable_shields_count]


func _kit() -> Dictionary:
	var props := {}
	for child: Node3D in deployments(room()).get_children():
		if child is ClaymoreMine:
			props["claymore"] = child
		elif child is C4Satchel:
			props["satchel"] = child
		elif child is SmokeGrenade:
			props["smoke"] = child
		elif child is DeployableShield:
			props["shield"] = child
	return props


func snapshot(label: String, active_slots: Array[int], expected_count: int = 4) -> void:
	if label == "rejoined":
		await super.travel(ids[RECON - 1])
		var actor := (main.current_site as GateRoom).players_container.get_node(str(ids[RECON - 1])) as PlayerController3D
		require(inventory(actor) == SPENT, "Server carries all four stocks through the gate")
		require(_matches_kit(), "Server retains all four deployments in the original world")
		require(deployments(main.current_site as GateRoom).get_child_count() == 0, "Deployments stay behind")
	elif label == "second_retry":
		require(_cleared(), "Retry clears the old field kit in both worlds")
	await super.snapshot(label, active_slots, expected_count)
	if label == "retry":
		await _prepare_host()
	elif label in ["rejoined", "second_retry"]:
		for index in active_slots:
			require(await marked("kit_%s_%d" % [label, index]))
		print("FIELD_KIT_JOIN: %s confirmed by server and %d clients" % [label, active_slots.size()])


func _prepare_host() -> void:
	require(await marked("kit_positioned"))
	var actor := room().players_container.get_node(str(ids[RECON - 1])) as PlayerController3D
	var deadline := Time.get_ticks_msec() + 15000
	while actor.global_position.distance_to(DEPLOY_AT) > 0.01 and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(actor.global_position.distance_to(DEPLOY_AT) < 0.01, "Host sees remote deployer's pose")
	mark("kit_deploy")
	deadline = Time.get_ticks_msec() + 15000
	while _kit().size() < 4 and Time.get_ticks_msec() < deadline:
		await frames(1)
	var kit := _kit()
	if kit.size() != 4:
		require(false, "Host receives all four remote placement requests")
		return
	require(inventory(actor) == SPENT, "Exactly one use of each item consumed")
	var shield := kit.shield as DeployableShield
	var claymore := kit.claymore as ClaymoreMine
	require(shield.position.distance_to(DEPLOY_AT + Vector3(0, 0, -1.3)) < 0.03, "Original shield placement")
	require(claymore.position.distance_to(DEPLOY_AT + Vector3(0, 0.05, -1.2)) < 0.03, "Original claymore placement")
	shield.health_component.take_damage(125.0)
	var satchel := kit.satchel as C4Satchel
	var smoke := kit.smoke as SmokeGrenade
	# Give the fixed-step visual observation a reproducible layout and enough cloud time.
	shield.position = SHIELD_AT
	claymore.position = CLAYMORE_AT
	satchel.freeze = true
	satchel.position = SATCHEL_AT
	smoke.freeze = true
	smoke.position = SMOKE_AT
	smoke.cloud_duration_s = 90.0
	require(await marked("kit_stock_seen"))
	deadline = Time.get_ticks_msec() + 15000
	while not _matches_kit() and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(_matches_kit(), "Server has armed props, active smoke and damaged shield")


func _matches_kit() -> bool:
	var kit := _kit()
	if kit.size() != 4 or deployments(room()).get_child_count() != 4:
		return false
	var shield := kit.shield as DeployableShield
	var claymore := kit.claymore as ClaymoreMine
	var satchel := kit.satchel as C4Satchel
	var smoke := kit.smoke as SmokeGrenade
	return shield.position.distance_to(SHIELD_AT) < 0.02 and shield.health_component.current_health == 475.0 \
		and shield.is_in_group("cover") and shield.has_node("Visuals/ShieldMesh") \
		and claymore.position.distance_to(CLAYMORE_AT) < 0.02 and claymore.is_armed \
		and (claymore.get_node("BodyMesh/ArmedLens") as MeshInstance3D).visible \
		and satchel.position.distance_to(SATCHEL_AT) < 0.02 and satchel.is_armed \
		and satchel.led_light.visible and satchel.mode == C4Satchel.C4Mode.REMOTE \
		and smoke.position.distance_to(SMOKE_AT) < 0.02 and smoke.is_detonated \
		and smoke.cloud_remaining > 0.0 and smoke.cloud_area.is_in_group("smoke_cloud") \
		and not (smoke.get_node("CanisterMesh") as MeshInstance3D).visible


func _cleared() -> bool:
	return deployments(room()).get_child_count() == 0 \
		and deployments(main.current_site as GateRoom).get_child_count() == 0


func see_snapshot(label: String) -> void:
	await super.see_snapshot(label)
	if label == "retry" and slot == RECON:
		await _deploy_remote()
	if label not in ["rejoined", "second_retry"]:
		return
	var deadline := Time.get_ticks_msec() + 15000
	if label == "rejoined":
		while not _matches_kit() and Time.get_ticks_msec() < deadline:
			await frames(1)
		if not _matches_kit():
			for prop: Node3D in deployments(room()).get_children():
				print("FIELD_KIT_JOIN: %s at %s" % [prop.name, prop.position])
			require(false, "Peer receives four field-kit replicas and current state")
			return
		if slot == RECON:
			var actor := (main.current_site as GateRoom).players_container.get_node(str(net.local_peer_id)) as PlayerController3D
			while inventory(actor) != SPENT and Time.get_ticks_msec() < deadline:
				await frames(1)
			require(inventory(actor) == SPENT, "Remote Recon sees spent stock after travel")
	else:
		var actor := room().players_container.get_node(str(net.local_peer_id)) as PlayerController3D
		require(_cleared() and inventory(actor) == FULL, "Peer sees clear worlds and restocked kit after retry")
	if slot == replacement_slot() and DisplayServer.get_name() != "headless":
		await _capture(label)
	mark("kit_%s_%d" % [label, slot])
	print("FIELD_KIT_JOIN: %s confirmed by operative %d" % [label, slot])


func _deploy_remote() -> void:
	var actor := room().players_container.get_node(str(net.local_peer_id)) as PlayerController3D
	actor.global_position = DEPLOY_AT
	actor.rotation.y = 0.0
	mark("kit_positioned")
	require(await marked("kit_deploy"))
	actor._plant_claymore()
	actor._deploy_tactical_gadget()
	actor.throw_smoke_grenade()
	actor.deploy_shield()
	actor.deploy_shield() # No extra cover appears with an empty slot.
	var deadline := Time.get_ticks_msec() + 15000
	while inventory(actor) != SPENT and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(inventory(actor) == SPENT, "Remote inventory reflects server-confirmed uses")
	mark("kit_stock_seen")


func _capture(label: String) -> void:
	if room().hud != null:
		room().hud.hide()
	var camera := Camera3D.new()
	camera.fov = 46.0
	room().add_child(camera)
	camera.global_position = Vector3(0.34, 1.90, 7.55)
	camera.look_at(Vector3(-0.12, 0.34, 3.65))
	camera.make_current()
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	room().add_child(overlay)
	var caption := Label.new()
	caption.position = Vector2(30, 22)
	caption.add_theme_font_size_override("font_size", 23)
	caption.add_theme_constant_override("outline_size", 8)
	var result := "Late join during gate travel  ·  4 replicated deployments" if label == "rejoined" else "After retry  ·  0 deployments in either world"
	caption.text = "%s server  /  4 operatives\n%s" % ["Dedicated" if is_dedicated else "Listen", result]
	overlay.add_child(caption)
	await frames(5)
	while main.session._settling:
		await frames(1)
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK)
