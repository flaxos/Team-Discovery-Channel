class_name PlayerController3D
extends CharacterBody3D
## Tactical SGC Operative Controller (Twin-stick Isometric / Top-Down 3D).
## Handles WASD movement, mouse-plane aiming, weapon discharging,
## HealthComponent integration, and Godot 4 multiplayer synchronization.

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const LabDataPatchDriveScript = preload("res://scripts/props/LabDataPatchDrive.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")

signal player_died(peer_id: int)
signal player_downed(peer_id: int)
signal player_revived(peer_id: int)
signal revive_progress_changed(progress: float)
signal weapon_ammo_changed(current: int, reserve: int)
signal class_configured(class_id: String)

@export var class_id: String = "sg3_heavy":
	set(val):
		if class_id == val and current_weapon != null:
			return
		class_id = val
		if is_inside_tree() and weapon_holder != null:
			_apply_class_profile(val)
@export var player_callsign: String = "OPERATIVE"
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
var c4_charges_remaining: int = 2
const MAX_C4_CHARGES: int = 2
var claymore_charges: int = 2
const MAX_CLAYMORE_CHARGES: int = 2
var active_turret: DeployableTurret = null
var mounted_turret: DeployableTurret = null
var turret_cooldown: float = 0.0
const TURRET_COOLDOWN_S: float = 30.0
var active_revive_target: CharacterBody3D = null
var current_revive_time: float = 0.0
const REVIVE_DURATION_S: float = 2.5

var trauma: float = 0.0
var max_shake_offset: float = 0.65
var max_shake_yaw_deg: float = 1.5
var max_aim_lead_dist: float = 2.8
var occluded_nodes: Dictionary = {}
var is_in_cctv_mode: bool = false
var is_aiming_down_sights: bool = false
var ads_blend: float = 0.0
var current_iso_cam_y: float = 12.0
var current_iso_pan_yaw: float = 0.0
var is_carrying_patch_rom: bool = false
var auto_cover_enabled: bool = true
var is_in_cover: bool = false
var is_peeking: bool = false
var cover_detection_distance: float = 1.35
var is_dragging_body: bool = false
var dragged_body: CharacterBody3D = null
const DRAG_SPEED: float = 3.2

@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer if has_node("MultiplayerSynchronizer") else null
@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var weapon_holder: Node3D = $WeaponHolder if has_node("WeaponHolder") else null
@onready var camera_rig: Node3D = $CameraRig if has_node("CameraRig") else null
@onready var camera: Camera3D = $CameraRig/Camera3D if has_node("CameraRig/Camera3D") else null
@onready var laser_sight: Node3D = $WeaponHolder/LaserSight if has_node("WeaponHolder/LaserSight") else null
@onready var body_mesh: Node3D = $Visuals/BodyMesh if has_node("Visuals/BodyMesh") else null
@onready var visor_mesh: MeshInstance3D = $Visuals/VisorMesh if has_node("Visuals/VisorMesh") else null
@onready var class_gear: Node3D = $Visuals/ClassGear if has_node("Visuals/ClassGear") else null
@onready var nameplate: Node3D = $Nameplate3D if has_node("Nameplate3D") else null


func _enter_tree() -> void:
	# Parse peer ID from node name (Godot Multiplayer convention: node name is string of peer_id)
	if name.is_valid_int():
		peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	is_local_authority = (multiplayer.get_unique_id() == peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)


func _exit_tree() -> void:
	_restore_all_occluded_nodes()


func _ready() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and net.peers.has(peer_id):
		player_callsign = net.peers[peer_id].get("name", "OPERATIVE")
	elif net != null and peer_id == 1:
		player_callsign = net.player_name

	_setup_replication()
	_apply_class_profile(class_id)

	if nameplate != null:
		nameplate.setup(self, is_local_authority)

	if health_component != null:
		health_component.can_be_downed = true
		health_component.died.connect(_on_died)
		health_component.downed.connect(_on_downed)
		health_component.revived.connect(_on_revived)
		health_component.stunned.connect(_on_stunned)
		health_component.recovered_from_stun.connect(_on_recovered_from_stun)
		health_component.vaporized.connect(_on_vaporized)
		health_component.damage_taken.connect(_on_damage_taken)

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


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_authority or is_in_cctv_mode:
		return
	if is_aiming_down_sights and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotation.y -= motion.relative.x * 0.003
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_G:
			_toggle_drag_body()
		elif key_event.keycode == KEY_C:
			auto_cover_enabled = not auto_cover_enabled
			print("Player %d auto-cover toggled: %s" % [peer_id, auto_cover_enabled])


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
	_apply_class_visuals(target_class_id)
	class_configured.emit(class_id)


