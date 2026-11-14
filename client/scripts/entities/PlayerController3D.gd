class_name PlayerController3D
extends CharacterBody3D
## Tactical SGC Operative Controller (Twin-stick Isometric / Top-Down 3D).
## Handles WASD movement, mouse-plane aiming, weapon discharging,
## HealthComponent integration, and Godot 4 multiplayer synchronization.

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const LabDataPatchDriveScript = preload("res://scripts/props/LabDataPatchDrive.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")
const DEPLOYABLE_SHIELD_PATH: String = "res://scenes/props/DeployableShield.tscn"
const DeployableShieldScript = preload("res://scripts/props/DeployableShield.gd")
const SMOKE_GRENADE_PATH: String = "res://scenes/weapons/SmokeGrenade.tscn"
const SmokeGrenadeScript = preload("res://scripts/weapons/SmokeGrenade.gd")
const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")
const RadialCommandWheelScript = preload("res://scripts/ui/RadialCommandWheel.gd")

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
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _server_class_id.is_empty() and val != _server_class_id:
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
var _weapon_inventory: Dictionary = {}
var _server_class_id: String = ""
var _applying_weapon_state: bool = false
var _shot_request_id: int = 0
var _last_shot_request: int = 0
var _revive_lease: float = 0.0
var _server_revive_target: NodePath = NodePath()
var _server_revive_time: float = 0.0
var _revive_send_timer: float = 0.0
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
@export var ads_cam_offset: Vector3 = Vector3(0.55, 1.55, 1.65)
@export var ads_cam_pitch_deg: float = -1.5
var ads_pitch_rad: float = 0.0
var current_locked_aim_y: float = 0.0

# Third-Person Shooter (TPS) Camera & Zoom System
@export var tps_zoom_distance: float = 4.2 # Default zoomed-out third person distance (1.2m to 6.5m)
const TPS_MIN_ZOOM: float = 1.2 # Close over-shoulder view
const TPS_MAX_ZOOM: float = 6.5 # Wide tactical third person view
const TPS_ZOOM_STEP: float = 0.35 # Distance step per mouse wheel notch

# Right-Click ADS Extra Zoom (Wildlands close sightline to Near-FPS)
@export var ads_zoom_distance: float = 0.85 # Extra tight ADS sightline (0.35m to 1.65m)
const ADS_MIN_ZOOM: float = 0.35 # Near-FPS sightline
const ADS_MAX_ZOOM: float = 1.65 # Over-shoulder sightline
const ADS_ZOOM_STEP: float = 0.15 # Distance step per mouse wheel notch in ADS

# Sprint 19: Dynamic Proximity Transparency / Fade on Player Model
var original_visual_materials: Dictionary = {}
var current_player_alpha: float = 1.0

