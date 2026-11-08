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
signal downed()
signal revived()
signal bleedout_tick(seconds_left: float)

@export var max_health: float = 100.0
@export var can_be_downed: bool = false

var current_health: float = 100.0
var is_dead: bool = false
var is_downed: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0
var bleedout_timer: float = 0.0
const MAX_BLEEDOUT_TIME: float = 20.0

var zat_hits: int = 0
var zat_window_timer: float = 0.0
const ZAT_WINDOW_DURATION: float = 8.0
const ZAT_STUN_DURATION: float = 20.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	# Bleedout countdown when downed
	if is_downed and not is_dead:
		bleedout_timer -= delta
		bleedout_tick.emit(maxf(0.0, bleedout_timer))
		if bleedout_timer <= 0.0:
			is_downed = false
			is_dead = true
			died.emit()
			return

	# Stun countdown
	if is_stunned and not is_dead and not is_downed:
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

	var final_dmg := amount
	var parent_node := get_parent()
	if parent_node is PlayerController3D:
		var pc := parent_node as PlayerController3D
		if pc.mounted_turret != null:
			final_dmg *= 0.35  # 65% damage mitigation from .50 cal heavy armor gun shield
		elif pc.is_crouching:
			final_dmg *= 0.35  # 65% damage mitigation while crouched behind cover
	elif parent_node is SGCAirmanAI:
		var airman := parent_node as SGCAirmanAI
		if airman.mounted_turret != null:
			final_dmg *= 0.35  # 65% damage mitigation from .50 cal heavy armor gun shield
		elif airman.is_crouching or airman.is_in_cover:
			final_dmg *= 0.35  # 65% damage mitigation while crouched behind cover

	current_health = maxf(0.0, current_health - final_dmg)
	damage_taken.emit(final_dmg, source, damage_type)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0 and not is_dead:
		if can_be_downed and not is_downed and damage_type != "kawoosh_vortex" and damage_type != "zat_vaporize" and damage_type != "zat_kill":
			is_downed = true
			is_stunned = false
			bleedout_timer = MAX_BLEEDOUT_TIME
			current_health = 0.0
			downed.emit()
		elif not is_downed or damage_type == "zat_kill" or damage_type == "kawoosh_vortex":
			is_downed = false
			is_dead = true
			is_stunned = false
			died.emit()


## Revives a downed operative with 40% maximum health
func revive(_reviver: Node = null) -> void:
	if not is_downed or is_dead:
		return
	is_downed = false
	bleedout_timer = 0.0
	current_health = max_health * 0.40
	health_changed.emit(current_health, max_health)
	revived.emit()


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
			# 3rd shot: Vaporization
			zat_hits = 3
			is_dead = true
			is_downed = false
			vaporized.emit()
	else:
		# Already dead: 3rd shot vaporizes
		zat_hits = 3
		vaporized.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
