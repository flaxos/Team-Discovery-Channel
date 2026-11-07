class_name JaffaAI
extends CharacterBody3D
## Goa'uld Serpent / Horus Guard Enemy AI.
## Advances down the Stargate ramp, takes tactical firing positions,
## discharges liquid Naquadah plasma bolts, and enforces canonical Zat status effects.

signal jaffa_died(killer: Node)
signal jaffa_vaporized()

enum State { ADVANCE, COMBAT, MELEE, STUNNED, DEAD }

@export var is_shock_guard: bool = false
@export var move_speed: float = 4.2
@export var combat_range: float = 22.0
@export var melee_range: float = 2.2
@export var plasma_damage: float = 45.0
@export var fire_interval_s: float = 2.8
@export var staff_accuracy_spread_deg: float = 3.5

var current_state: State = State.ADVANCE
var current_target: Node3D = null
var fire_timer: float = 0.0
var melee_cooldown: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var health_component: HealthComponent = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var muzzle_point: Marker3D = $StaffMount/MuzzlePoint if has_node("StaffMount/MuzzlePoint") else null
@onready var stun_fx: Node3D = $Visuals/StunFX if has_node("Visuals/StunFX") else null
@onready var body_mesh: MeshInstance3D = $Visuals/ArmorMesh if has_node("Visuals/ArmorMesh") else null


func _ready() -> void:
	# Server is authoritative over AI logic
	set_multiplayer_authority(1)

	if is_shock_guard:
		if health_component != null:
			health_component.max_health = 140.0
			health_component.current_health = 140.0
		move_speed = 4.8
		plasma_damage = 42.0
		fire_interval_s = 1.4

	health_component.died.connect(_on_died)
	health_component.stunned.connect(_on_stunned)
	health_component.recovered_from_stun.connect(_on_recovered_from_stun)
	health_component.vaporized.connect(_on_vaporized)
	health_component.damage_taken.connect(_on_damage_taken)

	# Randomize initial fire offset so multiple Jaffa don't shoot in unison
	fire_timer = randf_range(0.5, fire_interval_s)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Only server executes state machine and movement decisions
	if not multiplayer.is_server():
		move_and_slide()
		return

	if current_state == State.DEAD or current_state == State.STUNNED:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	_find_nearest_target()

	if current_target == null:
		# Advance towards defensive zone center if no targets found
		_advance_towards(Vector3(0, 0, 6), delta)
		move_and_slide()
		return

	var dist := global_position.distance_to(current_target.global_position)

	# Look towards target on horizontal plane
	var look_dir := (current_target.global_position - global_position)
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.01:
		rotation.y = atan2(-look_dir.x, -look_dir.z)

	# State evaluations
	if dist <= melee_range:
		current_state = State.MELEE
		_process_melee(delta)
	elif dist <= combat_range and _has_line_of_sight(current_target):
		current_state = State.COMBAT
		_process_combat(delta, dist)
	else:
		current_state = State.ADVANCE
		_advance_towards(current_target.global_position, delta)

	move_and_slide()


func _find_nearest_target() -> void:
	# Find closest active SGC operative
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container == null:
		return

	var closest_player: Node3D = null
	var min_dist: float = 999999.0

	for child in players_container.get_children():
		var player := child as PlayerController3D
		if player != null and player.health_component != null and not player.health_component.is_dead:
			var d := global_position.distance_to(player.global_position)
			if d < min_dist:
				min_dist = d
				closest_player = player

	current_target = closest_player


func _has_line_of_sight(target: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.4, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var exclude_list: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude_list.append((target as CollisionObject3D).get_rid())

	for iter in range(3):
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1  # Blocked only by World walls/barricades
		query.exclude = exclude_list
		var result := space.intersect_ray(query)
		if result.is_empty():
			return true
		var col: Node = result.get("collider") as Node
		if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
			if result.has("rid"):
				exclude_list.append(result["rid"])
			continue
		return false
	return true


func _advance_towards(target_pos: Vector3, delta: float) -> void:
	var move_dest := target_pos

	# Multi-Level Pathfinding: If target is on Sublevel 27 (Y >= 4.5) and Jaffa is on Sublevel 28 (Y < 4.5)
	if target_pos.y >= 4.5 and global_position.y < 4.5:
		var stairs_landing := Vector3(-5.0, 1.0, 11.0)
		var dist_to_landing := Vector2(global_position.x - stairs_landing.x, global_position.z - stairs_landing.z).length()
		if dist_to_landing > 1.5:
			# Advance toward the Spiral Staircase base in the Control Room
			move_dest = stairs_landing
		else:
			# Ascend the helical spiral stairs toward Level 27
			velocity.y = 3.5
			move_dest = Vector3(-5.0, 5.5, 11.0)

	var to_target := (move_dest - global_position)
	to_target.y = 0.0
	var dir := to_target.normalized()

	velocity.x = move_toward(velocity.x, dir.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, 20.0 * delta)


func _process_combat(delta: float, dist: float) -> void:
	# Continue advancing down the ramp while in long-range combat (> 10m)
	if dist > 10.0:
		_advance_towards(current_target.global_position, delta)
	else:
		# Tactical stop-and-shoot when holding position at mid-range
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval_s + randf_range(-0.3, 0.4)
		_fire_staff_blast()


func _fire_staff_blast() -> void:
	if current_target == null:
		return

	_dispatch_single_plasma_bolt()

	# Jaffa Shock Guard rapid double-burst logic (fires 2nd bolt after 0.18s)
	if is_shock_guard:
		var burst_timer := get_tree().create_timer(0.18)
		burst_timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and is_inside_tree() and current_state != State.DEAD and current_state != State.STUNNED and current_target != null:
				_dispatch_single_plasma_bolt()
		)


