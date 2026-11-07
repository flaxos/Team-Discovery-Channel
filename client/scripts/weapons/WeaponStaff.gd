class_name WeaponStaff
extends WeaponBase
## Ma'Tok Goa'uld Staff Weapon (Allied Jaffa / Teal'c).
## High-energy liquid Naquadah plasma discharge, high single-shot impact.


func _init() -> void:
	weapon_id = "staff_weapon"
	display_name = "Ma'Tok Staff Weapon"
	damage = 75.0
	fire_rate_rpm = 120.0
	mag_capacity = 25
	reserve_capacity = 100
	reload_time_s = 2.5
	base_spread_deg = 1.2
	max_range_m = 55.0
	is_plasma = true
	fire_sound_path = "res://audio/sfx_staff_fire.wav"
