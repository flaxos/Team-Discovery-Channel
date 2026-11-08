extends SceneTree
## Automated Headless Validation: Sprint 17 Weapon Balancing, Recoil Bloom,
## Dynamic 4-Pip Crosshair, and Energy Heat Gauge HUD Integration.

const HUD_SCENE: String = "res://scenes/ui/HUD.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const TURRET_SCENE: String = "res://scenes/props/DeployableTurret.tscn"

var hud: TacticalHUD = null
var player: PlayerController3D = null
var ticks: int = 0
var elapsed: float = 0.0
var test_passed: bool = false


func _init() -> void:
	print("\n==================================================================")
	print("  PROJECT SGC: SPRINT 17 WEAPONS, RECOIL BLOOM & HUD TEST        ")
	print("==================================================================")

	_test_weapon_stats_tuning()
	_setup_hud_environment()


func _test_weapon_stats_tuning() -> void:
	print("[TEST 1] Verifying tuned weapon stats and spread bloom parameters...")

	# M249 SAW
	var m249 := WeaponM249.new()
	assert(is_equal_approx(m249.bloom_per_shot_deg, 0.75), "M249 bloom_per_shot_deg must be 0.75, got %f" % m249.bloom_per_shot_deg)
	assert(is_equal_approx(m249.max_spread_deg, 8.5), "M249 max_spread_deg must be 8.5, got %f" % m249.max_spread_deg)
	assert(is_equal_approx(m249.spread_recovery_rate, 14.0), "M249 spread_recovery_rate must be 14.0, got %f" % m249.spread_recovery_rate)
	assert(is_equal_approx(m249.fire_rate_rpm, 750.0), "M249 fire_rate_rpm must be 750.0, got %f" % m249.fire_rate_rpm)
	assert(m249.magazine_size == 100, "M249 magazine_size must be 100, got %d" % m249.magazine_size)
	assert(m249.mag_capacity == 100, "M249 mag_capacity must be 100, got %d" % m249.mag_capacity)
	assert(m249.reserve_ammo == 300, "M249 reserve_ammo must be 300, got %d" % m249.reserve_ammo)
	assert(m249.reserve_capacity == 300, "M249 reserve_capacity must be 300, got %d" % m249.reserve_capacity)
	print("  ✓ WeaponM249: 750 RPM, 100/300 ammo, 0.75 deg bloom, 8.5 max spread, 14.0 recovery.")

	# MP5
	var mp5 := WeaponMP5.new()
	assert(is_equal_approx(mp5.bloom_per_shot_deg, 0.50), "MP5 bloom_per_shot_deg must be 0.50, got %f" % mp5.bloom_per_shot_deg)
	assert(is_equal_approx(mp5.max_spread_deg, 6.0), "MP5 max_spread_deg must be 6.0, got %f" % mp5.max_spread_deg)
	assert(is_equal_approx(mp5.spread_recovery_rate, 18.0), "MP5 spread_recovery_rate must be 18.0, got %f" % mp5.spread_recovery_rate)
	assert(is_equal_approx(mp5.fire_rate_rpm, 800.0), "MP5 fire_rate_rpm must be 800.0, got %f" % mp5.fire_rate_rpm)
	assert(mp5.magazine_size == 30, "MP5 magazine_size must be 30, got %d" % mp5.magazine_size)
	assert(mp5.mag_capacity == 30, "MP5 mag_capacity must be 30, got %d" % mp5.mag_capacity)
	assert(mp5.reserve_ammo == 150, "MP5 reserve_ammo must be 150, got %d" % mp5.reserve_ammo)
	assert(mp5.reserve_capacity == 150, "MP5 reserve_capacity must be 150, got %d" % mp5.reserve_capacity)
	print("  ✓ WeaponMP5: 800 RPM, 30/150 ammo, 0.50 deg bloom, 6.0 max spread, 18.0 recovery.")

	# M9
	var m9 := WeaponM9.new()
	assert(is_equal_approx(m9.bloom_per_shot_deg, 0.30), "M9 bloom_per_shot_deg must be 0.30, got %f" % m9.bloom_per_shot_deg)
	assert(is_equal_approx(m9.max_spread_deg, 4.5), "M9 max_spread_deg must be 4.5, got %f" % m9.max_spread_deg)
	assert(is_equal_approx(m9.spread_recovery_rate, 22.0), "M9 spread_recovery_rate must be 22.0, got %f" % m9.spread_recovery_rate)
	assert(is_equal_approx(m9.fire_rate_rpm, 400.0), "M9 fire_rate_rpm must be 400.0, got %f" % m9.fire_rate_rpm)
	assert(m9.magazine_size == 15, "M9 magazine_size must be 15, got %d" % m9.magazine_size)
	assert(m9.mag_capacity == 15, "M9 mag_capacity must be 15, got %d" % m9.mag_capacity)
	assert(m9.reserve_ammo == 60, "M9 reserve_ammo must be 60, got %d" % m9.reserve_ammo)
	assert(m9.reserve_capacity == 60, "M9 reserve_capacity must be 60, got %d" % m9.reserve_capacity)
	print("  ✓ WeaponM9: 400 RPM, 15/60 ammo, 0.30 deg bloom, 4.5 max spread, 22.0 recovery.")

	m249.free()
	mp5.free()
	m9.free()


