class_name WeaponP90
extends WeaponBase
## FN P90 Personal Defense Weapon.
## 50-round horizontal magazine, 5.7x28mm armor piercing, agile movement.


func _init() -> void:
	weapon_id = "p90"
	display_name = "FN P90 Tactical PDW"
	damage = 22.0
	fire_rate_rpm = 900.0
	mag_capacity = 50
	reserve_capacity = 300
	reload_time_s = 1.9
	base_spread_deg = 1.8
	max_range_m = 45.0
