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
	reserve_capacity = 240
	reload_time_s = 1.7
	base_spread_deg = 1.5
	max_range_m = 40.0
