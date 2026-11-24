extends Node3D
## SGC-only dressing. Gate and wave snapshots remain the owners of gate and iris state.

@onready var gate := get_parent() as StargateRing
@onready var servo := get_node("../../IrisServoHousing") as IrisServoHousing
@onready var iris := $IrisFace as MeshInstance3D


func _ready() -> void:
	# The gate attaches AP-1g in its own _ready, after this child enters.
	_update_rim.call_deferred()
	_update_iris()


func _update_rim() -> void:
	# The fallback torus already fills this envelope.
	$Rim.visible = gate.has_node("CommunityVisual")


func _process(_delta: float) -> void:
	# Snapshots can arrive in either order. Derive presentation from the current pair.
	_update_iris()


func _update_iris() -> void:
	iris.visible = servo.is_repaired \
		and gate.direction == StargateRing.GateDirection.INBOUND \
		and gate.current_state == StargateRing.GateState.ACTIVE
