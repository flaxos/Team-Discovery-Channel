class_name WeaponStaff
extends WeaponBase
## Ma'Tok Goa'uld Staff Weapon (Allied Jaffa / Teal'c).
## High-energy liquid Naquadah plasma discharge, high single-shot impact.


func _init() -> void:
	weapon_id = "staff_weapon"
	display_name = "Ma'Tok Staff Weapon"
	damage = 85.0
	fire_rate_rpm = 180.0
	uses_heat = true
	heat_per_shot = 18.0
	heat_dissipation_rate = 22.0
	overheat_cooldown_time = 3.0
	mag_capacity = 999
	reserve_capacity = 999
	base_spread_deg = 0.8
	bloom_per_shot_deg = 0.35
	max_spread_deg = 3.5
	spread_recovery_rate = 18.0
	max_range_m = 55.0
	is_plasma = true
	plasma_speed_mps = 45.0
	fire_sound_path = "res://audio/sfx_staff_fire.wav"
