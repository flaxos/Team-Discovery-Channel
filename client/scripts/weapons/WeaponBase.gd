class_name WeaponBase
extends Node3D
## Base class for SGC firearms, Staff Weapons, and Zat'nik'tels.
## Handles fire rate cooldown, magazine management, spread cones, firing raycasts,
## procedural low-poly weapon meshes, and dynamic muzzle anchoring.

signal fired(origin: Vector3, direction: Vector3, hit_point: Vector3, hit_target: Node)
signal reloaded()
signal ammo_changed(current: int, reserve: int)

@export var weapon_id: String = "p90"
@export var display_name: String = "FN P90 PDW"
@export var damage: float = 24.0
@export var fire_rate_rpm: float = 900.0
@export var mag_capacity: int = 50
@export var reserve_capacity: int = 250
@export var reload_time_s: float = 2.0
@export var base_spread_deg: float = 2.0
@export var max_range_m: float = 50.0

@export var is_plasma: bool = false
@export var is_zat: bool = false
@export var plasma_speed_mps: float = 35.0
@export var fire_sound_path: String = "res://audio/sfx_p90.wav"

var current_ammo: int = 50
var reserve_ammo: int = 250
var is_reloading: bool = false
var fire_cooldown: float = 0.0

@onready var muzzle_point: Marker3D = $MuzzlePoint if has_node("MuzzlePoint") else null
var audio_player: AudioStreamPlayer3D = null


func _ready() -> void:
	current_ammo = mag_capacity
	reserve_ammo = reserve_capacity
	_setup_audio()
	_build_weapon_visual_mesh()


func _setup_audio() -> void:
	if ResourceLoader.exists(fire_sound_path):
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "FireAudio"
		audio_player.stream = load(fire_sound_path)
		audio_player.max_distance = 50.0
		audio_player.unit_size = 10.0
		add_child(audio_player)


func _build_weapon_visual_mesh() -> void:
	if has_node("WeaponModel"):
		return

	var model_root := Node3D.new()
	model_root.name = "WeaponModel"
	add_child(model_root)

	var muzzle_offset := Vector3(0, 0, -0.45)

	match weapon_id:
		"p90":
			# Compact bullpup frame
			var receiver := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.08, 0.14, 0.44)
			receiver.mesh = rm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.18, 0.20, 0.22)
			receiver.material_override = rmat
			model_root.add_child(receiver)

			# Top horizontal magazine strip
			var mag := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(0.06, 0.03, 0.32)
			mag.mesh = mm
			var mmat := StandardMaterial3D.new()
			mmat.albedo_color = Color(0.85, 0.65, 0.2, 0.85)
			mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mag.material_override = mmat
			mag.position = Vector3(0, 0.08, 0.02)
			model_root.add_child(mag)

			muzzle_offset = Vector3(0, 0.02, -0.30)

		"m249":
			# Heavy machine gun receiver + box drum
			var receiver := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.10, 0.16, 0.62)
			receiver.mesh = rm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.24, 0.26, 0.28)
			rmat.metallic = 0.8
			receiver.material_override = rmat
			model_root.add_child(receiver)

			var drum := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.12, 0.14, 0.16)
			drum.mesh = dm
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = Color(0.22, 0.30, 0.18)
			drum.material_override = dmat
			drum.position = Vector3(0, -0.12, 0.04)
			model_root.add_child(drum)

			var barrel := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.02
			bm.bottom_radius = 0.02
			bm.height = 0.35
			barrel.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.15, 0.15, 0.15)
			bmat.metallic = 0.9
			barrel.material_override = bmat
			barrel.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)), Vector3(0, 0.03, -0.42))
			model_root.add_child(barrel)

			muzzle_offset = Vector3(0, 0.03, -0.62)

		"mp5":
			# SMG frame + curved magazine
			var receiver := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.07, 0.12, 0.40)
			receiver.mesh = rm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.12, 0.13, 0.15)
			receiver.material_override = rmat
			model_root.add_child(receiver)

			var mag := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(0.04, 0.16, 0.06)
			mag.mesh = mm
			var mmat := StandardMaterial3D.new()
			mmat.albedo_color = Color(0.2, 0.2, 0.22)
			mag.material_override = mmat
			mag.position = Vector3(0, -0.11, -0.06)
			mag.rotation_degrees.x = 15.0
			model_root.add_child(mag)

			muzzle_offset = Vector3(0, 0.01, -0.36)

		"staff_weapon":
			# Long Goa'uld Naquadah bronze polearm with flared plasma head
			var shaft := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.025
			sm.bottom_radius = 0.025
			sm.height = 1.6
			shaft.mesh = sm
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.68, 0.50, 0.20)
			smat.metallic = 0.85
			smat.roughness = 0.3
			shaft.material_override = smat
			shaft.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)), Vector3(0, 0, -0.2))
			model_root.add_child(shaft)

			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.09, 0.14, 0.24)
			head.mesh = hm
			var hmat := StandardMaterial3D.new()
			hmat.albedo_color = Color(0.9, 0.6, 0.15)
			hmat.emission_enabled = true
			hmat.emission = Color(1.0, 0.55, 0.1)
			hmat.emission_energy_multiplier = 1.2
			head.material_override = hmat
			head.position = Vector3(0, 0, -0.95)
			model_root.add_child(head)

			muzzle_offset = Vector3(0, 0, -1.05)

		"zat":
			# Serpentine curved Goa'uld sidearm with glowing blue arc emitter
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 0.14, 0.24)
			body.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.60, 0.45, 0.20)
			bmat.metallic = 0.85
			body.material_override = bmat
			model_root.add_child(body)

			var arc := MeshInstance3D.new()
			var am := SphereMesh.new()
			am.radius = 0.035
			am.height = 0.07
			arc.mesh = am
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.2, 0.65, 1.0)
			amat.emission_enabled = true
			amat.emission = Color(0.2, 0.65, 1.0)
			amat.emission_energy_multiplier = 1.5
			arc.material_override = amat
			arc.position = Vector3(0, 0.05, -0.14)
			model_root.add_child(arc)

			muzzle_offset = Vector3(0, 0.05, -0.20)

		"m9":
			# Sleek black 9mm handgun
			var slide := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.05, 0.07, 0.20)
			slide.mesh = sm
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.12, 0.12, 0.14)
			smat.metallic = 0.7
			slide.material_override = smat
			model_root.add_child(slide)

			var grip := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.05, 0.10, 0.06)
			grip.mesh = gm
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = Color(0.08, 0.08, 0.08)
			grip.material_override = gmat
			grip.position = Vector3(0, -0.06, 0.06)
			grip.rotation_degrees.x = 12.0
			model_root.add_child(grip)

			muzzle_offset = Vector3(0, 0.02, -0.18)

	if muzzle_point == null:
		var mp := Marker3D.new()
		mp.name = "MuzzlePoint"
		mp.position = muzzle_offset
		add_child(mp)
		muzzle_point = mp