func _apply_class_visuals(target_class_id: String) -> void:
	if body_mesh == null or not is_inside_tree():
		return

	if class_gear != null:
		for child in class_gear.get_children():
			child.queue_free()

	var body_inst := body_mesh as MeshInstance3D
	var body_mat := StandardMaterial3D.new()

	match target_class_id:
		SGCNetworkManager.CLASS_SG3_HEAVY:
			body_mat.albedo_color = Color(0.20, 0.28, 0.16)
			body_mat.roughness = 0.8
			body_mesh.scale = Vector3(1.15, 1.0, 1.15)
			if visor_mesh != null:
				var vm := StandardMaterial3D.new()
				vm.albedo_color = Color(0.08, 0.08, 0.08)
				visor_mesh.material_override = vm

			if class_gear != null:
				var backpack := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.42, 0.55, 0.26)
				backpack.mesh = bm
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.18, 0.24, 0.15)
				backpack.material_override = bmat
				backpack.position = Vector3(0, 1.0, 0.32)
				class_gear.add_child(backpack)

		SGCNetworkManager.CLASS_CARTER_TECH:
			body_mat.albedo_color = Color(0.16, 0.21, 0.33)
			body_mat.roughness = 0.65
			body_mesh.scale = Vector3(0.96, 0.98, 0.96)
			if visor_mesh != null:
				var vm := StandardMaterial3D.new()
				vm.albedo_color = Color(0.15, 0.85, 1.0)
				vm.emission_enabled = true
				vm.emission = Color(0.15, 0.85, 1.0)
				vm.emission_energy_multiplier = 0.8
				visor_mesh.material_override = vm

			if class_gear != null:
				var scanner := MeshInstance3D.new()
				var sm := BoxMesh.new()
				sm.size = Vector3(0.32, 0.38, 0.18)
				scanner.mesh = sm
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.22, 0.24, 0.28)
				scanner.material_override = smat
				scanner.position = Vector3(0, 1.0, 0.28)
				class_gear.add_child(scanner)

				var antenna := MeshInstance3D.new()
				var am := CylinderMesh.new()
				am.top_radius = 0.015
				am.bottom_radius = 0.015
				am.height = 0.6
				antenna.mesh = am
				var amat := StandardMaterial3D.new()
				amat.albedo_color = Color(0.8, 0.8, 0.8)
				amat.metallic = 0.9
				antenna.material_override = amat
				antenna.position = Vector3(0.12, 1.35, 0.28)
				class_gear.add_child(antenna)

		SGCNetworkManager.CLASS_ONEILL_RECON:
			body_mat.albedo_color = Color(0.50, 0.43, 0.32)
			body_mat.roughness = 0.75
			body_mesh.scale = Vector3(0.96, 1.0, 0.96)
			if visor_mesh != null:
				var vm := StandardMaterial3D.new()
				vm.albedo_color = Color(0.1, 0.9, 0.25)
				vm.emission_enabled = true
				vm.emission = Color(0.1, 0.9, 0.25)
				vm.emission_energy_multiplier = 0.9
				visor_mesh.material_override = vm

			if class_gear != null:
				var pouch := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.15, 0.20, 0.12)
				pouch.mesh = pm
				var pmat := StandardMaterial3D.new()
				pmat.albedo_color = Color(0.35, 0.30, 0.22)
				pouch.material_override = pmat
				pouch.position = Vector3(0.35, 0.7, 0.0)
				class_gear.add_child(pouch)

		SGCNetworkManager.CLASS_TEALC_JAFFA:
			body_mat.albedo_color = Color(0.68, 0.50, 0.20)
			body_mat.metallic = 0.85
			body_mat.roughness = 0.28
			body_mesh.scale = Vector3(1.06, 1.10, 1.06)
			if visor_mesh != null:
				var vm := StandardMaterial3D.new()
				vm.albedo_color = Color(0.9, 0.15, 0.15)
				vm.emission_enabled = true
				vm.emission = Color(0.9, 0.15, 0.15)
				visor_mesh.material_override = vm

			if class_gear != null:
				var crest := MeshInstance3D.new()
				var cm := BoxMesh.new()
				cm.size = Vector3(0.16, 0.16, 0.08)
				crest.mesh = cm
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(1.0, 0.84, 0.1)
				cmat.metallic = 0.95
				cmat.roughness = 0.15
				crest.material_override = cmat
				crest.position = Vector3(0, 1.62, -0.28)
				class_gear.add_child(crest)

	if body_inst != null:
		body_inst.material_override = body_mat

	if nameplate != null:
		var profile: Dictionary = SGCNetworkManager.CLASS_PROFILES.get(target_class_id, {})
		nameplate.set_callsign(player_callsign, profile.get("name", "OPERATIVE").to_upper())


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

	# Handle dead state
	if health_component != null and health_component.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Handle downed / bleedout state
	if health_component != null and health_component.is_downed:
		is_aiming_down_sights = false
		if is_local_authority and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if mounted_turret != null:
			mounted_turret.dismount()
			mounted_turret = null
		_process_aim()
		_process_downed_crawl(delta)
		_update_camera_and_occlusion(delta)
		return

	# Handle stunned state
	if health_component != null and health_component.is_stunned:
		is_aiming_down_sights = false
		if is_local_authority and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Check Right-Click Aim Down Sights (ADS)
	var wants_ads: bool = Input.is_action_pressed("aim") and not is_in_cctv_mode
	is_aiming_down_sights = wants_ads

	if is_local_authority:
		if Input.is_action_just_pressed("aim") and wants_ads:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif Input.is_action_just_released("aim") or not wants_ads:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Aiming towards mouse intersection on horizontal plane
	_process_aim()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# Process reviving nearby downed teammates while holding interact
	_process_revive(delta)

	# Process Iris servo repair channeling
	var iris_servo := get_tree().root.find_child("IrisServoHousing", true, false) as IrisServoHousingScript
	if iris_servo != null and iris_servo.is_repairing and iris_servo.repairer_player == self:
		iris_servo.update_repair(delta)

	# Process SGC Dialing console patch upload channeling
	var sgc_console := get_tree().root.find_child("SGCDialingConsole", true, false) as SGCDialingConsoleScript
	if sgc_console != null and sgc_console.is_uploading_patch and sgc_console.uploader_player == self:
		if sgc_console.update_upload(delta):
			is_carrying_patch_rom = false

	# If mounted on .50 cal tripod, lock position behind gun and process manual fire
	if mounted_turret != null and is_instance_valid(mounted_turret):
		velocity = Vector3.ZERO
		global_position = mounted_turret.global_position + mounted_turret.global_transform.basis.z * 0.75
		if Input.is_action_pressed("fire"):
			var aim_dir := (current_aim_target - mounted_turret.turret_head.global_position).normalized()
			if aim_dir != Vector3.ZERO:
				mounted_turret.try_manual_fire(aim_dir)
				add_screen_shake(0.08)
		_update_camera_and_occlusion(delta)
		return

	# If actively dialing SGC console or DHD console, route directional inputs to glyph entries
	var dhd := get_tree().root.find_child("SGCDialingConsole", true, false) as DHDDialer
	if dhd == null:
		dhd = get_tree().root.find_child("DHDConsole", true, false) as DHDDialer
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
		_update_camera_and_occlusion(delta)
		return

	# Movement vector from input actions: Camera / Sightline relative
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3.ZERO
	if raw_input.length_squared() > 0.001:
		var cam_yaw: float = 0.0
		if is_aiming_down_sights or ads_blend > 0.2:
			# In ADS: move forward in player's facing direction, strafe left/right
			cam_yaw = rotation.y
		elif camera_rig != null:
			# In tactical isometric: move relative to camera rig yaw
			cam_yaw = camera_rig.rotation.y

		var cam_forward := -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
		var cam_right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
		move_dir = (cam_right * raw_input.x + cam_forward * (-raw_input.y)).normalized()

	# Stances (Cover / Sprint / Crouch / Peek-to-Shoot)
	_process_cover_and_peeking(delta, move_dir)

	var speed := base_speed
	if is_dragging_body:
		speed = DRAG_SPEED
	elif is_crouching:
		speed *= crouch_multiplier
	elif is_sprinting:
		speed *= sprint_multiplier

	# Body Dragging Physics follow
	if is_dragging_body:
		if is_instance_valid(dragged_body) and not health_component.is_dead and not health_component.is_downed:
			var pull_target := global_position - global_transform.basis.z * 1.1
			dragged_body.global_position = dragged_body.global_position.lerp(pull_target, 12.0 * delta)
			dragged_body.rotation.y = lerp_angle(dragged_body.rotation.y, rotation.y, 8.0 * delta)
		else:
			stop_dragging_body()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	# Void boundary containment safety recovery
	if global_position.y < -4.0:
		print("PlayerController3D: Operative %s recovered from void boundary (Y=%.2f)." % [name, global_position.y])
		global_position = Vector3(0.0, 0.5, 0.0)
		velocity = Vector3.ZERO

	if turret_cooldown > 0.0:
		turret_cooldown = maxf(0.0, turret_cooldown - delta)

	# Update tactical dynamic camera (aim-lead, screenshake, and occlusion transparency)
	_update_camera_and_occlusion(delta)

	# Handle firing & reloading
	_process_combat()


