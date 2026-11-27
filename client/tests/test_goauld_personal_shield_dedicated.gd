extends "res://tests/test_goauld_personal_shield_multiplayer.gd"
## Dedicated-server ENet variant of SW-2 Goa'uld Personal Shield verification.

func dedicated() -> bool:
	return true


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_goauld_personal_shield_dedicated.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)
