extends "res://tests/test_campaign_variation_multiplayer.gd"
## Dedicated-server ENet variant for Milestone CA-2 campaign variation, difficulty tiers & sync.


func dedicated() -> bool:
	return true


func _spawn_peer(peer_role: String, log_file: String) -> int:
	return OS.create_process(
		OS.get_executable_path(),
		[
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", output_dir.path_join(log_file),
			"--script", "res://tests/test_campaign_variation_dedicated.gd",
			"--", "--role", peer_role, "--result-dir", output_dir
		]
	)