func _update_camera_and_occlusion(delta: float) -> void:
	if not is_local_authority or camera_rig == null:
		return

	if is_in_cctv_mode:
		return

	# Floor-Aware Culling: Show Level 27 complex only when operative is on upper floor (Y >= 4.5m)
	var l27_node: Node3D = null
	if get_tree() != null and get_tree().current_scene != null:
		l27_node = get_tree().current_scene.get_node_or_null("Level27Complex") as Node3D
	if l27_node == null and get_tree() != null and get_tree().root != null:
		l27_node = get_tree().root.find_child("Level27Complex", true, false) as Node3D
	if l27_node != null:
		l27_node.visible = (global_position.y >= 4.5)

	# Smooth ADS transition weight (0.0 = tactical isometric, 1.0 = over-the-shoulder semi-scoped)
	var target_ads := 1.0 if is_aiming_down_sights else 0.0
	ads_blend = move_toward(ads_blend, target_ads, 6.0 * delta)

	# 1. Aim-Lead: offset camera toward aiming reticle for tactical forward vision in isometric mode
	var aim_lead := Vector3.ZERO
	if current_aim_target != Vector3.ZERO:
		var aim_diff := (current_aim_target - global_position)
		aim_diff.y = 0.0
		aim_lead = aim_diff.limit_length(max_aim_lead_dist)

	# In isometric: cam rig tracks player + aim_lead; In ADS: cam rig tracks player center
	var iso_desired_pos := global_position + aim_lead
	var ads_desired_pos := global_position
	var desired_cam_pos := iso_desired_pos.lerp(ads_desired_pos, ads_blend)
	var target_cam_pos := camera_rig.global_position.lerp(desired_cam_pos, 10.0 * delta)

	# 2. Procedural trauma screen shake
	var off_yaw: float = 0.0
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - 1.8 * delta)
		var shake_p := trauma * trauma
		var off_x := (randf() * 2.0 - 1.0) * max_shake_offset * shake_p
		var off_z := (randf() * 2.0 - 1.0) * max_shake_offset * shake_p
		off_yaw = deg_to_rad((randf() * 2.0 - 1.0) * max_shake_yaw_deg * shake_p)
		target_cam_pos += Vector3(off_x, 0, off_z)

	camera_rig.global_position = target_cam_pos

	# Gentle Isometric Mouse-Pan Yaw: allow tactical peeking around corners
	var target_iso_pan_yaw: float = 0.0
	if is_inside_tree() and get_viewport() != null:
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 0.0:
			var mouse_x := get_viewport().get_mouse_position().x
			var mouse_ratio := clampf((mouse_x / vp_size.x) - 0.5, -0.5, 0.5) * 2.0
			# Subtle tactical pan up to +/- 22 degrees
			target_iso_pan_yaw = -mouse_ratio * deg_to_rad(22.0)

	current_iso_pan_yaw = lerp_angle(current_iso_pan_yaw, target_iso_pan_yaw, 2.5 * delta)

	# Rig Yaw: in isometric mode follows current_iso_pan_yaw; in ADS mode follows player yaw rotation.y
	var target_rig_yaw := lerp_angle(current_iso_pan_yaw, rotation.y, ads_blend)
	camera_rig.rotation.y = target_rig_yaw + off_yaw

	# Floor-Aware Camera Elevation: smoothly adjust isometric camera height between L28 (12m) and L27 (17.5m)
	var target_cam_y: float = 12.0
	if global_position.y >= 4.5:
		target_cam_y = 17.5
	current_iso_cam_y = move_toward(current_iso_cam_y, target_cam_y, 14.0 * delta)

	if camera != null:
		# Isometric position: (0, current_iso_cam_y, 7.0)
		# ADS over-shoulder position: (0.80, 2.15, 1.80) - Ghost Recon: Wildlands style
		var iso_cam_pos := Vector3(0.0, current_iso_cam_y, 7.0)
		var ads_cam_pos := Vector3(0.80, 2.15, 1.80)
		camera.position = iso_cam_pos.lerp(ads_cam_pos, ads_blend)

		# Pitch angle: -60° (tactical isometric) <-> -12° (over-the-shoulder semi-scoped)
		var iso_pitch := deg_to_rad(-60.0)
		var ads_pitch := deg_to_rad(-12.0)
		camera.rotation.x = lerp_angle(iso_pitch, ads_pitch, ads_blend)
		camera.rotation.y = 0.0
		camera.rotation.z = 0.0

		# FOV: 55.0° (wide tactical) <-> 50.0° (Ghost Recon semi-scoped clarity)
		camera.fov = lerpf(55.0, 50.0, ads_blend)

	# 3. Dynamic Wall & Structure Occlusion Fade
	_update_wall_occlusion()