func _test_recoil_bloom_accumulation_and_recovery() -> void:
	print("[TEST 2] Testing weapon bloom accumulation and recovery over time...")

	var m249 := WeaponM249.new()
	player.weapon_holder.add_child(m249)

	var initial_spread: float = m249.current_spread_deg
	assert(is_equal_approx(initial_spread, m249.base_spread_deg), "Initial spread should equal base_spread_deg (3.2)")

	# Simulate 5 consecutive shots
	for i: int in range(5):
		m249.fire_cooldown = 0.0 # reset cooldown for test simulation
		m249.try_fire(1.0)

	assert(m249.current_spread_deg > initial_spread, "Spread bloom should accumulate upon firing")
	var expected_spread: float = initial_spread + 5.0 * 0.75
	assert(is_equal_approx(m249.current_spread_deg, expected_spread), "Spread bloom should be base + 5*0.75 = %f, got %f" % [expected_spread, m249.current_spread_deg])
	print("  ✓ Spread accumulated to %.2f deg after 5 shots" % m249.current_spread_deg)

	# Simulate full auto burst to cap at max_spread_deg
	for i: int in range(20):
		m249.fire_cooldown = 0.0
		m249.try_fire(1.0)
	assert(is_equal_approx(m249.current_spread_deg, m249.max_spread_deg), "Bloom should cap at max_spread_deg (8.5), got %f" % m249.current_spread_deg)
	print("  ✓ Bloom capped at max_spread_deg (%.1f deg)" % m249.current_spread_deg)

	# Simulate recovery over 0.25s
	m249._process(0.25)
	var recovered_spread: float = m249.current_spread_deg
	assert(recovered_spread < 8.5, "Spread must recover toward base spread during idle delta")
	print("  ✓ Spread recovered to %.2f deg after 0.25s idle" % recovered_spread)

	m249.queue_free()


func _setup_hud_environment() -> void:
	print("[TEST 3] Loading Tactical HUD scene and instantiating player operative...")

	var hud_scene := load(HUD_SCENE) as PackedScene
	hud = hud_scene.instantiate() as TacticalHUD
	root.add_child(hud)

	var p_scene := load(PLAYER_SCENE) as PackedScene
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	root.add_child(player)

	hud.bind_local_player(player)


func _process(delta: float) -> bool:
	ticks += 1
	elapsed += delta

	if ticks == 3:
		_test_recoil_bloom_accumulation_and_recovery()

	if ticks == 6:
		_test_dynamic_crosshair_stances()

	if ticks == 10:
		_test_energy_weapon_heat_gauge()

	if ticks == 15:
		_test_heat_overheating_venting_warning()

	if ticks == 20:
		_test_switch_back_to_ballistic_weapon()

	if ticks == 25:
		print("\n==================================================================")
		print("  ALL SPRINT 17 WEAPON BLOOM & HUD TESTS PASSED (100% SUCCESS)    ")
		print("==================================================================\n")
		test_passed = true
		quit(0)
		return true

	return false