func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)


## Attempts to discharge the weapon, factoring in spread modifier (moving, crouch).
func try_fire(spread_mult: float = 1.0) -> bool:
	if is_reloading or fire_cooldown > 0.0 or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading and reserve_ammo > 0:
			reload()
		return false

	var shot_interval := 60.0 / fire_rate_rpm
	fire_cooldown = shot_interval
	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)

	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position
	var base_forward: Vector3 = -global_transform.basis.z

	# 3D Aim-Elevation: if parent operative has an active 3D aim target, align shot vector toward it
	var parent_entity: Node = get_parent()
	if parent_entity != null and not ("current_aim_target" in parent_entity) and parent_entity.get_parent() != null:
		parent_entity = parent_entity.get_parent()

	if parent_entity != null and "current_aim_target" in parent_entity:
		var target: Vector3 = parent_entity.get("current_aim_target")
		if target != Vector3.ZERO:
			base_forward = (target - origin).normalized()

	# Apply cone spread
	var spread_rad := deg_to_rad(base_spread_deg * spread_mult)
	var random_yaw := randf_range(-spread_rad, spread_rad)
	var random_pitch := randf_range(-spread_rad * 0.5, spread_rad * 0.5)
	var dir := (base_forward.rotated(Vector3.UP, random_yaw)).rotated(base_forward.cross(Vector3.UP).normalized(), random_pitch).normalized()

	_perform_shot(origin, dir)
	return true


func _perform_shot(origin: Vector3, dir: Vector3) -> void:
	if audio_player != null:
		audio_player.play()

	if is_plasma:
		var bolt_scene := load("res://scenes/entities/PlasmaBolt.tscn") as PackedScene
		if bolt_scene != null:
			var bolt := bolt_scene.instantiate() as PlasmaBolt
			var is_enemy := (get_parent() is CharacterBody3D and not (get_parent() is PlayerController3D))
			get_tree().root.add_child(bolt)
			bolt.initialize(origin, dir, get_parent(), is_enemy)
			fired.emit(origin, dir, origin + dir * max_range_m, null)
			return

	var space := get_world_3d().direct_space_state
	var exclude_list: Array[RID] = []
	if get_parent() is CollisionObject3D:
		exclude_list.append((get_parent() as CollisionObject3D).get_rid())
	elif get_parent() != null and get_parent().get_parent() is CollisionObject3D:
		exclude_list.append((get_parent().get_parent() as CollisionObject3D).get_rid())

	var hit_pos := origin + dir * max_range_m
	var hit_node: Node = null

	# Trace ray with ballistic penetration through reinforced observation glass
	for iter in range(4):
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range_m)
		query.collision_mask = 1 | 2 | 4  # World (1), Players (2), and Jaffa (4)
		query.exclude = exclude_list
		var result := space.intersect_ray(query)
		if result.is_empty():
			break

		var col: Node = result["collider"] as Node
		hit_pos = result["position"]
		hit_node = col

		# If hit observation glass, allow high-velocity bullet penetration through window
		if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
			if result.has("rid"):
				exclude_list.append(result["rid"])
			continue
		else:
			_apply_hit(hit_node)
			break

	fired.emit(origin, dir, hit_pos, hit_node)


func _apply_hit(target: Node) -> void:
	if target == null:
		return
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		if is_zat:
			health.apply_zat_shot(get_parent())
		else:
			var damage_type := "plasma" if is_plasma else "bullet"
			health.take_damage(damage, get_parent(), damage_type)


func reload() -> void:
	if is_reloading or current_ammo >= mag_capacity or reserve_ammo <= 0:
		return
	is_reloading = true
	var timer := get_tree().create_timer(reload_time_s)
	timer.timeout.connect(func() -> void:
		var needed := mag_capacity - current_ammo
		var transfer := mini(needed, reserve_ammo)
		current_ammo += transfer
		reserve_ammo -= transfer
		is_reloading = false
		ammo_changed.emit(current_ammo, reserve_ammo)
		reloaded.emit()
	)


func resupply() -> void:
	reserve_ammo = reserve_capacity
	ammo_changed.emit(current_ammo, reserve_ammo)