func _update_wall_occlusion() -> void:
	if camera == null or not is_inside_tree():
		return

	var world_3d := get_world_3d()
	if world_3d == null:
		return
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return

	var cam_pos := camera.global_position
	var player_head := global_position + Vector3(0, 1.2, 0)
	var newly_hit: Dictionary = {}

	# Cast 3 ray passes (center, left flank, right flank) to detect wide occluding structures
	var ray_targets: Array[Vector3] = [
		player_head,
		player_head + Vector3(-0.6, 0, 0),
		player_head + Vector3(0.6, 0, 0)
	]

	var exclude: Array[RID] = [get_rid()]

	for target_pt in ray_targets:
		var cur_exclude := exclude.duplicate()
		for iter in range(3):
			var query := PhysicsRayQueryParameters3D.create(cam_pos, target_pt)
			query.collision_mask = 1
			query.exclude = cur_exclude
			var res := space_state.intersect_ray(query)
			if res.is_empty():
				break

			var col: Object = res.get("collider")
			cur_exclude.append(res.get("rid"))
			if col is Node:
				var node: Node = col as Node
				# Do not occlude floors below the operative's feet/head or cover sandbags
				var is_floor_below: bool = node.name.begins_with("Floor") and node.global_position.y <= player_head.y
				# Do not occlude Level 27 structures when operative is on Level 28
				var is_l27_upper: bool = global_position.y < 4.5 and (node.name.contains("27") or node.name.begins_with("Briefing") or node.name.begins_with("Office") or node.name.begins_with("Security") or node.name.begins_with("Conference") or node.name.begins_with("Chair"))
				if node != self and not is_floor_below and not is_l27_upper and not node.name.begins_with("Sandbag"):
					newly_hit[node] = true

	# Fade newly occluded nodes
	for node: Node in newly_hit.keys():
		if not occluded_nodes.has(node):
			var orig_mat: Material = null
			if "material" in node and node.get("material") is Material:
				orig_mat = node.get("material") as Material
			elif "material_override" in node and node.get("material_override") is Material:
				orig_mat = node.get("material_override") as Material

			if orig_mat is StandardMaterial3D:
				occluded_nodes[node] = orig_mat
				var fade_mat := (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				fade_mat.albedo_color.a = 0.22
				if "material" in node:
					node.set("material", fade_mat)
				elif "material_override" in node:
					node.set("material_override", fade_mat)

	# Restore nodes that are no longer occluding
	var to_remove: Array[Node] = []
	for node: Node in occluded_nodes.keys():
		if not newly_hit.has(node):
			if is_instance_valid(node):
				var orig_mat: Material = occluded_nodes[node]
				if "material" in node:
					node.set("material", orig_mat)
				elif "material_override" in node:
					node.set("material_override", orig_mat)
			to_remove.append(node)

	for node in to_remove:
		occluded_nodes.erase(node)


func _restore_all_occluded_nodes() -> void:
	for node: Node in occluded_nodes.keys():
		if is_instance_valid(node):
			var orig_mat: Material = occluded_nodes[node]
			if "material" in node:
				node.set("material", orig_mat)
			elif "material_override" in node:
				node.set("material_override", orig_mat)
	occluded_nodes.clear()


func add_screen_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process_aim() -> void:
	if camera == null:
		return

	if is_aiming_down_sights:
		# In ADS semi-scoped mode, aim forward along weapon sightline
		current_aim_target = global_position - global_transform.basis.z * 40.0 + Vector3(0, 1.2, 0)
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)

	# High-Ground Aiming: when operative is on Level 27 looking down into the Gate Room
	var target_plane_y: float = global_position.y
	if global_position.y >= 4.5 and ray_normal.y < -0.1:
		var arena_plane := Plane(Vector3.UP, 0.0)
		var arena_hit: Variant = arena_plane.intersects_ray(ray_origin, ray_normal)
		if arena_hit != null:
			var hit_pt: Vector3 = arena_hit
			# If aimed into Gate Room arena in front of Briefing window (Z <= 8.5)
			if hit_pt.z <= 8.5 and absf(hit_pt.x) <= 18.0:
				target_plane_y = 0.0

	var ground_plane := Plane(Vector3.UP, target_plane_y)
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

	if Input.is_action_just_pressed("plant_claymore"):
		_plant_claymore()

	if Input.is_action_just_pressed("reload"):
		current_weapon.reload()

	is_firing = Input.is_action_pressed("fire")
	if is_firing:
		var spread_mult: float = 1.0
		if is_aiming_down_sights:
			spread_mult *= 0.5  # Precision semi-scoped ADS zoom
		if is_crouching:
			spread_mult *= 0.5  # Crouching / bipod stabilization
		elif velocity.length() > 2.0:
			spread_mult *= 1.8  # Running penalty

		current_weapon.try_fire(spread_mult)


