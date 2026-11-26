extends MeshInstance3D
## Reads the existing mission release on the host and on peers receiving its snapshot.
## In an authoring preview or a mission without that event, the light stays powered.
const SHUTDOWN_EVENT := &"generator_releases_command"
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
	if events.fired.has(str(SHUTDOWN_EVENT)):
		_on_trigger_fired(SHUTDOWN_EVENT)


func _on_trigger_fired(id: StringName) -> void:
	if id == SHUTDOWN_EVENT:
		material_override = shutdown_material
