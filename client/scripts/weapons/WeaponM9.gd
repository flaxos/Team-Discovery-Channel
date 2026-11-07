class_name WeaponM9
extends WeaponBase
## Beretta 92FS / M9 9mm SGC Standard Issue Sidearm.
## 15-round magazine, rapid semi-automatic tactical backup.


func _init() -> void:
	weapon_id = "m9"
	display_name = "Beretta M9 9mm Pistol"
	damage = 28.0
	fire_rate_rpm = 380.0
	mag_capacity = 15
	reserve_capacity = 90
	reload_time_s = 1.3
	base_spread_deg = 1.6
	max_range_m = 35.0