func _deploy_tactical_gadget() -> void:
	if class_id == SGCNetworkManager.CLASS_SG3_HEAVY:
		if turret_cooldown > 0.0:
			print("Player %d: Tripod Turret on cooldown (%.1fs remaining)!" % [peer_id, turret_cooldown])
			return
		# Free previous active turret if any
		if active_turret != null and is_instance_valid(active_turret):
			active_turret.queue_free()
			active_turret = null

		var turret_scene := load("res://scenes/props/DeployableTurret.tscn") as PackedScene
		if turret_scene != null:
			var turret := turret_scene.instantiate() as DeployableTurret
			turret.position = global_position - global_transform.basis.z * 1.6
			get_parent().add_child(turret)
			active_turret = turret
			turret_cooldown = TURRET_COOLDOWN_S
			print("Player %d deployed .50 Cal Tripod Turret! Cooldown started (%.0fs)." % [peer_id, TURRET_COOLDOWN_S])
	elif class_id == SGCNetworkManager.CLASS_ONEILL_RECON:
		if active_c4 != null and is_instance_valid(active_c4) and active_c4.is_armed:
			active_c4.detonate()
			active_c4 = null
			print("Player %d detonated C4 Satchel!" % peer_id)
		else:
			if c4_charges_remaining <= 0:
				print("Player %d: No C4 satchels remaining!" % peer_id)
				return
			var c4_scene := load("res://scenes/props/C4Satchel.tscn") as PackedScene
			if c4_scene != null:
				var c4 := c4_scene.instantiate() as C4Satchel
				c4.position = global_position + Vector3(0, 1.0, 0)
				c4.planter = self
				get_parent().add_child(c4)
				c4.apply_central_impulse(-global_transform.basis.z * 10.0 + Vector3.UP * 3.0)
				active_c4 = c4
				c4_charges_remaining -= 1
				print("Player %d threw C4 Satchel Charge! (%d charges left)" % [peer_id, c4_charges_remaining])


