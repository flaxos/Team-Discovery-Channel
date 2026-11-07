class_name HealthComponent
extends Node
## Health, damage, and canonical Stargate Zat'nik'tel status component.
## Canonical Zat rule: 1st shot = 20s stun lock, 2nd shot = kill, 3rd shot = complete vaporization.

signal health_changed(current: float, max_health: float)
signal damage_taken(amount: float, source: Node, damage_type: String)
signal died()
signal stunned(duration: float)
signal recovered_from_stun()
signal vaporized()

@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0

var zat_hits: int = 0
var zat_window_timer: float = 0.0
const ZAT_WINDOW_DURATION: float = 25.0
const ZAT_STUN_DURATION: float = 20.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	# Stun countdown
	if is_stunned and not is_dead:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
			recovered_from_stun.emit()

	# Zat hit window decay
	if zat_hits > 0 and not is_dead:
		zat_window_timer -= delta
		if zat_window_timer <= 0.0:
			zat_hits = 0


## Applies damage with source and damage type tagging.
func take_damage(amount: float, source: Node = null, damage_type: String = "bullet") -> void:
	if is_dead:
		return
	current_health = maxf(0.0, current_health - amount)
	damage_taken.emit(amount, source, damage_type)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0 and not is_dead:
		is_dead = true
		is_stunned = false
		died.emit()


## Canonical Stargate Zat'nik'tel hit logic:
## 1st shot: Stuns target for 20s (electric arc, weapon dropped).
## 2nd shot: Fatal electrical shock (drops target dead).
## 3rd shot: Disintegrates / vaporizes target completely (mesh dissolves).
func apply_zat_shot(source: Node = null) -> void:
	zat_window_timer = ZAT_WINDOW_DURATION

	if not is_dead:
		if zat_hits == 0:
			# 1st shot: Stun
			zat_hits = 1
			is_stunned = true
			stun_timer = ZAT_STUN_DURATION
			damage_taken.emit(10.0, source, "zat_stun")
			stunned.emit(ZAT_STUN_DURATION)
		elif zat_hits == 1:
			# 2nd shot: Kill
			zat_hits = 2
			take_damage(current_health + 50.0, source, "zat_kill")
	else:
		# Already dead: 3rd shot vaporizes
		zat_hits = 3
		vaporized.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
