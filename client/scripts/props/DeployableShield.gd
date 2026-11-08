class_name DeployableShield
extends StaticBody3D
## Tactical Deployable Ballistic Shield.
## Stocked at the Sublevel 28 Armory. Can be placed anywhere to establish an instant
## fortified redoubt (600 HP) with full auto-cover and peek-to-shoot compatibility.

signal shield_deployed(shield: DeployableShield)
signal shield_damaged(current_hp: float, max_hp: float)
signal shield_destroyed(shield: DeployableShield)

@export var max_durability: float = 600.0
@export var is_deployed: bool = true

@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var shield_mesh: Node3D = $Visuals/ShieldMesh if has_node("Visuals/ShieldMesh") else null


func _ready() -> void:
	add_to_group("cover")
	add_to_group("deployable_shield")

	if health_component != null:
		health_component.max_health = max_durability
		health_component.current_health = max_durability
		health_component.can_be_downed = false
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_destroyed)

	shield_deployed.emit(self)


func _on_damage_taken(amount: float, _source: Node, _type: String) -> void:
	if health_component != null:
		shield_damaged.emit(health_component.current_health, health_component.max_health)

	# Slight hit reaction twitch
	if shield_mesh != null:
		var tween := create_tween()
		tween.tween_property(shield_mesh, "position:z", 0.04, 0.04)
		tween.tween_property(shield_mesh, "position:z", 0.0, 0.04)


func _on_destroyed() -> void:
	shield_destroyed.emit(self)
	collision_layer = 0
	remove_from_group("cover")

	# Collapse & disintegrate
	var tween := create_tween()
	if shield_mesh != null:
		tween.tween_property(shield_mesh, "scale", Vector3(1.0, 0.05, 1.0), 0.2)
		tween.tween_property(shield_mesh, "position:y", -0.4, 0.15)
	tween.tween_callback(queue_free)