func _plant_claymore() -> void:
	if claymore_charges <= 0:
		print("Player %d: Out of M18A1 Claymore mines!" % peer_id)
		return

	var claymore_scene := load("res://scenes/props/ClaymoreMine.tscn") as PackedScene
	if claymore_scene != null:
		var claymore := claymore_scene.instantiate() as Node3D
		claymore.position = global_position - global_transform.basis.z * 1.2 + Vector3(0, 0.05, 0)
		claymore.rotation.y = rotation.y
		claymore.set("planter", self)
		get_parent().add_child(claymore)
		claymore_charges -= 1
		print("Player %d planted M18A1 Claymore! (%d charges left)" % [peer_id, claymore_charges])


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
		mat.albedo_color = Color(0.25, 0.85, 1.0, 1.0)  # Zat'nik'tel electric cyan lightning
	elif is_plasma:
		mat.albedo_color = Color(1.0, 0.5, 0.0, 1.0)  # Goa'uld golden plasma
	else:
		mat.albedo_color = Color(1.0, 0.9, 0.4, 0.8)  # Bullet tracer

	tracer.material_override = mat
	get_tree().root.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	# 1. Straight core line
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)

	# 2. Spikey + jagged electric lightning discharge arcs for Zat'nik'tel
	if is_zat:
		var dist := from.distance_to(to)
		var segments := maxi(4, int(dist * 0.8))
		var dir := (to - from).normalized()
		var perp := dir.cross(Vector3.UP).normalized()
		if perp.length_squared() < 0.01:
			perp = dir.cross(Vector3.RIGHT).normalized()
		var perp_up := dir.cross(perp).normalized()

		var prev_pt := from
		for i in range(1, segments):
			var t := float(i) / float(segments)
			var base_pt := from.lerp(to, t)
			var spike_offset := perp * randf_range(-0.25, 0.25) + perp_up * randf_range(-0.25, 0.25)
			var cur_pt := base_pt + spike_offset
			imm.surface_add_vertex(prev_pt)
			imm.surface_add_vertex(cur_pt)
			prev_pt = cur_pt

			# 3. Spikey lateral branch tendrils
			if i % 2 == 0:
				var branch_end := cur_pt + (perp * randf_range(-0.4, 0.4) + perp_up * randf_range(-0.35, 0.35) + dir * 0.2)
				imm.surface_add_vertex(cur_pt)
				imm.surface_add_vertex(branch_end)

		imm.surface_add_vertex(prev_pt)
		imm.surface_add_vertex(to)

		# Electric discharge impact flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.2, 0.8, 1.0)
		flash.light_energy = 4.0
		flash.omni_range = 3.5
		get_tree().root.add_child(flash)
		flash.global_position = to
		var flash_tween := flash.create_tween()
		flash_tween.tween_property(flash, "light_energy", 0.0, 0.12)
		flash_tween.tween_callback(flash.queue_free)

	imm.surface_end()

	# Fade out and clean up after 0.12s
	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12 if is_zat else 0.08)
	tween.tween_callback(tracer.queue_free)


func _process_downed_crawl(delta: float) -> void:
	is_crouching = true
	is_sprinting = false
	if body_mesh != null:
		body_mesh.scale.y = 0.45
		body_mesh.position.y = 0.25

	var crawl_speed: float = 1.2
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(raw_input.x, 0.0, raw_input.y).normalized()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * crawl_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * crawl_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	# Downed operative can only use secondary sidearm (Beretta M9)
	if active_slot != 2:
		switch_slot(2)

	is_firing = Input.is_action_pressed("fire")
	if is_firing and current_weapon != null:
		current_weapon.try_fire(1.8)

	if Input.is_action_just_pressed("reload") and current_weapon != null:
		current_weapon.reload()


func _process_revive(delta: float) -> void:
	if not Input.is_action_pressed("interact"):
		if current_revive_time > 0.0:
			current_revive_time = 0.0
			active_revive_target = null
			revive_progress_changed.emit(0.0)
		return

	# Find closest downed squadmate or allied SGC Airman within 2.4m
	var closest_downed: CharacterBody3D = null
	var min_d: float = 2.4
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for p in players_container.get_children():
			var teammate := p as CharacterBody3D
			if teammate != null and teammate != self:
				var health := teammate.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and health.is_downed and not health.is_dead:
					var d := global_position.distance_to(teammate.global_position)
					if d < min_d:
						min_d = d
						closest_downed = teammate

	var allies_container := get_tree().root.find_child("Allies", true, false)
	if allies_container != null:
		for a in allies_container.get_children():
			var ally := a as CharacterBody3D
			if ally != null and ally != self:
				var health := ally.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and health.is_downed and not health.is_dead:
					var d := global_position.distance_to(ally.global_position)
					if d < min_d:
						min_d = d
						closest_downed = ally

	if closest_downed != null:
		active_revive_target = closest_downed
		current_revive_time += delta
		var prog := clampf(current_revive_time / REVIVE_DURATION_S, 0.0, 1.0)
		revive_progress_changed.emit(prog)
		if current_revive_time >= REVIVE_DURATION_S:
			var target_health := active_revive_target.get_node_or_null("HealthComponent") as HealthComponent
			if target_health != null:
				target_health.revive(self)
			active_revive_target = null
			current_revive_time = 0.0
			revive_progress_changed.emit(0.0)
			print("Player %d REVIVED squadmate/ally %s!" % [peer_id, closest_downed.name])
	else:
		if current_revive_time > 0.0:
			current_revive_time = 0.0
			active_revive_target = null
			revive_progress_changed.emit(0.0)


