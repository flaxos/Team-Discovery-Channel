extends MainGameCoordinator
## Test-only load barrier: keep polling ENet while production gameplay nodes do not exist.
var before_load: Callable


func _on_game_started() -> void:
	await before_load.call()
	super._on_game_started()
