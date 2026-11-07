class_name WeaponZat
extends WeaponBase
## Zat'nik'tel sidearm (Carter / Teal'c).
## Canonical Stargate mechanics: 1 shot stun, 2 shots kill, 3 shots disintegrate.


func _init() -> void:
	weapon_id = "zat"
	display_name = "Zat'nik'tel"
	damage = 10.0
	fire_rate_rpm = 100.0
	mag_capacity = 12
	reserve_capacity = 48
	reload_time_s = 1.8
	base_spread_deg = 1.0
	max_range_m = 30.0
	is_zat = true
	fire_sound_path = "res://audio/sfx_zat.wav"
