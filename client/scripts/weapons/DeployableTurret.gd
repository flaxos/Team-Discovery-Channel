class_name DeployableTurret
extends Node3D
## SGC Browning M2HB .50 Cal Deployable Heavy Machine Gun.
## Operates in automated sentry mode OR mounted by an operative via [E] for manual suppressing fire.

signal turret_fired(origin: Vector3, dir: Vector3)
signal player_mounted(player: Node)
signal player_dismounted(player: Node)

@export var fire_rate_rpm: float = 450.0
@export var damage: float = 52.0
@export var auto_targeting_range: float = 28.0

var fire_cooldown: float = 0.0
var current_target: Node3D = null
var mounted_player: CharacterBody3D = null

@onready var muzzle_point: Marker3D = $TurretHead/MuzzlePoint if has_node("TurretHead/MuzzlePoint") else null
@onready var turret_head: Node3D = $TurretHead if has_node("TurretHead") else null
@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_interact_entered)
		interact_area.body_exited.connect(_on_interact_exited)


func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	# If manually mounted by a player, aim head where the player is aiming
	if mounted_player != null and is_instance_valid(mounted_player):
		var p_aim: Vector3 = mounted_player.get("current_aim_target")
		if p_aim != Vector3.ZERO and turret_head != null:
			var target_head_pos := Vector3(p_aim.x, turret_head.global_position.y, p_aim.z)
			if turret_head.global_position.distance_squared_to(target_head_pos) > 0.2:
				turret_head.look_at(target_head_pos, Vector3.UP)
		return

	# Sentry mode: server authoritative target acquisition
	if not multiplayer.is_server():
		return

	_find_target()
	if current_target != null:
		var target_pos := current_target.global_position + Vector3(0, 1.0, 0)
		var aim_dir := (target_pos - global_position).normalized()

		if turret_head != null:
			turret_head.look_at(target_pos, Vector3.UP)

		if fire_cooldown <= 0.0:
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_shot(aim_dir)


func try_manual_fire(aim_dir: Vector3) -> bool:
	if fire_cooldown > 0.0:
		return false
	fire_cooldown = 60.0 / fire_rate_rpm
	_fire_shot(aim_dir)
	return true


func mount(player: CharacterBody3D) -> void:
	if mounted_player != null:
		return
	mounted_player = player
	player_mounted.emit(player)
	print("DeployableTurret: Operative %s mounted the .50 Cal Browning!" % player.name)


func dismount() -> void:
	if mounted_player != null:
		var prev := mounted_player
		mounted_player = null
		player_dismounted.emit(prev)
		print("DeployableTurret: Operative %s dismounted the .50 Cal Browning." % prev.name)


func _on_interact_entered(body: Node) -> void:
	if body is PlayerController3D and (body as PlayerController3D).is_local_authority:
		print("DeployableTurret: In range of .50 Cal. Press [E] to mount.")


func _on_interact_exited(body: Node) -> void:
	if body == mounted_player:
		dismount()


func _find_target() -> void:
	var enemies_container := get_tree().root.find_child("Enemies", true, false)
	if enemies_container == null:
		return

	var nearest: Node3D = null
	var min_dist := auto_targeting_range

	for child in enemies_container.get_children():
		var jaffa := child as JaffaAI
		if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
			var d := global_position.distance_to(jaffa.global_position)
			if d < min_dist:
				min_dist = d
				nearest = jaffa

	current_target = nearest


func _fire_shot(dir: Vector3) -> void:
	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.0, -0.8)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * auto_targeting_range)
	query.collision_mask = 1 | 4  # World and Jaffa

	var result := space.intersect_ray(query)
	var hit_pos := origin + dir * auto_targeting_range

	if not result.is_empty():
		hit_pos = result["position"]
		var hit_node := result["collider"] as Node
		if hit_node != null:
			var health := hit_node.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(damage, self, "50cal_heavy")

	turret_fired.emit(origin, dir)
	rpc("play_turret_fx", origin, hit_pos)


@rpc("call_local", "unreliable")
func play_turret_fx(origin: Vector3, hit_point: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	tracer.mesh = imm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.3, 0.95)
	tracer.material_override = mat
	get_tree().root.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(origin)
	imm.surface_add_vertex(hit_point)
	imm.surface_end()

	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)

	if ResourceLoader.exists("res://audio/sfx_m249.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_m249.wav")
		audio.max_distance = 60.0
		audio.unit_size = 12.0
		get_tree().root.add_child(audio)
		audio.global_position = origin
		audio.finished.connect(audio.queue_free)
		audio.play()
