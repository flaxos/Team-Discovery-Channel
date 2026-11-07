class_name PlayerController3D
extends CharacterBody3D
## Tactical SGC Operative Controller (Twin-stick Isometric / Top-Down 3D).
## Handles WASD movement, mouse-plane aiming, weapon discharging,
## HealthComponent integration, and Godot 4 multiplayer synchronization.

signal player_died(peer_id: int)
signal weapon_ammo_changed(current: int, reserve: int)
signal class_configured(class_id: String)

@export var class_id: String = "sg3_heavy":
	set(val):
		if class_id == val and current_weapon != null:
			return
		class_id = val
		if is_inside_tree() and weapon_holder != null:
			_apply_class_profile(val)
@export var base_speed: float = 6.0
@export var sprint_multiplier: float = 1.35
@export var crouch_multiplier: float = 0.55
@export var acceleration: float = 30.0
@export var friction: float = 25.0

var peer_id: int = 1
var is_local_authority: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var is_firing: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var current_weapon: WeaponBase = null
var current_aim_target: Vector3 = Vector3.ZERO
var primary_weapon_id: String = "m249"
var secondary_weapon_id: String = "m9"
var active_slot: int = 1
var active_c4: C4Satchel = null

@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer if has_node("MultiplayerSynchronizer") else null
@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var weapon_holder: Node3D = $WeaponHolder if has_node("WeaponHolder") else null
@onready var camera_rig: Node3D = $CameraRig if has_node("CameraRig") else null
@onready var camera: Camera3D = $CameraRig/Camera3D if has_node("CameraRig/Camera3D") else null
@onready var laser_sight: Node3D = $WeaponHolder/LaserSight if has_node("WeaponHolder/LaserSight") else null
@onready var body_mesh: Node3D = $Visuals/BodyMesh if has_node("Visuals/BodyMesh") else null


func _enter_tree() -> void:
	# Parse peer ID from node name (Godot Multiplayer convention: node name is string of peer_id)
	if name.is_valid_int():
		peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	is_local_authority = (multiplayer.get_unique_id() == peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)


func _ready() -> void:
	_setup_replication()
	_apply_class_profile(class_id)

	if health_component != null:
		health_component.died.connect(_on_died)
		health_component.stunned.connect(_on_stunned)
		health_component.recovered_from_stun.connect(_on_recovered_from_stun)
		health_component.vaporized.connect(_on_vaporized)

	# Configure Camera and input authority
	if is_local_authority:
		if camera_rig != null:
			camera_rig.top_level = true
			camera_rig.global_position = global_position
			camera_rig.rotation = Vector3.ZERO
		if camera != null:
			camera.current = true
		if laser_sight != null:
			laser_sight.visible = true
	else:
		if camera != null:
			camera.current = false


func _setup_replication() -> void:
	if synchronizer == null and has_node("MultiplayerSynchronizer"):
		synchronizer = $MultiplayerSynchronizer
	if synchronizer != null:
		synchronizer.set_multiplayer_authority(peer_id)


func _apply_class_profile(target_class_id: String) -> void:
	if class_id != target_class_id:
		class_id = target_class_id
	var profile: Dictionary = SGCNetworkManager.CLASS_PROFILES.get(target_class_id, SGCNetworkManager.CLASS_PROFILES[SGCNetworkManager.CLASS_SG3_HEAVY])
	base_speed = profile.get("speed", 6.0)

	if health_component != null:
		health_component.max_health = profile.get("health", 120.0)
		health_component.current_health = health_component.max_health

	primary_weapon_id = profile.get("primary", "m249")
	secondary_weapon_id = profile.get("secondary", "m9")
	active_slot = 1
	_equip_weapon_by_id(primary_weapon_id)
	class_configured.emit(class_id)


func switch_slot(slot: int) -> void:
	if active_slot == slot:
		return
	active_slot = slot
	var target_id := primary_weapon_id if active_slot == 1 else secondary_weapon_id
	_equip_weapon_by_id(target_id)
	print("Player %d switched to slot %d: %s" % [peer_id, active_slot, current_weapon.display_name])


func _equip_weapon_by_id(weapon_id: String) -> void:
	if weapon_holder == null:
		return

	# Clear existing weapons in holder
	for child in weapon_holder.get_children():
		if child is WeaponBase:
			child.queue_free()

	var new_weapon: WeaponBase = null
	match weapon_id:
		"p90":
			new_weapon = WeaponP90.new()
		"m249":
			new_weapon = WeaponM249.new()
		"mp5":
			new_weapon = WeaponMP5.new()
		"staff_weapon":
			new_weapon = WeaponStaff.new()
		"zat":
			new_weapon = WeaponZat.new()
		"m9":
			new_weapon = WeaponM9.new()
		_:
			new_weapon = WeaponP90.new()

	weapon_holder.add_child(new_weapon)
	current_weapon = new_weapon
	current_weapon.position = Vector3(0.3, 0.9, -0.4)

	# Connect weapon signals
	current_weapon.ammo_changed.connect(func(cur: int, res: int) -> void:
		weapon_ammo_changed.emit(cur, res)
	)
	current_weapon.fired.connect(_on_weapon_fired)


