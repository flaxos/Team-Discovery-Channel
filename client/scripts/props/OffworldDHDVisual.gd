extends Node3D
## Feed the offworld deck lamp from the existing dialer and replicated gate state.

@onready var dialer := get_parent() as DHDDialer
@onready var dome := $Deck/Dome as MeshInstance3D
var finish: StandardMaterial3D
var was_dialing := false
var was_open := false


func _ready() -> void:
	finish = dome.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	dome.material_override = finish


func _process(_delta: float) -> void:
	var gate := dialer.target_stargate
	var opened := is_instance_valid(gate) and gate.current_state == StargateRing.GateState.ACTIVE
	var dialing := dialer.current_phase in [DHDDialer.DialPhase.CHEVRONS, DHDDialer.DialPhase.GDO_AUTH]
	dialing = dialing or (is_instance_valid(gate) and gate.current_state in [
		StargateRing.GateState.DIALING, StargateRing.GateState.KAWOOSH
	])
	if opened == was_open and dialing == was_dialing:
		return
	was_open = opened
	was_dialing = dialing
	finish.emission_energy_multiplier = 2.1 if opened else (0.85 if dialing else 0.24)
