class_name WeaponM9
extends WeaponBase
## Beretta 92FS / M9 9mm SGC Standard Issue Sidearm.
## 15-round magazine, rapid semi-automatic tactical backup.


func _init() -> void:
	weapon_id = "m9"
	display_name = "Beretta M9 9mm Pistol"
	damage = 28.0
	fire_rate_rpm = 400.0
	mag_capacity = 15
	magazine_size = 15
	reserve_capacity = 60
	reserve_ammo = 60
	reload_time_s = 1.3
	base_spread_deg = 1.6
	current_spread_deg = 1.6
	bloom_per_shot_deg = 0.30
	max_spread_deg = 4.5
	spread_recovery_rate = 22.0
	max_range_m = 35.0
	noise_radius = 25.0