func _dispatch_single_plasma_bolt() -> void:
	if current_target == null:
		return

	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.2, -0.6)
	var target_chest := current_target.global_position + Vector3(0, 1.0, 0)
	var base_dir := (target_chest - origin).normalized()

	# Spread inaccuracy cone
	var spread_rad := deg_to_rad(staff_accuracy_spread_deg)
	var random_yaw := randf_range(-spread_rad, spread_rad)
	var dir := base_dir.rotated(Vector3.UP, random_yaw).normalized()

	# Instantiate plasma bolt across server
	var bolt_scene := load("res://scenes/entities/PlasmaBolt.tscn") as PackedScene
	if bolt_scene != null:
		var bolt := bolt_scene.instantiate() as PlasmaBolt
		bolt.damage = plasma_damage
		get_parent().add_child(bolt)
		bolt.initialize(origin, dir, self, true)

	# Visual muzzle burst RPC
	rpc("play_staff_fire_fx", origin)


func _on_damage_taken(_amount: float, _source: Node, _damage_type: String) -> void:
	if is_shock_guard and current_state != State.DEAD:
		rpc("play_armor_spark_fx", global_position + Vector3(0, 1.2, 0))


@rpc("call_local", "unreliable")
func play_armor_spark_fx(pos: Vector3) -> void:
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.85, 0.4)
	spark.light_energy = 5.0
	spark.omni_range = 2.5
	get_tree().root.add_child(spark)
	spark.global_position = pos

	var tween := spark.create_tween()
	tween.tween_property(spark, "light_energy", 0.0, 0.1)
	tween.tween_callback(spark.queue_free)


func _process_melee(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	melee_cooldown -= delta
	if melee_cooldown <= 0.0 and current_target != null:
		melee_cooldown = 1.6
		var target_health := current_target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(35.0, self, "melee_strike")
			print("Jaffa guard struck operative in melee!")


@rpc("call_local", "unreliable")
func play_staff_fire_fx(origin_pos: Vector3) -> void:
	# Orange muzzle burst light
	var burst := OmniLight3D.new()
	burst.light_color = Color(1.0, 0.5, 0.1)
	burst.light_energy = 4.0
	burst.omni_range = 3.0
	get_tree().root.add_child(burst)
	burst.global_position = origin_pos

	var tween := burst.create_tween()
	tween.tween_property(burst, "light_energy", 0.0, 0.09)
	tween.tween_callback(burst.queue_free)


func _on_stunned(duration: float) -> void:
	current_state = State.STUNNED
	if stun_fx != null:
		stun_fx.visible = true
	print("Jaffa Guard incapacitated by Zat'nik'tel stun for %.1f s." % duration)


func _on_recovered_from_stun() -> void:
	if current_state == State.STUNNED:
		current_state = State.ADVANCE
		if stun_fx != null:
			stun_fx.visible = false
		print("Jaffa Guard recovered from Zat stun.")


func _on_died() -> void:
	current_state = State.DEAD
	collision_layer = 0  # No longer blocks bullets or players
	if stun_fx != null:
		stun_fx.visible = false

	# Collapse animation (tilt mesh backwards)
	if body_mesh != null:
		var tween := create_tween()
		tween.tween_property(body_mesh, "rotation:x", deg_to_rad(-85.0), 0.35)
		tween.parallel().tween_property(body_mesh, "position:y", 0.2, 0.35)

	jaffa_died.emit(self)
	print("Jaffa Guard eliminated.")


func _on_vaporized() -> void:
	jaffa_vaporized.emit()
	print("Jaffa Guard corpse vaporized by Zat'nik'tel 3rd shot!")

	# Disintegration flash
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.2, 0.6, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	get_tree().root.add_child(flash)
	flash.global_position = global_position + Vector3(0, 0.5, 0)

	var tween := create_tween()
	if body_mesh != null:
		tween.tween_property(body_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tween.tween_callback(queue_free)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.25)
	flash_tween.tween_callback(flash.queue_free)