func _process_cover_and_peeking(delta: float, _move_dir: Vector3) -> void:
	# Check cover proximity when auto-cover is enabled
	var near_cover := false
	if auto_cover_enabled:
		near_cover = _check_near_cover()

	is_in_cover = near_cover
	if is_in_cover:
		# In cover: Peeking is triggered by Aiming (ADS) or Firing
		var wants_peek := is_aiming_down_sights or Input.is_action_pressed("fire")
		is_peeking = wants_peek
		is_crouching = not is_peeking
		is_sprinting = false
	else:
		is_peeking = false
		is_crouching = Input.is_action_pressed("crouch")
		is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and not is_dragging_body

	if body_mesh != null:
		var target_scale_y: float = 1.0
		var target_pos_y: float = 0.9
		if is_in_cover:
			if is_peeking:
				target_scale_y = 0.85
				target_pos_y = 0.75
			else:
				target_scale_y = 0.55
				target_pos_y = 0.50
		elif is_crouching:
			target_scale_y = 0.65
			target_pos_y = 0.60

		body_mesh.scale.y = move_toward(body_mesh.scale.y, target_scale_y, 6.0 * delta)
		body_mesh.position.y = move_toward(body_mesh.position.y, target_pos_y, 6.0 * delta)


func _check_near_cover() -> bool:
	if not is_inside_tree():
		return false

	# 1. Check nearby nodes in 'cover' group
	for node in get_tree().get_nodes_in_group("cover"):
		if node is Node3D and is_instance_valid(node):
			var n3d := node as Node3D
			var d := global_position.distance_to(n3d.global_position)
			if d <= cover_detection_distance + 1.2:
				return true

	# 2. Check barricades container in bunker geometry
	var barricades := get_tree().root.find_child("Barricades", true, false)
	if barricades != null:
		for child in barricades.get_children():
			if child is Node3D:
				var c3d := child as Node3D
				if global_position.distance_to(c3d.global_position) <= cover_detection_distance + 1.2:
					return true

	# 3. Raycast ahead and to sides for obstacle geometry
	var world3d := get_world_3d()
	if world3d != null and world3d.direct_space_state != null:
		var space := world3d.direct_space_state
		var origin := global_position + Vector3(0, 0.5, 0)
		var dirs: Array[Vector3] = [
			-global_transform.basis.z,
			global_transform.basis.z,
			-global_transform.basis.x,
			global_transform.basis.x,
			(-global_transform.basis.z + global_transform.basis.x).normalized(),
			(-global_transform.basis.z - global_transform.basis.x).normalized()
		]
		for d: Vector3 in dirs:
			var query := PhysicsRayQueryParameters3D.create(origin, origin + d * cover_detection_distance)
			query.collision_mask = 1  # Environment
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var col: Node = hit.get("collider") as Node
				if col != null:
					if col.is_in_group("cover") or col.name.to_lower().contains("sandbag") or col.name.to_lower().contains("barricade") or col.name.to_lower().contains("crate"):
						return true

	return false


func _toggle_drag_body() -> void:
	if is_dragging_body:
		stop_dragging_body()
	else:
		var target := _find_nearby_drag_target()
		if target != null:
			start_dragging_body(target)


func start_dragging_body(body: CharacterBody3D) -> void:
	if body == null or not is_instance_valid(body) or body == self:
		return
	is_dragging_body = true
	dragged_body = body
	print("Player %d started dragging %s into cover." % [peer_id, body.name])


func stop_dragging_body() -> void:
	if is_dragging_body:
		print("Player %d released dragged body." % peer_id)
	is_dragging_body = false
	dragged_body = null


func _find_nearby_drag_target() -> CharacterBody3D:
	if not is_inside_tree():
		return null
	var min_d: float = 2.4
	var best_target: CharacterBody3D = null

	# 1. Downed players
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for p in players_container.get_children():
			var body := p as CharacterBody3D
			if body != null and body != self:
				var health := body.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and health.is_downed and not health.is_dead:
					var d := global_position.distance_to(body.global_position)
					if d < min_d:
						min_d = d
						best_target = body

	# 2. Downed allies
	var allies_container := get_tree().root.find_child("Allies", true, false)
	if allies_container != null:
		for a in allies_container.get_children():
			var body := a as CharacterBody3D
			if body != null and body != self:
				var health := body.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and health.is_downed and not health.is_dead:
					var d := global_position.distance_to(body.global_position)
					if d < min_d:
						min_d = d
						best_target = body

	# 3. Dead enemies (Jaffa corpses)
	var enemies_container := get_tree().root.find_child("Enemies", true, false)
	if enemies_container != null:
		for e in enemies_container.get_children():
			var body := e as CharacterBody3D
			if body != null:
				var health := body.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and health.is_dead:
					var d := global_position.distance_to(body.global_position)
					if d < min_d:
						min_d = d
						best_target = body

	return best_target


func _on_downed() -> void:
	stop_dragging_body()
	if mounted_turret != null:
		mounted_turret.dismount()
		mounted_turret = null
	if body_mesh != null:
		body_mesh.scale.y = 0.45
		body_mesh.position.y = 0.25
	switch_slot(2)
	player_downed.emit(peer_id)
	print("Player %d is DOWNED! Bleeding out..." % peer_id)


