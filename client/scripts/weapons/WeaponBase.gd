class_name WeaponBase
extends Node3D
## Base class for SGC firearms, Staff Weapons, and Zat'nik'tels.
## Handles fire rate cooldown, magazine management, spread cones, and firing raycasts.

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

var current_ammo: int = 50
var reserve_ammo: int = 250
var is_reloading: bool = false
var fire_cooldown: float = 0.0

@onready var muzzle_point: Marker3D = $MuzzlePoint if has_node("MuzzlePoint") else null


func _ready() -> void:
	current_ammo = mag_capacity
	reserve_ammo = reserve_capacity


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

	# Apply cone spread
	var spread_rad := deg_to_rad(base_spread_deg * spread_mult)
	var random_yaw := randf_range(-spread_rad, spread_rad)
	var random_pitch := randf_range(-spread_rad * 0.5, spread_rad * 0.5)
	var dir := (base_forward.rotated(Vector3.UP, random_yaw)).rotated(base_forward.cross(Vector3.UP).normalized(), random_pitch).normalized()

	_perform_shot(origin, dir)
	return true


func _perform_shot(origin: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range_m)
	query.collision_mask = 1 | 4  # World (1) and Enemies (3) / Players (2)
	query.exclude = [get_parent()]

	var result := space.intersect_ray(query)
	var hit_pos := origin + dir * max_range_m
	var hit_node: Node = null

	if not result.is_empty():
		hit_pos = result["position"]
		hit_node = result["collider"] as Node
		_apply_hit(hit_node)

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
