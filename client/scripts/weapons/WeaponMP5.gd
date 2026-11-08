class_name WeaponMP5
extends WeaponBase
## Heckler & Koch MP5 Submachine Gun (Tech Specialist / Carter).
## Suppressed, fast handling, tight spread, 30-round 9x19mm magazine.


func _init() -> void:
	weapon_id = "mp5"
	display_name = "HK MP5-SD Tactical SMG"
	damage = 20.0
	fire_rate_rpm = 800.0
	mag_capacity = 30
	magazine_size = 30
	reserve_capacity = 150
	reserve_ammo = 150
	reload_time_s = 1.7
	base_spread_deg = 1.5
	current_spread_deg = 1.5
	bloom_per_shot_deg = 0.50
	max_spread_deg = 6.0
	spread_recovery_rate = 18.0
	max_range_m = 40.0
