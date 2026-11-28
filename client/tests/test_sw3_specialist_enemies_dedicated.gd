extends "res://tests/test_sw3_specialist_enemies_multiplayer.gd"
## Dedicated-server ENet variant of SW-3 Specialist Enemies & Goa'uld System Lord Boss verification.


func dedicated() -> bool:
	return true


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_sw3_specialist_enemies_dedicated.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)
