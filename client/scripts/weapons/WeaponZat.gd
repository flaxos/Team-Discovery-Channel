class_name WeaponZat
extends WeaponBase
## Zat'nik'tel sidearm (Carter / Teal'c).
## Canonical Stargate mechanics: 1 shot stun, 2 shots kill, 3 shots disintegrate.


func _init() -> void:
	weapon_id = "zat"
	display_name = "Zat'nik'tel"
	damage = 10.0
	fire_rate_rpm = 200.0
	uses_heat = true
	heat_per_shot = 22.0
	heat_dissipation_rate = 25.0
	overheat_cooldown_time = 3.0
	mag_capacity = 999
	reserve_capacity = 999
	base_spread_deg = 0.5
	bloom_per_shot_deg = 0.25
	max_spread_deg = 2.5
	spread_recovery_rate = 20.0
	max_range_m = 35.0
	is_zat = true
	fire_sound_path = "res://audio/sfx_zat.wav"
	noise_radius = 10.0
