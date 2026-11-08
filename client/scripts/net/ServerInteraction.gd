extends RefCounted
## Shared validation for server-owned stations; callers send identity, never results.
static func resolve(station: Node3D, player_path: NodePath, radius: float = 3.5) -> PlayerController3D:
	if not station.multiplayer.is_server():
		return null
	var player := station.get_node_or_null(player_path) as PlayerController3D
	var sender: int = station.multiplayer.get_remote_sender_id()
	if player == null or (sender != 0 and player.get_multiplayer_authority() != sender):
		return null
	if sender != 0 and player.global_position.distance_to(station.global_position) > radius:
		return null
	var health: HealthComponent = player.health_component
	if health != null and (health.is_dead or health.is_downed or health.is_stunned):
		return null
	return player
