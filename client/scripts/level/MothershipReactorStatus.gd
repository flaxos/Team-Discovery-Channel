class_name MothershipReactorStatus
extends MeshInstance3D
## Updates reactor core visual materials when the sabotage/power diversion event fires.
## In an authoring preview or without mission events, the core displays powered state.

@export var event_id: StringName = &"sabotage_releases_bridge"
@export var shutdown_material: Material


func _ready() -> void:
	_bind_mission.call_deferred()


func _bind_mission() -> void:
	var world := MissionWorld.of(self)
	if world == null:
		return
	var events := world.get_node_or_null(^"Events") as MissionEvents
	if events == null:
		return
	events.trigger_fired.connect(_on_trigger_fired)
	if events.fired.has(str(event_id)) or events.fired.has("sabotage_releases_bridge"):
		_on_trigger_fired(event_id)


func _on_trigger_fired(id: StringName) -> void:
	if (id == event_id or id == &"sabotage_releases_bridge" or id == &"sabotage_hyperdrive") and shutdown_material != null:
		material_override = shutdown_material
