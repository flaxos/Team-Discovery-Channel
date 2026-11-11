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
var is_vaporized: bool = false
var _revision: int = 0
var _last_revision: int = -1
var _snapshot_timer: float = 0.0
## Server only: peers whose copy of this actor exists and has asked for its state.
var replica_peers: Dictionary = {}
var is_downed: bool = false
## Set once the mission result is final: no further damage, bleed-out or stun changes.
var frozen: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0
var bleedout_timer: float = 0.0
const MAX_BLEEDOUT_TIME: float = 20.0

var zat_hits: int = 0
var zat_window_timer: float = 0.0
const ZAT_WINDOW_DURATION: float = 8.0
const ZAT_STUN_DURATION: float = 20.0


func _enter_tree() -> void:
	# Movement can belong to an operative's peer; gameplay health always belongs to the server.
	set_multiplayer_authority(1)


func _ready() -> void:
	current_health = max_health
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_health_snapshot.rpc_id(1)


func _process(delta: float) -> void:
	if not _can_mutate() or frozen:
		return
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0 and (is_downed or is_stunned):
		_snapshot_timer = 0.25
		_publish_state()
	# Bleedout countdown when downed
	if is_downed and not is_dead:
		bleedout_timer -= delta
		bleedout_tick.emit(maxf(0.0, bleedout_timer))
		if bleedout_timer <= 0.0:
			is_downed = false
			is_dead = true
			died.emit()
			_publish_state()
			return

	# Stun countdown
	if is_stunned and not is_dead and not is_downed:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
			recovered_from_stun.emit()
			_publish_state()

	# Zat hit window decay
	if zat_hits > 0 and not is_dead:
		zat_window_timer -= delta
		if zat_window_timer <= 0.0:
			zat_hits = 0


## Applies damage with source and damage type tagging.
func take_damage(amount: float, source: Node = null, damage_type: String = "bullet") -> void:
	if not _can_mutate() or frozen or not is_finite(amount) or amount <= 0.0 or is_dead:
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

	if damage_type in ["zat_kill", "zat_vaporize", "kawoosh_vortex"]:
		final_dmg = amount
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

	_publish_state("damage", final_dmg, source)

## Revives a downed operative with 40% maximum health
func revive(_reviver: Node = null) -> void:
	if not _can_mutate() or not is_downed or is_dead:
		return
	is_downed = false
	bleedout_timer = 0.0
	current_health = max_health * 0.40
	health_changed.emit(current_health, max_health)
	revived.emit()
	_publish_state()


## Canonical Stargate Zat'nik'tel hit logic:
## 1st shot: Stuns target for 20s (electric arc, weapon dropped).
## 2nd shot: Fatal electrical shock (drops target dead).
## 3rd shot: Disintegrates / vaporizes target completely (mesh dissolves).
func apply_zat_shot(source: Node = null) -> void:
	if not _can_mutate() or frozen or is_vaporized:
		return
	zat_window_timer = ZAT_WINDOW_DURATION

	if not is_dead:
		if zat_hits == 0:
			# 1st shot: Stun
			zat_hits = 1
			is_stunned = true
			stun_timer = ZAT_STUN_DURATION
			damage_taken.emit(10.0, source, "zat_stun")
			stunned.emit(ZAT_STUN_DURATION)
			_publish_state("zat_stun", 10.0, source)
		elif zat_hits == 1:
			# 2nd shot: Kill
			zat_hits = 2
			take_damage(current_health + 50.0, source, "zat_kill")
		else:
			# 3rd shot: Vaporization
			zat_hits = 3
			is_dead = true
			is_downed = false
			is_vaporized = true
			vaporized.emit()
			_publish_state()
	else:
		# Already dead: 3rd shot vaporizes
		zat_hits = 3
		is_vaporized = true
		vaporized.emit()
		_publish_state()


func heal(amount: float) -> void:
	if not _can_mutate() or not is_finite(amount) or amount <= 0.0 or is_dead:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

	_publish_state()


func _can_mutate() -> bool:
	return not is_inside_tree() or not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _state() -> Dictionary:
	return {"revision": _revision, "health": current_health, "maximum": max_health,
		"dead": is_dead, "downed": is_downed, "stunned": is_stunned, "vaporized": is_vaporized,
		"stun_timer": stun_timer, "bleedout_timer": bleedout_timer, "zat_hits": zat_hits,
		"zat_window": zat_window_timer}


func _publish_state(event: String = "", amount: float = 0.0, source: Node = null) -> void:
	_revision += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var source_path: NodePath = get_path_to(source) if is_instance_valid(source) and source.is_inside_tree() else NodePath()
		SGCNetworkManager.mission_rpc(
			self, &"sync_health_state", [_state(), event, amount, source_path], self
		)


@rpc("any_peer", "call_remote", "reliable")
func request_health_snapshot() -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		if sender in multiplayer.get_peers():
			replica_peers[sender] = true
			sync_health_state.rpc_id(sender, _state(), "", 0.0, NodePath())


@rpc("authority", "call_remote", "reliable")
func sync_health_state(state: Dictionary, event: String, amount: float, source_path: NodePath) -> void:
	var revision: int = state.get("revision", -1)
	if revision <= _last_revision:
		return
	_last_revision = revision
	var was_dead: bool = is_dead
	var was_downed: bool = is_downed
	var was_stunned: bool = is_stunned
	var was_vaporized: bool = is_vaporized
	current_health = state.health
	max_health = state.maximum
	is_dead = state.dead
	is_downed = state.downed
	is_stunned = state.stunned
	is_vaporized = state.vaporized
	stun_timer = state.stun_timer
	bleedout_timer = state.bleedout_timer
	zat_hits = state.zat_hits
	zat_window_timer = state.zat_window
	health_changed.emit(current_health, max_health)
	if event in ["damage", "zat_stun"]:
		var source: Node = get_node_or_null(source_path) if not source_path.is_empty() else null
		damage_taken.emit(amount, source, "zat_stun" if event == "zat_stun" else "replicated")
	if is_downed and not was_downed:
		downed.emit()
	if was_downed and not is_downed and not is_dead:
		revived.emit()
	if is_stunned and not was_stunned:
		stunned.emit(stun_timer)
	if was_stunned and not is_stunned and not is_dead and not is_downed:
		recovered_from_stun.emit()
	if is_dead and not was_dead:
		died.emit()
	if is_vaporized and not was_vaporized:
		vaporized.emit()
	if is_downed:
		bleedout_tick.emit(bleedout_timer)
