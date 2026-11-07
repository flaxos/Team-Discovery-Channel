class_name WeaponM249
extends WeaponBase
## M249 SAW Light Machine Gun (SG-3 Heavy Support Marine).
## 100-round drum, heavy moving recoil penalty, stabilized when crouched / braced on tripod.


func _init() -> void:
	weapon_id = "m249"
	display_name = "M249 SAW Squad Automatic Weapon"
	damage = 34.0
	fire_rate_rpm = 800.0
	mag_capacity = 100
	reserve_capacity = 400
	reload_time_s = 3.6
	base_spread_deg = 3.2
	max_range_m = 60.0