func _physics_process(delta: float) -> void:
	# Non-authorities rely on MultiplayerSynchronizer replication for position/rotation
	if not is_local_authority:
		move_and_slide()
		return

	# Handle dead or stunned state
	if health_component != null and (health_component.is_dead or health_component.is_stunned):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Aiming towards mouse intersection on horizontal plane
	_process_aim()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# If actively dialing DHD console, route directional inputs to glyph entries
	var dhd := get_tree().root.find_child("DHDConsole", true, false) as DHDDialer
	if dhd != null and dhd.active_dialer == self:
		if Input.is_action_just_pressed("move_up"):
			dhd.input_glyph("UP")
		elif Input.is_action_just_pressed("move_down"):
			dhd.input_glyph("DOWN")
		elif Input.is_action_just_pressed("move_left"):
			dhd.input_glyph("LEFT")
		elif Input.is_action_just_pressed("move_right"):
			dhd.input_glyph("RIGHT")

		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		return

	# Stances (Sprint / Crouch)
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching

	var speed := base_speed
	if is_crouching:
		speed *= crouch_multiplier
	elif is_sprinting:
		speed *= sprint_multiplier

	# Movement vector from input actions
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(raw_input.x, 0.0, raw_input.y).normalized()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	# Smoothly follow player with camera rig without rotating with character
	if is_local_authority and camera_rig != null:
		camera_rig.global_position = camera_rig.global_position.lerp(global_position, 14.0 * delta)
		camera_rig.rotation = Vector3.ZERO

	# Handle firing & reloading
	_process_combat()


func _process_aim() -> void:
	if camera == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	var hit_variant: Variant = ground_plane.intersects_ray(ray_origin, ray_normal)
	if hit_variant != null:
		var hit: Vector3 = hit_variant
		current_aim_target = hit
		var look_dir: Vector3 = (hit - global_position)
		look_dir.y = 0.0
		# Deadzone: only rotate if mouse is at least 0.5m away from player center
		if look_dir.length_squared() > 0.25:
			rotation.y = atan2(-look_dir.x, -look_dir.z)


func _process_combat() -> void:
	if current_weapon == null:
		return

	if Input.is_key_pressed(KEY_1):
		switch_slot(1)
	elif Input.is_key_pressed(KEY_2):
		switch_slot(2)

	if Input.is_action_just_pressed("gadget"):
		_deploy_tactical_gadget()

	if Input.is_action_just_pressed("reload"):
		current_weapon.reload()

	is_firing = Input.is_action_pressed("fire")
	if is_firing:
		var spread_mult: float = 1.0
		if is_crouching:
			spread_mult = 0.5  # Crouching / bipod stabilization
		elif velocity.length() > 2.0:
			spread_mult = 1.8  # Running penalty

		current_weapon.try_fire(spread_mult)


func _deploy_tactical_gadget() -> void:
	if class_id == SGCNetworkManager.CLASS_SG3_HEAVY:
		var turret_scene := load("res://scenes/props/DeployableTurret.tscn") as PackedScene
		if turret_scene != null:
			var turret := turret_scene.instantiate() as DeployableTurret
			turret.position = global_position - global_transform.basis.z * 1.6
			get_parent().add_child(turret)
			print("Player %d deployed .50 Cal Tripod Turret!" % peer_id)
	elif class_id == SGCNetworkManager.CLASS_ONEILL_RECON:
		if active_c4 != null and is_instance_valid(active_c4) and active_c4.is_armed:
			active_c4.detonate()
			active_c4 = null
			print("Player %d detonated C4 Satchel!" % peer_id)
		else:
			var c4_scene := load("res://scenes/props/C4Satchel.tscn") as PackedScene
			if c4_scene != null:
				var c4 := c4_scene.instantiate() as C4Satchel
				c4.position = global_position + Vector3(0, 1.0, 0)
				c4.planter = self
				get_parent().add_child(c4)
				c4.apply_central_impulse(-global_transform.basis.z * 10.0 + Vector3.UP * 3.0)
				active_c4 = c4
				print("Player %d threw C4 Satchel Charge!" % peer_id)


func _on_weapon_fired(origin: Vector3, dir: Vector3, hit_point: Vector3, hit_node: Node) -> void:
	var is_zat := (current_weapon != null and current_weapon.is_zat)
	var is_pl := (current_weapon != null and current_weapon.is_plasma)
	rpc("play_shot_fx", origin, hit_point, is_pl, is_zat)


@rpc("call_local", "unreliable")
func play_shot_fx(from: Vector3, to: Vector3, is_plasma: bool, is_zat: bool = false) -> void:
	# Render lightweight tracer beam
	var tracer := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	tracer.mesh = imm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_zat:
		mat.albedo_color = Color(0.2, 0.7, 1.0, 1.0)  # Zat'nik'tel electric blue arc
	elif is_plasma:
		mat.albedo_color = Color(1.0, 0.5, 0.0, 1.0)  # Goa'uld golden plasma
	else:
		mat.albedo_color = Color(1.0, 0.9, 0.4, 0.8)  # Bullet tracer

	tracer.material_override = mat
	get_tree().root.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)
	imm.surface_end()

	# Fade out and clean up after 0.08s
	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(tracer.queue_free)


func _on_died() -> void:
	player_died.emit(peer_id)
	print("Player %d has fallen in combat." % peer_id)


func _on_stunned(duration: float) -> void:
	print("Player %d stunned by Zat'nik'tel for %.1f seconds." % [peer_id, duration])


func _on_recovered_from_stun() -> void:
	print("Player %d recovered from stun." % peer_id)


func _on_vaporized() -> void:
	print("Player %d disintegrated by Zat'nik'tel!" % peer_id)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.2, 0.6, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	get_tree().root.add_child(flash)
	flash.global_position = global_position + Vector3(0, 0.5, 0)

	var tween := create_tween()
	if body_mesh != null:
		tween.tween_property(body_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tween.tween_callback(queue_free)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.25)
	flash_tween.tween_callback(flash.queue_free)


func _try_interact() -> void:
	var dhd := get_tree().root.find_child("DHDConsole", true, false) as DHDDialer
	if dhd != null and global_position.distance_to(dhd.global_position) <= 3.2:
		if dhd.current_phase == DHDDialer.DialPhase.INACTIVE:
			dhd.start_dialing(self)
		else:
			dhd.cancel_dialing()