# Windowed Mode Mouse Cursor Confinement (Captured in gameplay)
var is_window_focused: bool = true
var current_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
@export var auto_y_aim_enabled: bool = true
var is_crouch_toggled: bool = false
var active_c4_timer_mode: int = 0  # 0: Remote, 1: 5s, 2: 10s, 3: 30s
var is_carrying_patch_rom: bool = false
var auto_cover_enabled: bool = true
var is_in_cover: bool = false
var is_peeking: bool = false
var cover_detection_distance: float = 1.35
var is_dragging_body: bool = false
var dragged_body: CharacterBody3D = null
const DRAG_SPEED: float = 3.2
var deployable_shields_count: int = 1
const MAX_DEPLOYABLE_SHIELDS: int = 1
var smoke_grenades_count: int = 2
const MAX_SMOKE_GRENADES: int = 2
var q_press_time_ms: int = 0
var command_press_time_ms: int = 0
var is_holding_command_input: bool = false
var is_command_wheel_open: bool = false
var command_press_start_pos: Vector2 = Vector2.ZERO
var locked_target_world_pos: Vector3 = Vector3.ZERO

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
	is_local_authority = ((multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1) == peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
		var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
		if net != null:
			net.configure_mission_sync($MultiplayerSynchronizer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		is_window_focused = false
		if is_inside_tree():
			close_squad_command_wheel()
		if is_local_authority:
			if is_inside_tree():
				_bindings().release_all()
			current_mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		is_window_focused = true
		if is_local_authority and not _is_ui_modal_open():
			_update_mouse_mode()


func _exit_tree() -> void:
	if is_instance_valid(lift_floor_dialog):
		lift_floor_dialog.queue_free()
	close_squad_command_wheel()
	_restore_all_occluded_nodes()
	_restore_visual_materials()


func _ready() -> void:
	collision_mask |= 128
	floor_snap_length = 0.4
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and net.peers.has(peer_id):
		class_id = net.peers[peer_id].get("class_id", class_id)
		player_callsign = net.peers[peer_id].get("name", "OPERATIVE")
	elif net != null and peer_id == 1:
		player_callsign = net.player_name

	if multiplayer.is_server():
		_server_class_id = class_id
	_setup_replication()
	_apply_class_profile(class_id)
	_setup_visual_materials()
	_update_mouse_mode()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_weapon_snapshot.rpc_id(1)

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
			camera.position = Vector3(0.0, current_iso_cam_y, 7.0)
			camera.rotation.x = deg_to_rad(-60.0)
		if camera != null:
			camera.current = true
		if laser_sight != null:
			laser_sight.visible = true
	else:
		if camera != null:
			camera.current = false


var lift_floor_dialog: AcceptDialog


func _is_ui_modal_open() -> bool:
	if is_instance_valid(lift_floor_dialog) and lift_floor_dialog.visible:
		return true
	if not is_inside_tree() or get_tree() == null:
		return false
	var hud := MissionWorld.find(self, "TacticalHUD")
	if hud != null:
		if hud.get("is_mission_ended") == true:
			return true
		var vm: Control = hud.get("victory_modal") as Control
		if vm != null and vm.visible:
			return true
		var pm: Control = hud.get("pause_menu") as Control
		if pm != null and pm.visible:
			return true
		var km: Control = hud.get("keybindings_modal") as Control
		if km != null and km.visible:
			return true
	var standalone_km := MissionWorld.find(self, "KeybindingsModal") as Control
	if standalone_km != null and standalone_km.visible:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_authority or not is_window_focused or is_in_cctv_mode or _is_ui_modal_open():
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if is_command_wheel_open:
			var hud := _get_tactical_hud()
			if hud != null:
				hud.update_radial_command_wheel_rel(motion.relative)
			get_viewport().set_input_as_handled()
			return

		# Unified Third-Person Shooter Look: mouse pitch and yaw control always active
		# Sensitivity scaling: scale down during ADS for precision tracking
		var sens_mult: float = lerpf(1.0, 0.55, ads_blend)
		rotation.y -= motion.relative.x * 0.0028 * sens_mult
		ads_pitch_rad = clampf(ads_pitch_rad - motion.relative.y * 0.0022 * sens_mult, deg_to_rad(-35.0), deg_to_rad(35.0))
		current_iso_pan_yaw = rotation.y
		return
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_update_mouse_mode()
	if health_component != null and (health_component.is_dead or health_component.is_stunned or health_component.is_downed):
		if health_component.is_downed and event.is_action_pressed("reload") and current_weapon != null:
			current_weapon.reload()
		return
	if event.is_action_pressed("squad_command"):
		_on_command_input_pressed()
	elif event.is_action_released("squad_command"):
		# Releasing an alternate binding must not close a still-held command.
		if not Input.is_action_pressed("squad_command"):
			_on_command_input_released()
	elif event.is_action_pressed("squad_ping"):
		_try_issue_squad_ping()
	elif event.is_action_pressed("crouch"):
		is_crouch_toggled = not is_crouch_toggled
	elif event.is_action_pressed("c4_mode"):
		active_c4_timer_mode = (active_c4_timer_mode + 1) % 4
	elif event.is_action_pressed("deploy_shield"):
		deploy_shield()
	elif event.is_action_pressed("throw_smoke"):
		throw_smoke_grenade()
	elif event.is_action_pressed("drag_body"):
		_toggle_drag_body()
	elif event.is_action_pressed("gadget"):
		if is_dragging_body or _find_nearby_drag_target() != null:
			_toggle_drag_body()
		else:
			_deploy_tactical_gadget()
	elif event.is_action_pressed("weapon_primary"):
		switch_slot(1)
	elif event.is_action_pressed("weapon_secondary"):
		switch_slot(2)
	elif event.is_action_pressed("plant_claymore"):
		_plant_claymore()
	elif event.is_action_pressed("reload") and current_weapon != null:
		current_weapon.reload()
	elif event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		var direction: float = -1.0 if event.is_action_pressed("zoom_in") else 1.0
		if is_aiming_down_sights:
			ads_zoom_distance = clampf(ads_zoom_distance + direction * ADS_ZOOM_STEP, ADS_MIN_ZOOM, ADS_MAX_ZOOM)
		else:
			tps_zoom_distance = clampf(tps_zoom_distance + direction * TPS_ZOOM_STEP, TPS_MIN_ZOOM, TPS_MAX_ZOOM)
		get_viewport().set_input_as_handled()


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
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
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

	_setup_visual_materials()


func switch_slot(slot: int) -> void:
	if slot not in [1, 2]:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and not _applying_weapon_state:
		if is_local_authority:
			_equip_slot_local(slot)
			server_request_slot.rpc_id(1, slot)
		return
	_equip_slot_local(slot)
	if multiplayer.is_server():
		_broadcast_weapon_state()


func _equip_slot_local(slot: int) -> void:
	if active_slot == slot and current_weapon != null:
		return
	active_slot = slot
	_equip_weapon_by_id(primary_weapon_id if slot == 1 else secondary_weapon_id)


func _equip_weapon_by_id(weapon_id: String) -> void:
	if weapon_holder == null:
		return

	for child: Node in weapon_holder.get_children():
		if child is WeaponBase:
			child.hide()
	if _weapon_inventory.has(weapon_id) and is_instance_valid(_weapon_inventory[weapon_id]):
		current_weapon = _weapon_inventory[weapon_id]
		current_weapon.show()
		weapon_ammo_changed.emit(current_weapon.current_ammo, current_weapon.reserve_ammo)
		return

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
	_weapon_inventory[weapon_id] = new_weapon
	current_weapon.position = Vector3(0.3, 0.9, -0.4)

	# Connect weapon signals
	new_weapon.ammo_changed.connect(func(cur: int, res: int) -> void:
		if current_weapon == new_weapon:
			weapon_ammo_changed.emit(cur, res)
	)
	current_weapon.fired.connect(_on_weapon_fired)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_revive_tick(delta)
	# Non-authorities rely on MultiplayerSynchronizer replication for position/rotation
	if not is_local_authority:
		move_and_slide()
		return

	# If victory / defeat / pause UI modal is open, ensure mouse is visible and suppress movement & firing
	if not is_window_focused or _is_ui_modal_open():
		close_squad_command_wheel()
		is_aiming_down_sights = false
		_update_mouse_mode()
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_update_camera_and_occlusion(delta)
		return

	# Handle dead state
	if health_component != null and health_component.is_dead:
		is_aiming_down_sights = false
		_update_mouse_mode()
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Handle downed / bleedout state
	if health_component != null and health_component.is_downed:
		is_aiming_down_sights = false
		_update_mouse_mode()
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
		_update_mouse_mode()
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Check Right-Click Aim Down Sights (ADS)
	var wants_ads: bool = Input.is_action_pressed("aim") and not is_in_cctv_mode
	var ads_state_changed: bool = (is_aiming_down_sights != wants_ads)
	is_aiming_down_sights = wants_ads

	if is_local_authority and ads_state_changed:
		_update_mouse_mode()
		if not wants_ads:
			current_iso_pan_yaw = rotation.y

	# Radial Squad Command Wheel hold threshold (>= 200ms)
	if is_holding_command_input and not is_command_wheel_open:
		var elapsed_hold: int = Time.get_ticks_msec() - command_press_time_ms
		if elapsed_hold >= 200:
			open_squad_command_wheel()

	# Aiming towards mouse intersection on horizontal plane
	_process_aim()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# Process reviving nearby downed teammates while holding interact
	_process_revive(delta)

	# Process Iris servo repair channeling
	var iris_servo := MissionWorld.find(self, "IrisServoHousing") as IrisServoHousingScript
	if iris_servo != null and iris_servo.is_repairing and iris_servo.repairer_player == self:
		iris_servo.update_repair(delta)

	# Process SGC Dialing console patch upload channeling
	var sgc_console := MissionWorld.find(self, "SGCDialingConsole") as SGCDialingConsoleScript
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
				if mounted_turret.try_manual_fire(aim_dir):
					add_screen_shake(0.20)
		_update_camera_and_occlusion(delta)
		return

	# If actively dialing SGC console or DHD console, route directional inputs to glyph entries
	var dhd := MissionWorld.find(self, "SGCDialingConsole") as DHDDialer
	if dhd == null:
		dhd = MissionWorld.find(self, "DHDConsole") as DHDDialer
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
	else:
		velocity.y = 0.0

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

	# Level 27 Complex remains visible so Observation Lounge overlooks the Gate Room
	var l27_node: Node3D = null
	if get_tree() != null and get_tree().current_scene != null:
		l27_node = get_tree().current_scene.get_node_or_null("Level27Complex") as Node3D
	if l27_node == null and get_tree() != null and get_tree().root != null:
		l27_node = MissionWorld.find(self, "Level27Complex") as Node3D
	if l27_node != null and not l27_node.visible:
		l27_node.visible = true

	# Smooth ADS transition weight (0.0 = TPS default, 1.0 = ADS extra zoom & precision)
	var target_ads := 1.0 if is_aiming_down_sights else 0.0
	ads_blend = move_toward(ads_blend, target_ads, 8.0 * delta)

	# Camera rig tracks player operative center
	var desired_cam_pos := global_position
	var target_cam_pos := camera_rig.global_position.lerp(desired_cam_pos, 15.0 * delta)

	# Procedural trauma screen shake
	var off_yaw: float = 0.0
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - 1.8 * delta)
		var shake_p := trauma * trauma
		var off_x := (randf() * 2.0 - 1.0) * max_shake_offset * shake_p
		var off_z := (randf() * 2.0 - 1.0) * max_shake_offset * shake_p
		off_yaw = deg_to_rad((randf() * 2.0 - 1.0) * max_shake_yaw_deg * shake_p)
		target_cam_pos += Vector3(off_x, 0, off_z)

	camera_rig.global_position = target_cam_pos
	camera_rig.rotation.y = rotation.y + off_yaw

	if camera != null:
		# Effective distance blending between TPS default and tight ADS
		var eff_dist: float = lerpf(tps_zoom_distance, ads_zoom_distance, ads_blend)

		# Lateral shoulder offset X (0.28m at tight sightline up to 0.75m at wide third-person)
		var dist_ratio: float = clampf((eff_dist - ADS_MIN_ZOOM) / (TPS_MAX_ZOOM - ADS_MIN_ZOOM), 0.0, 1.0)
		var target_x: float = lerpf(0.28, 0.75, dist_ratio)

		# Elevation height Y (1.55m eye-level at close sightline up to 2.10m at wide view)
		var target_y: float = lerpf(1.55, 2.10, dist_ratio)

		camera.position = Vector3(target_x, target_y, eff_dist)

		# Pitch angle: slightly downward base pitch when zoomed out, leveling to -1.5 deg in tight sightline, plus mouse pitch
		var base_pitch: float = lerpf(deg_to_rad(-8.0), deg_to_rad(ads_cam_pitch_deg), ads_blend)
		camera.rotation.x = base_pitch + ads_pitch_rad
		camera.rotation.y = 0.0
		camera.rotation.z = 0.0

		# FOV: 60 deg in wide third person, tightening to 46 deg in ADS (or 44 deg at min zoom)
		var wide_fov: float = lerpf(55.0, 62.0, dist_ratio)
		var ads_fov: float = lerpf(44.0, 50.0, clampf((ads_zoom_distance - ADS_MIN_ZOOM) / (ADS_MAX_ZOOM - ADS_MIN_ZOOM), 0.0, 1.0))
		camera.fov = lerpf(wide_fov, ads_fov, ads_blend)

	# 3. Dynamic Player Model Proximity Fade
	_update_proximity_fade(delta)

	# 4. Dynamic Wall & Structure Occlusion Fade
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
			query.collision_mask = 129
			query.exclude = cur_exclude
			var res := space_state.intersect_ray(query)
			if res.is_empty():
				break

			var col: Object = res.get("collider")
			cur_exclude.append(res.get("rid"))
			if col is Node:
				var node: Node = col as Node
				if node.has_meta("asset_slot") and node.get_child_count() > 0:
					node = node.get_child(0)
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
	var to_remove: Array[Variant] = []
	@warning_ignore("untyped_declaration") # Freed object keys must be checked before casting.
	for node: Variant in occluded_nodes.keys():
		if not newly_hit.has(node):
			if is_instance_valid(node):
				var orig_mat: Material = occluded_nodes[node]
				if "material" in node:
					node.set("material", orig_mat)
				elif "material_override" in node:
					node.set("material_override", orig_mat)
			to_remove.append(node)

	@warning_ignore("untyped_declaration")
	for node in to_remove:
		occluded_nodes.erase(node)


func _restore_all_occluded_nodes() -> void:
	@warning_ignore("untyped_declaration") # Freed object keys must be checked before casting.
	for node: Variant in occluded_nodes.keys():
		if is_instance_valid(node):
			var orig_mat: Material = occluded_nodes[node]
			if "material" in node:
				node.set("material", orig_mat)
			elif "material_override" in node:
				node.set("material_override", orig_mat)
	occluded_nodes.clear()


func _update_mouse_mode() -> void:
	if not is_local_authority:
		return

	var target_mode: int = Input.MOUSE_MODE_CAPTURED
	if not is_window_focused or _is_ui_modal_open():
		target_mode = Input.MOUSE_MODE_VISIBLE
	elif health_component != null and (health_component.is_dead or health_component.is_downed or health_component.is_stunned):
		target_mode = Input.MOUSE_MODE_VISIBLE
	elif is_in_cctv_mode:
		target_mode = Input.MOUSE_MODE_VISIBLE
	else:
		target_mode = Input.MOUSE_MODE_CAPTURED

	current_mouse_mode = target_mode
	Input.mouse_mode = target_mode


func _setup_visual_materials() -> void:
	original_visual_materials.clear()
	var visuals := get_node_or_null("Visuals") as Node3D
	if visuals == null:
		return
	_collect_mesh_instances(visuals)


func _collect_mesh_instances(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var orig: Material = null
			if mi.material_override != null and not mi.material_override.has_meta("is_proximity_fade_mat"):
				orig = mi.material_override
			elif mi.get_surface_override_material(0) != null:
				orig = mi.get_surface_override_material(0)
			elif mi.mesh != null and mi.mesh.surface_get_material(0) != null:
				orig = mi.mesh.surface_get_material(0)
			original_visual_materials[mi] = orig
		if child.get_child_count() > 0:
			_collect_mesh_instances(child)


func _update_proximity_fade(delta: float = 1.0) -> void:
	if original_visual_materials.is_empty():
		_setup_visual_materials()

	var eff_dist: float = lerpf(tps_zoom_distance, ads_zoom_distance, ads_blend)
	var target_alpha: float = 1.0
	if eff_dist < 1.60:
		var t_fade: float = clampf((eff_dist - ADS_MIN_ZOOM) / (1.60 - ADS_MIN_ZOOM), 0.0, 1.0)
		target_alpha = lerpf(0.15, 1.0, t_fade)

	current_player_alpha = move_toward(current_player_alpha, target_alpha, 8.0 * delta)

	var mesh_keys: Array = original_visual_materials.keys()
	if current_player_alpha >= 0.999:
		for mi_obj: Variant in mesh_keys:
			if not is_instance_valid(mi_obj):
				original_visual_materials.erase(mi_obj)
				continue
			var mi := mi_obj as MeshInstance3D
			if mi != null and is_instance_valid(mi):
				if mi.material_override != null and mi.material_override.has_meta("is_proximity_fade_mat"):
					mi.material_override = original_visual_materials.get(mi, null) as Material
		return

	for mi_obj: Variant in mesh_keys:
		if not is_instance_valid(mi_obj):
			original_visual_materials.erase(mi_obj)
			continue
		var mi := mi_obj as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			var base_mat: Material = original_visual_materials.get(mi, null) as Material
			var fade_mat: StandardMaterial3D = null

			if mi.material_override != null and mi.material_override.has_meta("is_proximity_fade_mat"):
				fade_mat = mi.material_override as StandardMaterial3D
			else:
				if base_mat is StandardMaterial3D:
					fade_mat = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					fade_mat = StandardMaterial3D.new()
					if base_mat != null and "albedo_color" in base_mat:
						fade_mat.albedo_color = base_mat.get("albedo_color") as Color
				fade_mat.set_meta("is_proximity_fade_mat", true)
				fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.material_override = fade_mat

			if fade_mat != null:
				fade_mat.albedo_color.a = current_player_alpha


func _restore_visual_materials() -> void:
	var mesh_keys: Array = original_visual_materials.keys()
	for mi_obj: Variant in mesh_keys:
		if not is_instance_valid(mi_obj):
			original_visual_materials.erase(mi_obj)
			continue
		var mi := mi_obj as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			var orig_mat: Material = original_visual_materials.get(mi, null) as Material
			mi.material_override = orig_mat
	current_player_alpha = 1.0


func add_screen_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _calculate_auto_y_aim_target(_mouse_pos: Vector2 = Vector2.ZERO) -> Vector3:
	if camera == null:
		return Vector3.ZERO

	# Third-Person Shooter Sightline 3D raycast
	var cam_forward := -camera.global_transform.basis.z
	var ray_start := camera.global_position
	var ray_end := ray_start + cam_forward * 80.0
	if is_inside_tree():
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collision_mask = 1 | 4  # World geometry + Enemies
			query.exclude = [get_rid()]
			var res := space_state.intersect_ray(query)
			if not res.is_empty():
				return res["position"] as Vector3
	return ray_end


func _process_aim() -> void:
	if camera == null:
		return

	if is_command_wheel_open:
		current_aim_target = locked_target_world_pos
		return

	var hit := _calculate_auto_y_aim_target()
	current_aim_target = hit

	# 3D Weapon visual pitch alignment towards aim target
	if weapon_holder != null and hit != Vector3.ZERO:
		var local_target := to_local(hit) - weapon_holder.position
		var pitch_rad := atan2(local_target.y, -local_target.z)
		weapon_holder.rotation.x = clampf(pitch_rad, deg_to_rad(-45.0), deg_to_rad(45.0))


func _process_combat() -> void:
	if current_weapon == null:
		return


	is_firing = Input.is_action_pressed("fire") and not is_command_wheel_open
	if is_firing:
		var spread_mult: float = 1.0
		if is_aiming_down_sights and is_crouching:
			spread_mult = 0.01  # 99% pinpoint laser accuracy when crouched + ADS
		elif is_aiming_down_sights:
			spread_mult *= 0.35  # ADS tight precision
		elif is_crouching:
			spread_mult *= 0.40  # Crouched bipod stabilization
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
			turret.position = MissionWorld.local(get_parent(), global_position - global_transform.basis.z * 1.6)
			get_parent().add_child(turret)
			active_turret = turret
			turret_cooldown = TURRET_COOLDOWN_S
			print("Player %d deployed .50 Cal Tripod Turret! Cooldown started (%.0fs)." % [peer_id, TURRET_COOLDOWN_S])
	elif class_id == SGCNetworkManager.CLASS_ONEILL_RECON:
		if active_c4 != null and is_instance_valid(active_c4) and active_c4.is_armed and active_c4.mode == C4Satchel.C4Mode.REMOTE:
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
				c4.position = MissionWorld.local(get_parent(), global_position + Vector3(0, 1.0, 0))
				c4.planter = self
				if active_c4_timer_mode == 1:
					c4.set_timer_mode(5.0)
				elif active_c4_timer_mode == 2:
					c4.set_timer_mode(10.0)
				elif active_c4_timer_mode == 3:
					c4.set_timer_mode(30.0)
				get_parent().add_child(c4)
				c4.apply_central_impulse(-global_transform.basis.z * 10.0 + Vector3.UP * 3.0)
				if c4.mode == C4Satchel.C4Mode.REMOTE:
					active_c4 = c4
				c4_charges_remaining -= 1
				print("Player %d threw C4 Satchel Charge (Mode: %d)! (%d charges left)" % [peer_id, active_c4_timer_mode, c4_charges_remaining])


func _plant_claymore() -> void:
	if claymore_charges <= 0:
		print("Player %d: Out of M18A1 Claymore mines!" % peer_id)
		return

	var claymore_scene := load("res://scenes/props/ClaymoreMine.tscn") as PackedScene
	if claymore_scene != null:
		var claymore := claymore_scene.instantiate() as Node3D
		claymore.position = MissionWorld.local(get_parent(), global_position - global_transform.basis.z * 1.2 + Vector3(0, 0.05, 0))
		claymore.rotation.y = rotation.y
		claymore.set("planter", self)
		get_parent().add_child(claymore)
		claymore_charges -= 1
		print("Player %d planted M18A1 Claymore! (%d charges left)" % [peer_id, claymore_charges])


func _on_weapon_fired(origin: Vector3, _dir: Vector3, hit_point: Vector3, _hit_node: Node) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var zat: bool = current_weapon != null and current_weapon.is_zat
	var plasma: bool = current_weapon != null and current_weapon.is_plasma
	play_shot_fx(origin, hit_point, plasma, zat)
	SGCNetworkManager.mission_rpc(self, &"play_shot_fx", [origin, hit_point, plasma, zat], health_component)
	_broadcast_weapon_state()


@rpc("any_peer", "call_local", "unreliable")
func play_shot_fx(from: Vector3, to: Vector3, is_plasma: bool, is_zat: bool = false) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and sender != 0 and sender != 1:
		return
	if sender == 1 and is_local_authority:
		return # The firing client already rendered its responsive prediction.
	_render_shot_fx(from, to, is_plasma, is_zat)


func _render_shot_fx(from: Vector3, to: Vector3, is_plasma: bool, is_zat: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
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



func _process_revive(delta: float) -> void:
	_revive_send_timer -= delta
	if not Input.is_action_pressed("interact"):
		if current_revive_time > 0.0:
			current_revive_time = 0.0
			active_revive_target = null
			revive_progress_changed.emit(0.0)
		_send_revive_hold(null)
		return

	# Find closest downed squadmate or allied SGC Airman within 2.4m
	var closest_downed: CharacterBody3D = null
	var min_d: float = 2.4
	var players_container := MissionWorld.find(self, "Players")
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

	var allies_container := MissionWorld.find(self, "Allies")
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
		_send_revive_hold(closest_downed)
		current_revive_time += delta
		var prog := clampf(current_revive_time / REVIVE_DURATION_S, 0.0, 1.0)
		revive_progress_changed.emit(prog)
		if current_revive_time >= REVIVE_DURATION_S:
			var target_health := active_revive_target.get_node_or_null("HealthComponent") as HealthComponent
			if target_health != null and not multiplayer.has_multiplayer_peer():
				target_health.revive(self)
			active_revive_target = null
			current_revive_time = 0.0
			revive_progress_changed.emit(0.0)
			print("Player %d REVIVED squadmate/ally %s!" % [peer_id, closest_downed.name])
	else:
		_send_revive_hold(null)
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
		is_crouching = is_crouch_toggled
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
	for node in MissionWorld.in_group(self, &"cover"):
		if node is Node3D and is_instance_valid(node):
			var n3d := node as Node3D
			var d := global_position.distance_to(n3d.global_position)
			if d <= cover_detection_distance + 1.2:
				return true

	# 2. Check barricades container in bunker geometry
	var barricades := MissionWorld.find(self, "Barricades")
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
	var players_container := MissionWorld.find(self, "Players")
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
	var allies_container := MissionWorld.find(self, "Allies")
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
	var enemies_container := MissionWorld.find(self, "Enemies")
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


func _try_issue_squad_ping() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var mouse_pos := get_viewport().get_visible_rect().size * 0.5
	var cam := camera if (camera != null and camera.current) else get_viewport().get_camera_3d()
	if cam == null:
		var forward_pos := global_position - global_transform.basis.z * 6.0
		issue_squad_command(forward_pos)
		return

	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	query.collision_mask = 1 | 2 | 4  # World, players/allies, enemies
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		var collider: Node = hit.get("collider") as Node
		issue_squad_command(hit_pos, collider)
	else:
		var plane := Plane(Vector3.UP, 0.0)
		var hit_pt: Variant = plane.intersects_ray(from, dir)
		if hit_pt != null:
			issue_squad_command(hit_pt as Vector3, null)


func _on_command_input_pressed() -> void:
	if is_holding_command_input:
		return
	is_holding_command_input = true
	command_press_time_ms = Time.get_ticks_msec()
	q_press_time_ms = command_press_time_ms
	var vp: Viewport = get_viewport()
	command_press_start_pos = vp.get_visible_rect().size * 0.5 if vp != null else Vector2(640.0, 360.0)
	locked_target_world_pos = _calculate_auto_y_aim_target(command_press_start_pos)
	if locked_target_world_pos == Vector3.ZERO:
		locked_target_world_pos = global_position - global_transform.basis.z * 5.0


func _on_command_input_released() -> void:
	if not is_holding_command_input and not is_command_wheel_open:
		return
	var elapsed: int = Time.get_ticks_msec() - command_press_time_ms
	is_holding_command_input = false

	if is_command_wheel_open or elapsed >= 200:
		var cmd: int = RadialCommandWheel.CMD_CANCEL
		var hud := _get_tactical_hud()
		if hud != null:
			cmd = hud.get_radial_selected_command()
			hud.close_radial_command_wheel()
		is_command_wheel_open = false
		if cmd >= 0:
			execute_squad_radial_command(cmd, locked_target_world_pos)
		else:
			print("Player %d cancelled squad radial command wheel." % peer_id)
	else:
		# Quick tap (< 200ms): fire contextual squad quick ping
		is_command_wheel_open = false
		var hud := _get_tactical_hud()
		if hud != null and hud.is_radial_wheel_open():
			hud.close_radial_command_wheel()
		_try_issue_squad_ping()


func open_squad_command_wheel() -> void:
	is_command_wheel_open = true
	var hud := _get_tactical_hud()
	if hud != null:
		hud.open_radial_command_wheel(command_press_start_pos, locked_target_world_pos)


func close_squad_command_wheel() -> void:
	is_command_wheel_open = false
	is_holding_command_input = false
	var hud := _get_tactical_hud() if is_local_authority else null
	if hud != null:
		hud.close_radial_command_wheel()


func execute_squad_radial_command(cmd_index: int, target_world_pos: Vector3) -> void:
	close_squad_command_wheel()
	var hud := _get_tactical_hud()
	var sector_name: String = _get_sector_name_for_pos(target_world_pos)

	if cmd_index == RadialCommandWheel.CMD_REGROUP_ON_ME:
		issue_squad_regroup()
		return

	var airman: SGCAirmanAIScript = _find_nearest_active_airman()
	if airman == null:
		if hud != null:
			hud.show_squad_order_toast("[SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]")
		print("Player %d: [SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]" % peer_id)
		return

	match cmd_index:
		RadialCommandWheel.CMD_MOVE_TO_COVER:
			airman.order_move_to(target_world_pos)
			_spawn_command_waypoint_fx(target_world_pos, cmd_index)
			_play_command_radio_sound()
			if hud != null:
				hud.show_squad_order_toast("[TACTICAL ORDER: %s -> MOVE TO COVER (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
			print("[RADIO SQUAWK] %s: 'Moving to position! Covering the lane!'" % airman.airman_callsign)

		RadialCommandWheel.CMD_HOLD_CORNER:
			var facing: Vector3 = (target_world_pos - global_position).normalized()
			facing.y = 0.0
			if facing.length_squared() < 0.01:
				facing = Vector3(0.0, 0.0, -1.0)
			airman.hold_corner(target_world_pos, facing, "corner")
			_spawn_command_waypoint_fx(target_world_pos, cmd_index)
			_play_command_radio_sound()
			if hud != null:
				hud.show_squad_order_toast("[TACTICAL ORDER: %s -> HOLD CORNER (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
			print("[RADIO SQUAWK] %s: 'Acknowledged! Holding corner! Watching hallway!'" % airman.airman_callsign)

		RadialCommandWheel.CMD_SUPPRESS_HALLWAY:
			var suppress_dir: Vector3 = (target_world_pos - airman.global_position).normalized()
			suppress_dir.y = 0.0
			if suppress_dir.length_squared() < 0.01:
				suppress_dir = (target_world_pos - global_position).normalized()
				suppress_dir.y = 0.0
			if suppress_dir.length_squared() < 0.01:
				suppress_dir = Vector3(0.0, 0.0, -1.0)
			airman.suppress_hallway(suppress_dir, 3.0)
			_spawn_command_waypoint_fx(target_world_pos, cmd_index)
			_play_command_radio_sound()
			if hud != null:
				hud.show_squad_order_toast("[TACTICAL ORDER: %s -> SUPPRESS HALLWAY (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
			print("[RADIO SQUAWK] %s: 'Laying down suppressive fire! Keep your heads down!'" % airman.airman_callsign)

		RadialCommandWheel.CMD_MAN_50_CAL:
			var turret: DeployableTurret = _find_nearest_turret(target_world_pos)
			if turret != null:
				airman.order_mount_turret(turret)
				_spawn_command_waypoint_fx(turret.global_position, cmd_index)
			else:
				airman.order_move_to(target_world_pos)
				_spawn_command_waypoint_fx(target_world_pos, cmd_index)
			_play_command_radio_sound()
			if hud != null:
				hud.show_squad_order_toast("[TACTICAL ORDER: %s -> MAN .50 CAL (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
			print("[RADIO SQUAWK] %s: 'Manning the .50 Cal Browning! Gun ready!'" % airman.airman_callsign)


func _spawn_command_waypoint_fx(pos: Vector3, command_type: int) -> void:
	if not is_inside_tree():
		return
	var col := Color(0.2, 0.85, 1.0, 0.9)
	match command_type:
		RadialCommandWheel.CMD_MOVE_TO_COVER:
			col = Color(0.2, 0.85, 1.0, 0.9) # Cyan
		RadialCommandWheel.CMD_HOLD_CORNER:
			col = Color(0.25, 0.45, 1.0, 0.9) # Blue
		RadialCommandWheel.CMD_SUPPRESS_HALLWAY:
			col = Color(1.0, 0.55, 0.1, 0.9) # Orange
		RadialCommandWheel.CMD_MAN_50_CAL:
			col = Color(1.0, 0.82, 0.2, 0.9) # Gold
		RadialCommandWheel.CMD_REGROUP_ON_ME:
			col = Color(0.2, 0.95, 0.4, 0.9) # Green

	var waypoint := Node3D.new()
	waypoint.name = "CommandWaypointFX"
	waypoint.add_to_group("squad_waypoint")

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.85
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat

	var beacon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.08
	cyl.height = 2.2
	beacon.mesh = cyl
	beacon.position.y = 1.1
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(col.r, col.g, col.b, 0.5)
	beacon.material_override = b_mat

	waypoint.add_child(ring)
	waypoint.add_child(beacon)
	ring.position.y = 0.05
	ring.scale = Vector3(0.2, 0.2, 0.2)

	get_tree().root.add_child(waypoint)
	waypoint.global_position = pos

	var tween := waypoint.create_tween()
	tween.tween_property(ring, "scale", Vector3(1.3, 1.0, 1.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(1.1, 1.0, 1.1), 0.25)
	tween.tween_property(ring, "scale", Vector3(1.4, 1.0, 1.4), 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tween.parallel().tween_property(b_mat, "albedo_color:a", 0.0, 0.9)
	tween.tween_callback(waypoint.queue_free)


func _play_command_radio_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not is_inside_tree():
		return
	var asp := AudioStreamPlayer.new()
	asp.name = "RadioSquawkPlayer"
	var sfx: AudioStream = load("res://audio/sfx_gdo_beep.wav") as AudioStream
	if sfx == null:
		sfx = load("res://audio/sfx_chevron.wav") as AudioStream
	if sfx != null:
		asp.stream = sfx
		asp.volume_db = -3.0
		var bus_idx: int = AudioServer.get_bus_index("SFX")
		if bus_idx != -1:
			asp.bus = "SFX"
		get_tree().root.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	else:
		asp.queue_free()


func _get_tactical_hud() -> TacticalHUD:
	if not is_inside_tree():
		return null
	return MissionWorld.find(self, "TacticalHUD") as TacticalHUD


func _get_all_active_airmen() -> Array[SGCAirmanAIScript]:
	var result: Array[SGCAirmanAIScript] = []
	var allies := MissionWorld.find(self, "Allies")
	if allies != null:
		for child: Node in allies.get_children():
			var a := child as SGCAirmanAIScript
			if a != null and a.health_component != null and not a.health_component.is_dead and not a.health_component.is_downed:
				result.append(a)
	return result


func _find_nearest_turret(pos: Vector3) -> DeployableTurret:
	var turrets := MissionWorld.in_group(self, &"turret")
	var best_turret: DeployableTurret = null
	var min_d: float = 999999.0
	for t: Node in turrets:
		var dt := t as DeployableTurret
		if dt != null:
			var d: float = pos.distance_to(dt.global_position)
			if d < min_d:
				min_d = d
				best_turret = dt
	return best_turret


func _get_sector_name_for_pos(pos: Vector3) -> String:
	var gateroom := MissionWorld.find(self, "GateRoom")
	if gateroom != null and gateroom.has_method("get_current_sector"):
		var sec: String = gateroom.call("get_current_sector", pos) as String
		if not sec.is_empty() and sec != "UNKNOWN":
			return sec.replace("_", " ")
	var hud := _get_tactical_hud()
	if hud != null and not hud.current_sector_id.is_empty() and hud.current_sector_id != "UNKNOWN":
		return hud.current_sector_id.replace("_", " ")
	return "GATE ROOM"


func issue_squad_command(hit_pos: Vector3, target_node: Node = null) -> void:
	var airman := _find_nearest_active_airman()
	if airman == null:
		var hud := _get_tactical_hud()
		if hud != null:
			hud.show_squad_order_toast("[SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]")
		print("Player %d: [SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]" % peer_id)
		return

	var sector_name: String = _get_sector_name_for_pos(hit_pos)

	if target_node != null:
		# Check if target is a DeployableTurret
		var turret := target_node as DeployableTurret
		if turret == null and target_node.has_node("DeployableTurret"):
			turret = target_node.get_node("DeployableTurret") as DeployableTurret
		if turret != null:
			airman.order_mount_turret(turret)
			_spawn_command_waypoint_fx(turret.global_position, RadialCommandWheel.CMD_MAN_50_CAL)
			_play_command_radio_sound()
			var hud := _get_tactical_hud()
			if hud != null:
				hud.show_squad_order_toast("[TACTICAL ORDER: %s -> MAN .50 CAL (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
			print("[RADIO SQUAWK] %s: 'Manning the .50 Cal Browning! Gun ready!'" % airman.airman_callsign)
			return

		# Check if target is a downed ally or squadmate
		var body := target_node as CharacterBody3D
		if body != null:
			var hc := body.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null and hc.is_downed:
				airman.order_revive(body)
				_spawn_command_ping_fx(body.global_position, Color(0.2, 1.0, 0.4))
				_play_command_radio_sound()
				var hud := _get_tactical_hud()
				if hud != null:
					hud.show_squad_order_toast("[TACTICAL ORDER: %s -> REVIVE SQUADMATE (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
				print("[RADIO SQUAWK] %s: 'Squadmate down! Moving to revive!'" % airman.airman_callsign)
				return

	# Move / Take cover at pinged position
	airman.order_move_to(hit_pos)
	_spawn_command_waypoint_fx(hit_pos, RadialCommandWheel.CMD_MOVE_TO_COVER)
	_play_command_radio_sound()
	var hud := _get_tactical_hud()
	if hud != null:
		hud.show_squad_order_toast("[TACTICAL ORDER: %s -> MOVE TO COVER (SECTOR: %s)]" % [airman.airman_callsign, sector_name])
	print("[RADIO SQUAWK] %s: 'Moving to position! Covering the lane!'" % airman.airman_callsign)


func issue_squad_regroup() -> void:
	var hud := _get_tactical_hud()
	var active_airmen := _get_all_active_airmen()
	if active_airmen.is_empty():
		if hud != null:
			hud.show_squad_order_toast("[SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]")
		print("Player %d: [SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]" % peer_id)
		return

	for airman: SGCAirmanAIScript in active_airmen:
		airman.order_regroup(self)

	var sector_name: String = _get_sector_name_for_pos(global_position)
	_spawn_command_waypoint_fx(global_position, RadialCommandWheel.CMD_REGROUP_ON_ME)
	_play_command_radio_sound()
	if hud != null:
		hud.show_squad_order_toast("[TACTICAL ORDER: SQUAD -> REGROUP ON ME (SECTOR: %s)]" % sector_name)
	print("[RADIO SQUAWK] %s: 'Roger that, regrouping on your six!'" % active_airmen[0].airman_callsign)
	print("Player %d ordered ALL SGC Airmen to REGROUP!" % peer_id)


func _find_nearest_active_airman() -> SGCAirmanAIScript:
	var allies := MissionWorld.find(self, "Allies")
	if allies == null:
		return null
	var best_airman: SGCAirmanAIScript = null
	var min_d: float = 999999.0
	for child in allies.get_children():
		var a := child as SGCAirmanAIScript
		if a != null and a.health_component != null and not a.health_component.is_dead and not a.health_component.is_downed:
			var d := global_position.distance_to(a.global_position)
			if d < min_d:
				min_d = d
				best_airman = a
	return best_airman


func _spawn_command_ping_fx(pos: Vector3, color: Color) -> void:
	if not is_inside_tree():
		return
	var ping := Node3D.new()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.65
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	ring.material_override = mat

	ping.add_child(ring)
	ring.position.y = 0.05
	ring.scale = Vector3(0.2, 0.2, 0.2)
	get_tree().root.add_child(ping)
	ping.global_position = pos

	var tween := ping.create_tween()
	tween.tween_property(ring, "scale", Vector3(1.5, 1.0, 1.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.75)
	tween.tween_callback(ping.queue_free)


func deploy_shield() -> void:
	if deployable_shields_count <= 0:
		print("Player %d: No Deployable Ballistic Shields remaining!" % peer_id)
		return
	deployable_shields_count -= 1

	var shield := (load(DEPLOYABLE_SHIELD_PATH) as PackedScene).instantiate() as DeployableShieldScript
	var spawn_pos := global_position - global_transform.basis.z * 1.3
	spawn_pos.y = global_position.y
	shield.position = MissionWorld.local(get_parent(), spawn_pos)
	shield.rotation.y = rotation.y

	var parent := get_parent()
	if parent != null:
		parent.add_child(shield, true)
	else:
		get_tree().root.add_child(shield, true)

	print("Player %d deployed Ballistic Shield at %s (Remaining: %d)" % [peer_id, str(spawn_pos), deployable_shields_count])


func throw_smoke_grenade() -> void:
	if smoke_grenades_count <= 0:
		print("Player %d: No M18 Smoke Grenades remaining!" % peer_id)
		return
	smoke_grenades_count -= 1

	var grenade := (load(SMOKE_GRENADE_PATH) as PackedScene).instantiate() as SmokeGrenadeScript
	var spawn_pos := global_position + Vector3(0, 1.4, 0) - global_transform.basis.z * 0.8
	grenade.position = MissionWorld.local(get_parent(), spawn_pos)
	var throw_vel := (-global_transform.basis.z * 12.0) + Vector3(0, 3.5, 0)
	grenade.linear_velocity = throw_vel

	var parent := get_parent()
	if parent != null:
		parent.add_child(grenade, true)
	else:
		get_tree().root.add_child(grenade, true)

	print("Player %d threw M18 Smoke Grenade! (Remaining: %d)" % [peer_id, smoke_grenades_count])


func _on_downed() -> void:
	close_squad_command_wheel()
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
	close_squad_command_wheel()
	stop_dragging_body()
	_restore_all_occluded_nodes()
	_restore_visual_materials()
	is_aiming_down_sights = false
	_update_mouse_mode()
	player_died.emit(peer_id)
	print("Player %d has fallen in combat." % peer_id)


func _on_stunned(duration: float) -> void:
	close_squad_command_wheel()
	stop_dragging_body()
	print("Player %d stunned by Zat'nik'tel for %.1f seconds." % [peer_id, duration])


func _on_recovered_from_stun() -> void:
	print("Player %d recovered from stun." % peer_id)


func _on_vaporized() -> void:
	close_squad_command_wheel()
	print("Player %d disintegrated by Zat'nik'tel!" % peer_id)
	stop_dragging_body()
	_restore_all_occluded_nodes()
	_restore_visual_materials()
	is_aiming_down_sights = false
	_update_mouse_mode()
	player_died.emit(peer_id)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.2, 0.6, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	get_tree().root.add_child(flash)
	flash.global_position = global_position + Vector3(0, 0.5, 0)

	var tween := create_tween()
	if body_mesh != null:
		tween.tween_property(body_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
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
	for node in MissionWorld.of(self).find_children("", "DeployableTurret", true, false):
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

	# Aim at a specific control before using the proximity fallback.
	var aimed := aimed_interactable()
	if aimed != null:
		aimed.interact(self)
		return

	# 3. Check for nearby interactable stations (Armory, Defense Terminal, Security Console, etc.)
	var nearest_interactable: Node = null
	var min_interact_dist: float = 3.2
	for node in MissionWorld.in_group(self, &"interactable"):
		if is_instance_valid(node) and node is Node3D:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < min_interact_dist:
				min_interact_dist = d
				nearest_interactable = node

	if nearest_interactable != null and nearest_interactable.has_method("interact"):
		nearest_interactable.interact(self)
		return

	# 4. Check for SGC Blast Door console (any console in complex)
	for console_node in MissionWorld.in_group(self, &"blast_door_console"):
		var c := console_node as Node3D
		if c != null and global_position.distance_to(c.global_position) <= 3.0:
			if c.has_method("interact"):
				c.interact(self)
			else:
				var gateroom := MissionWorld.find(self, "GateRoom")
				if gateroom != null and gateroom.has_method("toggle_blast_doors"):
					gateroom.toggle_blast_doors()
			return

	# 5. Check for Lab Data Patch Drive (Research Lab)
	var patch_drive := MissionWorld.find(self, "LabDataPatchDrive") as LabDataPatchDriveScript
	if patch_drive != null and not patch_drive.is_retrieved and global_position.distance_to(patch_drive.global_position) <= 3.2:
		patch_drive.pickup_patch(self)
		is_carrying_patch_rom = true
		return

	# 6. Check for Iris Servo Housing (Gate Room ramp)
	var iris_servo := MissionWorld.find(self, "IrisServoHousing") as IrisServoHousingScript
	if iris_servo != null and not iris_servo.is_repaired and global_position.distance_to(iris_servo.global_position) <= 3.2:
		if not iris_servo.is_repairing:
			iris_servo.start_repair(self)
		else:
			iris_servo.cancel_repair()
		return

	# 7. Check for SGC Dialing Computer / DHD Console (Control Room Mezzanine)
	var dialer := MissionWorld.find(self, "SGCDialingConsole") as DHDDialer
	if dialer == null:
		dialer = MissionWorld.find(self, "DHDConsole") as DHDDialer
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
		elif dialer.current_phase == DHDDialer.DialPhase.COMPLETE:
			var world: Node = MissionWorld.of(self)
			if world != null and world.get("session") != null and sgc != null:
				sgc.request_abort_mission()
				return
			dialer.cancel_dialing()
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
	_restore_visual_materials()
	_update_mouse_mode()
	if camera_rig != null:
		camera_rig.global_position = global_position
		camera_rig.rotation = Vector3.ZERO
	if camera != null:
		camera.position = Vector3(0, 12.0, 7.0)
		camera.rotation = Vector3(-deg_to_rad(60.0), 0, 0)
		camera.fov = 55.0


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")


# Combat requests carry intent only. The server chooses weapon statistics, spread, ray hits and damage.
func _valid_combat_sender() -> bool:
	return multiplayer.is_server() and _combat_peer_allowed(multiplayer.get_remote_sender_id())


func _combat_peer_allowed(sender: int) -> bool:
	return sender == 0 or (sender == peer_id and sender in multiplayer.get_peers())


func _can_use_weapon(slot: int) -> bool:
	return health_component != null and not health_component.is_dead and not health_component.is_stunned and (not health_component.is_downed or slot == 2)


func request_weapon_fire() -> bool:
	if current_weapon == null or not is_local_authority or not _can_use_weapon(active_slot):
		return false
	if not current_weapon.consume_shot():
		return false
	var origin: Vector3 = current_weapon.muzzle_point.global_position
	var direction: Vector3 = (current_aim_target - origin).normalized() if current_aim_target != Vector3.ZERO else -global_transform.basis.z
	_shot_request_id += 1
	server_request_fire.rpc_id(1, _shot_request_id, active_slot, current_weapon.weapon_id, origin, direction, is_aiming_down_sights)
	if current_weapon.audio_player != null:
		current_weapon.audio_player.play()
	_render_shot_fx(origin, origin + direction * current_weapon.max_range_m, current_weapon.is_plasma, current_weapon.is_zat)
	return true


@rpc("any_peer", "call_remote", "reliable")
func server_request_fire(sequence: int, slot: int, weapon_id: String, origin: Vector3, direction: Vector3, aiming: bool) -> void:
	if not _valid_combat_sender() or sequence <= _last_shot_request or slot not in [1, 2] or not _can_use_weapon(slot):
		return
	_last_shot_request = sequence
	# These IDs are chosen by the server class profile or an authenticated armory interaction.
	var allowed: String = primary_weapon_id if slot == 1 else secondary_weapon_id
	if weapon_id != allowed or not origin.is_finite() or not direction.is_finite() or absf(direction.length() - 1.0) > 0.02:
		return
	_equip_slot_local(slot)
	var muzzle: Vector3 = current_weapon.muzzle_point.global_position
	if origin.distance_to(muzzle) > 1.5 or absf(direction.y) > 0.9:
		return
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	if flat.dot(-global_transform.basis.z) < -0.1:
		return
	is_aiming_down_sights = aiming
	var spread: float = 0.01 if aiming and is_crouching else (0.35 if aiming else (0.40 if is_crouching else (1.8 if velocity.length() > 2.0 else 1.0)))
	current_weapon.try_fire(spread, direction)
	_broadcast_weapon_state()


@rpc("any_peer", "call_remote", "reliable")
func server_request_slot(slot: int) -> void:
	if not _valid_combat_sender() or slot not in [1, 2] or not _can_use_weapon(slot):
		return
	_equip_slot_local(slot)
	_broadcast_weapon_state()


func request_weapon_reload() -> void:
	server_request_reload.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func server_request_reload() -> void:
	if _valid_combat_sender() and current_weapon != null and _can_use_weapon(active_slot):
		current_weapon.reload()
		_broadcast_weapon_state()


@rpc("any_peer", "call_remote", "reliable")
func request_weapon_snapshot() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in multiplayer.get_peers():
		_broadcast_weapon_state(multiplayer.get_remote_sender_id())


func _broadcast_weapon_state(peer: int = 0) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or current_weapon == null:
		return
	var weapon: WeaponBase = current_weapon
	if peer > 0:
		sync_weapon_state.rpc_id(peer, active_slot, weapon.weapon_id, weapon.current_ammo, weapon.reserve_ammo, weapon.current_heat, weapon.is_overheated, weapon.is_reloading)
	else:
		SGCNetworkManager.mission_rpc(self, &"sync_weapon_state", [active_slot, weapon.weapon_id, weapon.current_ammo, weapon.reserve_ammo, weapon.current_heat, weapon.is_overheated, weapon.is_reloading], health_component)


@rpc("any_peer", "call_remote", "reliable")
func sync_weapon_state(slot: int, weapon_id: String, ammo: int, reserve: int, heat: float, overheated: bool, reloading: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_applying_weapon_state = true
	_equip_slot_local(slot)
	_applying_weapon_state = false
	if current_weapon == null or current_weapon.weapon_id != weapon_id:
		return
	current_weapon.current_ammo = ammo
	current_weapon.reserve_ammo = reserve
	current_weapon.current_heat = heat
	current_weapon.is_overheated = overheated
	current_weapon.is_reloading = reloading
	weapon_ammo_changed.emit(ammo, reserve)
	current_weapon.heat_changed.emit(heat, overheated)


func _send_revive_hold(target: Node) -> void:
	if not multiplayer.has_multiplayer_peer() or _revive_send_timer > 0.0:
		return
	_revive_send_timer = 0.1
	var path: NodePath = get_parent().get_path_to(target) if is_instance_valid(target) else NodePath()
	if multiplayer.is_server():
		server_revive_hold(path)
	else:
		server_revive_hold.rpc_id(1, path)


@rpc("any_peer", "call_local", "reliable")
func server_revive_hold(target_path: NodePath) -> void:
	if not _valid_combat_sender() or not _can_use_weapon(1):
		return
	if target_path.is_empty():
		_server_revive_target = NodePath()
		_server_revive_time = 0.0
		return
	if target_path != _server_revive_target:
		_server_revive_time = 0.0
	_server_revive_target = target_path
	_revive_lease = 0.35


func _server_revive_tick(delta: float) -> void:
	if _server_revive_target.is_empty():
		return
	_revive_lease -= delta
	var target: Node3D = get_parent().get_node_or_null(_server_revive_target) as Node3D
	var health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent if target != null else null
	if _revive_lease <= 0.0 or not _can_use_weapon(1) or target == self or target == null or global_position.distance_to(target.global_position) > 2.4 or health == null or not health.is_downed or health.is_dead:
		_server_revive_target = NodePath()
		_server_revive_time = 0.0
		return
	_server_revive_time += delta
	if _server_revive_time >= REVIVE_DURATION_S:
		health.revive(self)
		_server_revive_target = NodePath()
		_server_revive_time = 0.0


func aimed_interactable() -> Node:
	if camera == null:
		return null
	var from := camera.global_position
	var end := from - camera.global_basis.z * 8.0
	var query := PhysicsRayQueryParameters3D.create(from, end, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node := hit["collider"] as Node
	while node != null:
		if (
			node.is_in_group("interactable")
			and node.has_method("interact")
			and node is Node3D
			and global_position.distance_to(node.global_position) < 3.2
		):
			return node
		node = node.get_parent()
	return null


func open_lift_selector(lift: SGCElevator) -> void:
	if is_instance_valid(lift_floor_dialog):
		lift_floor_dialog.queue_free()
	lift_floor_dialog = AcceptDialog.new()
	lift_floor_dialog.title = "Select SGC sublevel"
	lift_floor_dialog.ok_button_text = "Cancel"
	var list := VBoxContainer.new()
	for floor_number: int in lift.SUPPORTED_FLOORS:
		var button := Button.new()
		button.text = (
			"Level %d%s"
			% [floor_number, " — current floor" if floor_number == lift.current_floor else ""]
		)
		button.custom_minimum_size = Vector2(300, 48)
		button.disabled = floor_number == lift.current_floor or lift.is_moving
		button.pressed.connect(
			func() -> void:
				lift.select_floor(floor_number)
				lift_floor_dialog.hide()
				_update_mouse_mode()
		)
		list.add_child(button)
	lift_floor_dialog.add_child(list)
	get_tree().root.add_child(lift_floor_dialog)
	lift_floor_dialog.canceled.connect(_update_mouse_mode)
	lift_floor_dialog.confirmed.connect(_update_mouse_mode)
	lift_floor_dialog.popup_centered(Vector2i(340, 220))
	_update_mouse_mode()