func _on_revived() -> void:
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.9
	switch_slot(1)
	player_revived.emit(peer_id)
	print("Player %d REVIVED back into the fight!" % peer_id)


func _on_damage_taken(amount: float, _source: Node, _type: String) -> void:
	if is_local_authority:
		add_screen_shake(clampf(amount * 0.015, 0.15, 0.6))


func _on_died() -> void:
	stop_dragging_body()
	_restore_all_occluded_nodes()
	player_died.emit(peer_id)
	print("Player %d has fallen in combat." % peer_id)


func _on_stunned(duration: float) -> void:
	stop_dragging_body()
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
	# 0. If currently dragging a body, dropping it takes precedence
	if is_dragging_body:
		stop_dragging_body()
		return

	# 1. If currently mounted on a .50 cal turret, dismount
	if mounted_turret != null:
		mounted_turret.dismount()
		mounted_turret = null
		return

	# 2. Check for nearby DeployableTurret to mount
	var nearest_turret: DeployableTurret = null
	var min_turret_dist: float = 2.4
	for node in get_tree().root.find_children("", "DeployableTurret", true, false):
		var t := node as DeployableTurret
		if t != null and t.mounted_player == null:
			var d := global_position.distance_to(t.global_position)
			if d < min_turret_dist:
				min_turret_dist = d
				nearest_turret = t

	if nearest_turret != null:
		mounted_turret = nearest_turret
		nearest_turret.mount(self)
		return

	# 3. Check for nearby interactable stations (Armory, Defense Terminal, Security Console, etc.)
	var nearest_interactable: Node = null
	var min_interact_dist: float = 3.2
	for node in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(node) and node is Node3D:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < min_interact_dist:
				min_interact_dist = d
				nearest_interactable = node

	if nearest_interactable != null and nearest_interactable.has_method("interact"):
		nearest_interactable.interact(self)
		return

	# 4. Check for SGC Blast Door console
	var door_console := get_tree().root.find_child("BlastDoorConsole", true, false)
	if door_console != null and global_position.distance_to(door_console.global_position) <= 2.8:
		var gateroom := get_tree().root.find_child("GateRoom", true, false)
		if gateroom != null and gateroom.has_method("toggle_blast_doors"):
			gateroom.toggle_blast_doors()
		return

	# 5. Check for Lab Data Patch Drive (Research Lab)
	var patch_drive := get_tree().root.find_child("LabDataPatchDrive", true, false) as LabDataPatchDriveScript
	if patch_drive != null and not patch_drive.is_retrieved and global_position.distance_to(patch_drive.global_position) <= 3.2:
		patch_drive.pickup_patch(self)
		is_carrying_patch_rom = true
		return

	# 6. Check for Iris Servo Housing (Gate Room ramp)
	var iris_servo := get_tree().root.find_child("IrisServoHousing", true, false) as IrisServoHousingScript
	if iris_servo != null and not iris_servo.is_repaired and global_position.distance_to(iris_servo.global_position) <= 3.2:
		if not iris_servo.is_repairing:
			iris_servo.start_repair(self)
		else:
			iris_servo.cancel_repair()
		return

	# 7. Check for SGC Dialing Computer / DHD Console (Control Room Mezzanine)
	var dialer := get_tree().root.find_child("SGCDialingConsole", true, false) as DHDDialer
	if dialer == null:
		dialer = get_tree().root.find_child("DHDConsole", true, false) as DHDDialer
	if dialer != null and global_position.distance_to(dialer.global_position) <= 3.5:
		var sgc := dialer as SGCDialingConsoleScript
		if sgc != null and is_carrying_patch_rom and sgc.is_buffer_corrupted:
			if not sgc.is_uploading_patch:
				sgc.start_patch_upload(self)
			else:
				sgc.cancel_patch_upload()
			return

		if dialer.current_phase == DHDDialer.DialPhase.INACTIVE:
			dialer.start_dialing(self)
		else:
			dialer.cancel_dialing()
		return

	# 8. Check for nearby downed ally/squadmate or dead enemy corpse to drag
	var drag_target := _find_nearby_drag_target()
	if drag_target != null:
		start_dragging_body(drag_target)
		return


func set_cctv_camera(cam_pos: Vector3, cam_target: Vector3, cam_fov: float) -> void:
	is_in_cctv_mode = true
	_restore_all_occluded_nodes()
	if camera_rig != null:
		camera_rig.global_position = cam_pos
		camera_rig.rotation = Vector3.ZERO
	if camera != null:
		camera.position = Vector3.ZERO
		camera.look_at(cam_target, Vector3.UP)
		camera.fov = cam_fov


func clear_cctv_camera() -> void:
	is_in_cctv_mode = false
	is_aiming_down_sights = false
	ads_blend = 0.0
	current_iso_cam_y = 12.0
	current_iso_pan_yaw = 0.0
	if camera_rig != null:
		camera_rig.global_position = global_position
		camera_rig.rotation = Vector3.ZERO
	if camera != null:
		camera.position = Vector3(0, 12.0, 7.0)
		camera.rotation = Vector3(-deg_to_rad(60.0), 0, 0)
		camera.fov = 55.0
