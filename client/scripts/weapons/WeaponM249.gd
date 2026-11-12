class_name WeaponM249
extends WeaponBase
## M249 SAW Light Machine Gun (SG-3 Heavy Support Marine).
## 100-round drum, heavy moving recoil penalty, stabilized when crouched / braced on tripod.


func _init() -> void:
	weapon_id = "m249"
	display_name = "M249 SAW Squad Automatic Weapon"
	damage = 34.0
	fire_rate_rpm = 750.0
	mag_capacity = 100
	magazine_size = 100
	reserve_capacity = 300
	reserve_ammo = 300
	reload_time_s = 3.6
	base_spread_deg = 3.2
	current_spread_deg = 3.2
	bloom_per_shot_deg = 0.75
	max_spread_deg = 8.5
	spread_recovery_rate = 14.0
	max_range_m = 60.0
	fire_sound_path = "res://audio/sfx_m249.wav"
	noise_radius = 40.0
