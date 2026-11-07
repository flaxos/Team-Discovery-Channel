class_name PlasmaBolt
extends Area3D
## Ma'Tok Staff Weapon liquid Naquadah plasma projectile.
## High-energy golden plasma bolt traveling at 40 m/s with impact blast.

signal exploded(impact_point: Vector3)

@export var speed: float = 40.0
@export var damage: float = 45.0
@export var max_lifetime_s: float = 4.0
@export var is_enemy_bolt: bool = true

var shooter: Node = null
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime_s:
		queue_free()
		return

	global_position += direction * speed * delta


func initialize(p_origin: Vector3, p_direction: Vector3, p_shooter: Node, p_is_enemy: bool = true) -> void:
	global_position = p_origin
	direction = p_direction.normalized()
	shooter = p_shooter
	is_enemy_bolt = p_is_enemy

	# Orient mesh towards flight direction
	if is_inside_tree() and direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

	# Set collision masks based on whether bolt was fired by Jaffa or Player
	collision_layer = 8  # Layer 4 (projectiles)
	if is_enemy_bolt:
		collision_mask = 1 | 2  # World (1) and Players (2)
	else:
		collision_mask = 1 | 4  # World (1) and Jaffa (3)

	_play_fire_sound()


func _play_fire_sound() -> void:
	if ResourceLoader.exists("res://audio/sfx_staff_fire.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_staff_fire.wav")
		audio.max_distance = 60.0
		audio.unit_size = 12.0
		add_child(audio)
		audio.play()


func _on_body_entered(body: Node) -> void:
	if is_instance_valid(shooter) and body == shooter:
		return

	# Allow high-energy plasma bolts to penetrate observation glass windows
	if body != null and (body.name.contains("Glass") or body.name.contains("Overlook")):
		return

	# Apply damage if target has HealthComponent
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		var src: Node = shooter if is_instance_valid(shooter) else null
		health.take_damage(damage, src, "plasma")

	_detonate(global_position)


func _on_area_entered(_area: Area3D) -> void:
	# Avoid friendly area collisions
	pass


func _detonate(impact_point: Vector3) -> void:
	exploded.emit(impact_point)
	# Quick impact spark mesh
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	spark.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.1, 1.0)
	spark.material_override = mat

	if get_parent() != null:
		get_parent().add_child(spark)
		spark.global_position = impact_point

	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3(1.8, 1.8, 1.8), 0.08)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(spark.queue_free)

	queue_free()