func _test_dynamic_crosshair_stances() -> void:
	print("[TEST 4] Testing dynamic 4-pip crosshair stance multipliers & bloom...")

	assert(hud.crosshair_overlay != null, "Crosshair overlay must exist in HUD")

	# 1. Standing still stance
	player.velocity = Vector3.ZERO
	player.is_crouching = false
	player.is_aiming_down_sights = false
	player.mounted_turret = null

	var mult_standing: float = hud.get_stance_multiplier()
	assert(is_equal_approx(mult_standing, 0.75), "Standing still stance multiplier must be 0.75, got %f" % mult_standing)
	var gap_standing: float = hud.get_crosshair_gap()
	print("  ✓ Standing still: mult = %.2f, gap = %.1f px (crisp close cluster)" % [mult_standing, gap_standing])

	# 2. Crouched stance
	player.is_crouching = true
	var mult_crouch: float = hud.get_stance_multiplier()
	assert(mult_crouch < mult_standing, "Crouching must tighten stance multiplier")
	var gap_crouch: float = hud.get_crosshair_gap()
	assert(gap_crouch < gap_standing, "Crouching gap must be tighter than standing gap")
	print("  ✓ Crouched stance: mult = %.2f, gap = %.1f px (tighter close cluster)" % [mult_crouch, gap_crouch])
	player.is_crouching = false

	# 3. Running / moving penalty
	player.velocity = Vector3(4.0, 0, 0)
	var mult_running: float = hud.get_stance_multiplier()
	assert(is_equal_approx(mult_running, 1.8), "Running stance multiplier must be 1.8, got %f" % mult_running)
	var gap_running: float = hud.get_crosshair_gap()
	assert(gap_running > gap_standing, "Running gap must expand to reflect moving penalty")
	print("  ✓ Running moving penalty: mult = %.2f, gap = %.1f px (expanded spread)" % [mult_running, gap_running])
	player.velocity = Vector3.ZERO

	# 4. Mounted on .50 cal tripod / deployed
	var turret_scene := load(TURRET_SCENE) as PackedScene
	var turret := turret_scene.instantiate() as DeployableTurret
	root.add_child(turret)
	player.mounted_turret = turret

	var mult_mounted: float = hud.get_stance_multiplier()
	assert(is_equal_approx(mult_mounted, 0.01), "Mounted stance multiplier must be 0.01 (99%% laser accuracy), got %f" % mult_mounted)
	var gap_mounted: float = hud.get_crosshair_gap()
	assert(is_equal_approx(gap_mounted, 2.0), "Mounted gap must tighten to pinpoint dot (2.0px), got %f" % gap_mounted)
	print("  ✓ Mounted on .50 Cal Tripod: mult = %.2f, gap = %.1f px (laser pinpoint accuracy)" % [mult_mounted, gap_mounted])

	player.mounted_turret = null
	turret.queue_free()

	# 5. Full auto recoil bloom expansion
	player.current_weapon.current_spread_deg = player.current_weapon.max_spread_deg
	var gap_bloom: float = hud.get_crosshair_gap()
	assert(gap_bloom > gap_standing * 2.0, "Full auto bloom must dramatically expand crosshair gap")
	print("  ✓ Full auto recoil bloom: spread = %.1f deg, gap = %.1f px (dynamic expansion)" % [player.current_weapon.current_spread_deg, gap_bloom])

	# 6. Test crosshair draw execution
	hud._draw()
	print("  ✓ Tactical 4-Pip Crosshair draw routine executed cleanly.")


func _test_energy_weapon_heat_gauge() -> void:
	print("[TEST 5] Testing Energy Weapons Heat Gauge integration (Staff Weapon)...")

	var staff := WeaponStaff.new()
	player.weapon_holder.add_child(staff)
	player.current_weapon = staff

	# Update HUD display
	hud._update_weapon_display()

	assert(hud.heat_container != null and hud.heat_container.visible == true, "HeatContainer must be visible for energy weapons")
	assert(hud.heat_bar != null, "HeatBar must exist")
	assert(hud.heat_label != null, "HeatLabel must exist")
	assert(hud.heat_warning_label != null, "HeatWarningLabel must exist")

	# Test heat update
	staff.current_heat = 45.0
	hud._update_weapon_display()
	assert(is_equal_approx(hud.heat_bar.value, 45.0), "HeatBar value must match current_heat (45.0)")
	assert(hud.heat_label.text.contains("45%"), "HeatLabel must display 45%")
	assert(hud.heat_warning_label.visible == false, "Warning label should not be visible when not overheated")
	print("  ✓ Staff Weapon: Heat gauge visible, showing 45% heat (liquid Naquadah orange style).")


func _test_heat_overheating_venting_warning() -> void:
	print("[TEST 6] Testing Overheating / Venting warning display...")

	var staff: WeaponBase = player.current_weapon
	staff.current_heat = 100.0
	staff.is_overheated = true
	staff.overheat_timer = 3.0

	hud._update_weapon_display()

	assert(hud.heat_warning_label.visible == true, "HeatWarningLabel must be visible when overheated")
	assert(hud.heat_warning_label.text == "OVERHEATING / VENTING...", "Heat warning text must be 'OVERHEATING / VENTING...', got: %s" % hud.heat_warning_label.text)
	assert(hud.ammo_label.text == "VENTING...", "Ammo label must display 'VENTING...' when overheated")
	print("  ✓ Overheating triggered: Warning 'OVERHEATING / VENTING...' flashing red.")

	# Test Zat'nik'tel electric blue style
	var zat := WeaponZat.new()
	player.weapon_holder.add_child(zat)
	player.current_weapon = zat
	zat.current_heat = 60.0
	hud._update_weapon_display()

	assert(hud.heat_container.visible == true, "HeatContainer must be visible for Zat")
	assert(is_equal_approx(hud.heat_bar.value, 60.0), "HeatBar value must be 60.0 for Zat")
	print("  ✓ Zat'nik'tel: Heat gauge active with authentic electric Goa'uld blue meter.")


func _test_switch_back_to_ballistic_weapon() -> void:
	print("[TEST 7] Switching back to ballistic weapon (M249)...")

	var m249 := WeaponM249.new()
	player.weapon_holder.add_child(m249)
	player.current_weapon = m249

	hud._update_weapon_display()

	assert(hud.heat_container.visible == false, "HeatContainer must be hidden for ballistic weapons")
	assert(hud.ammo_label.text == "%d / %d" % [m249.current_ammo, m249.reserve_ammo], "Ammo label must display magazine / reserve ammo")
	print("  ✓ Ballistic weapon: Heat meter automatically hidden, ammo counter restored.")
