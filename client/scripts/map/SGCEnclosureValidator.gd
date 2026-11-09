class_name SGCEnclosureValidator
extends RefCounted
## Inspect the built indoor shell, not just the connectivity graph.
## Shared room/flight volumes are interior; every other boundary needs physical closure.
const WALL_STEP := 0.25
const PANEL_STEP := 0.5
const PROBE := 0.4
var map: SGCMap
var volumes: Array[AABB] = []
var errors := PackedStringArray()
var failed_faces: Dictionary = {}


func validate(target: SGCMap) -> PackedStringArray:
	map = target
	volumes = map.definition.enclosure_volumes()
	errors.clear()
	failed_faces.clear()
	var labels: Array[String] = []
	for r in map.definition.regions:
		labels.append(str(r.id))
	for c in map.definition.connections:
		if c.kind in ["stairs", "spiral"]:
			labels.append(str(c.id) + "/shaft")
	labels.append("LIFT_SHAFT")
	for index in range(volumes.size()):
		var bounds := volumes[index]
		var label := labels[index]
		for axis in range(3):
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var step := PANEL_STEP if axis == 1 else WALL_STEP
			var count_u := ceili(bounds.size[u] / step)
			var count_v := ceili(bounds.size[v] / step)
			for sign_value: float in [-1.0, 1.0]:
				var normal := Vector3.ZERO
				normal[axis] = sign_value
				for i in range(count_u):
					for j in range(count_v):
						var at := bounds.get_center()
						at[axis] = bounds.position[axis] if sign_value < 0 else bounds.end[axis]
						at[u] = bounds.position[u] + (i + 0.5) * bounds.size[u] / count_u
						at[v] = bounds.position[v] + (j + 0.5) * bounds.size[v] / count_v
						_probe(label + "/face%d_%s" % [axis, sign_value], at, normal)
	return errors


func _probe(label: String, at: Vector3, normal: Vector3) -> void:
	if failed_faces.has(label) or _interior(at + normal * 0.01):
		return
	var hit := map.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at - normal * PROBE, at + normal * PROBE, 129)
	)
	if hit.is_empty():
		failed_faces[label] = true
		errors.append("Exposed void: %s at %s facing %s" % [label, at, normal])


func _interior(p: Vector3) -> bool:
	for volume in volumes:
		if volume.has_point(p):
			return true
	return false
