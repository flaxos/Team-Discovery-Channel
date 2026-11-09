@tool
class_name LevelTransportBindings
extends RefCounted


static func bind_rings(layout: LevelLayout, root: Node3D) -> PackedStringArray:
	var errors := LevelLayoutValidator.validate(layout, false)
	errors.append_array(LevelLayoutValidator.validate_transports(layout, true))
	if not errors.is_empty():
		return errors
	var nodes := {}
	var endpoints := {}
	for item in layout.instances:
		for endpoint in item.transport_endpoints:
			if endpoint.kind != "rings":
				continue
			var owner := root.get_node_or_null(str(item.id))
			var anchor := (
				owner.get_node_or_null("Attachments/Interactions/" + str(endpoint.anchor))
				if owner != null
				else null
			)
			var rig := (
				owner.get_node_or_null(endpoint.node_path) as TransportRings
				if owner != null and not endpoint.node_path.is_empty()
				else null
			)
			if (
				rig == null
				or anchor == null
				or not anchor is Node3D
				or not (anchor as Node3D).transform.is_equal_approx(
					item.module.equipment_anchors[str(endpoint.anchor)]
				)
				or not anchor.is_ancestor_of(rig)
				or not rig.transform.is_equal_approx(Transform3D.IDENTITY)
			):
				errors.append(
					"Missing/misaligned shared ring scene: %s/%s" % [item.id, endpoint.id]
				)
			else:
				nodes[endpoint.id] = rig
				endpoints[endpoint.id] = endpoint
	if not errors.is_empty():
		return errors
	# Resolve every endpoint before applying anything; failure leaves all rigs intact.
	for id: Variant in nodes:
		var rig: TransportRings = nodes[id]
		var target: TransportRings = nodes[endpoints[id].target_id]
		rig.spawn_enemies_on_beam = false
		rig.paired_rings_path = rig.get_path_to(target)
		rig.paired_rings = target
	return errors
