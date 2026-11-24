extends RefCounted

const CONTAINER := "FieldKitDeployments"


static func configure(prop: Node3D, state: Array[String], streamed: Array[String] = []) -> void:
	var sync := prop.get_node_or_null("FieldKitSync") as MultiplayerSynchronizer
	if sync == null:
		return
	# Only the deployment spawner creates this node on remote peers.
	if prop.get_parent().name != CONTAINER:
		sync.public_visibility = false
		return
	var config := SceneReplicationConfig.new()
	var transform_path := NodePath(".:transform")
	config.add_property(transform_path)
	config.property_set_spawn(transform_path, true)
	config.property_set_replication_mode(transform_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS \
		if prop is RigidBody3D else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	for property: String in state + streamed:
		var path := NodePath(".:" + property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS \
			if property in streamed else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	var net := prop.get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.configure_mission_sync(sync)


static func is_replica(prop: Node) -> bool:
	return not prop.multiplayer.is_server() and prop.get_parent().name == CONTAINER
