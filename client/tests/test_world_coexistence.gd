extends SceneTree
## Two worlds side by side (roadmap GT-1; docs/plans/gate-travel-split-worlds.md). The quiet
## SGC and the Goa'uld compound are loaded together through the production lobby and
## coordinator, the compound 2 km away. Each world must find only its own operatives,
## enemies and props; the session places operatives, presents one world and loses the mission
## only when every operative in both worlds is down. There is no travel yet: the suite moves
## an operative between worlds by hand, on the host.
const MISSION := SGCNetworkManager.MISSION_TWO_WORLDS_DEV
var net: SGCNetworkManager
var main: MainGameCoordinator
var home: GateRoom
var site: ModularMission
var session: MissionSession


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func launch(previous: int = 0) -> void:
	home = null
	for i in range(900):
		var current := main.current_gate_room as GateRoom
		if current != null and current.get_instance_id() != previous and main.current_site != null:
			home = current
			break
		await frames(1)
	assert(home != null, "Both worlds load")
	site = main.current_site as ModularMission
	session = main.session
	assert(site != null and session != null)
	if not site.is_started:
		await site.started
	assert(site.setup_errors.is_empty(), str(site.setup_errors))
	assert(site.level.last_errors.is_empty(), str(site.level.last_errors))
	await frames(5)


func sentries() -> Array[JaffaAI]:
	var result: Array[JaffaAI] = []
	for enemy in site.enemies.get_children():
		var jaffa := enemy as JaffaAI
		if jaffa != null and jaffa.current_state != JaffaAI.State.DEAD:
			result.append(jaffa)
	return result


## Whether any of the first three sentries notices an operative held 3 m in front of it.
func noticed_by_a_sentry(operative: PlayerController3D) -> bool:
	for jaffa: JaffaAI in sentries().slice(0, 3):
		for side: float in [-1.0, 1.0]:
			for i in range(150):
				operative.global_position = (
					jaffa.global_position + jaffa.global_basis.z * 3.0 * side + Vector3(0, 0.05, 0)
				)
				operative.velocity = Vector3.ZERO
				await physics_frame
				if jaffa.awareness_level != JaffaPerception.Level.UNAWARE:
					return true
	return false


func inside(world: Node, nodes: Array[Node]) -> bool:
	for node in nodes:
		if not world.is_ancestor_of(node):
			return false
	return true


func active_environment() -> Environment:
	return root.get_world_3d().environment


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	# A development mission: offered in the lobby only because the flag chose it. The suites
	# of the listed missions check that a lobby without the flag has four entries.
	var lobby := main.current_lobby as LobbyUI
	assert(lobby.mission_option_button.item_count == 5)
	assert(lobby.mission_option_button.get_item_metadata(4) == MISSION)
	assert(lobby.mission_option_button.selected == 4 and lobby.start_game_button.text == "LAUNCH TWO WORLDS (DEV)")
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	await launch()

	# --- Structure: home keeps a single world's path; the site stands far off beside it.
	assert(str(home.get_path()) == "/root/Main/WorldContainer/GateRoom", str(home.get_path()))
	assert(str(site.get_path()) == "/root/Main/WorldContainer/Site/GateRoom", str(site.get_path()))
	assert(site.global_position.is_equal_approx(MainGameCoordinator.SITE_OFFSET))
	assert(home.global_position == Vector3.ZERO)
	assert(home.mission_id == SGCNetworkManager.MISSION_SGC_UAT, "Each world keeps its own rules")
	assert(site.mission_id == SGCNetworkManager.MISSION_GOAULD_INFILTRATION)
	assert(session.worlds == [home, site] and session.home() == home)
	assert(home.session == session and site.session == session)
	assert(root.get_tree().get_nodes_in_group(MissionWorld.GROUP).size() == 2)
	assert(sentries().size() == 6, "The site's patrols spawned")
	for jaffa in sentries():
		assert(jaffa.global_position.x > 1500.0, "Patrols stand in the site, not at the origin")

	# --- Placement: everyone starts at home; the site spawns nobody.
	var operative := home.players_container.get_node_or_null("1") as PlayerController3D
	assert(operative != null, "The host's operative is in the SGC")
	assert(site.players_container.get_child_count() == 0, "No operative was created in the site")
	assert(home.squad_state() == Vector2i(1, 1) and site.squad_state() == Vector2i.ZERO)
	assert(home.hosts_peer(1) and not site.hosts_peer(1))
	assert(home.hosts_peer(42) and not site.hosts_peer(42), "A peer nobody placed belongs at home")

	# --- Each world finds only its own surroundings, whichever was loaded first.
	var airman := home.allies_container.get_child(0) as Node
	var sentry := sentries()[0]
	assert(MissionWorld.of(operative) == home and MissionWorld.of(airman) == home)
	assert(MissionWorld.of(sentry) == site and MissionWorld.of(site.level) == site)
	assert(MissionWorld.find(sentry, "Players") == site.players_container)
	assert(MissionWorld.find(sentry, "Enemies") == site.enemies)
	assert(MissionWorld.find(sentry, "Allies") == null, "The site has no airmen; the SGC's are not its own")
	assert(MissionWorld.find(sentry, "GateRoom") == site and MissionWorld.find(sentry, "TacticalHUD") == site.hud)
	assert(MissionWorld.find(airman, "Players") == home.players_container)
	assert(MissionWorld.find(airman, "Allies") == home.allies_container)
	assert(MissionWorld.find(airman, "Enemies") != site.enemies)
	assert(MissionWorld.find(operative, "GateRoom") == home and MissionWorld.find(operative, "TacticalHUD") == home.hud)
	assert(MissionWorld.find(operative, "SGCDialingConsole") != null and MissionWorld.find(sentry, "SGCDialingConsole") == null)
	for group: StringName in [&"cover", &"interactable", &"modular_door", &"noise_listeners"]:
		var here := MissionWorld.in_group(sentry, group)
		var there := MissionWorld.in_group(airman, group)
		assert(inside(site, here), str(group) + " seen from the site is in the site")
		assert(inside(home, there), str(group) + " seen from the SGC is in the SGC")
		assert(here.size() + there.size() == root.get_tree().get_nodes_in_group(group).size(), str(group))
	assert(not MissionWorld.in_group(sentry, &"modular_door").is_empty())
	assert(not MissionWorld.in_group(airman, &"interactable").is_empty())
	assert(MissionWorld.first_in_group(airman, &"sgc_map") != null)
	assert(MissionWorld.first_in_group(sentry, &"sgc_map") == null, "A Jaffa in the site must not route on the SGC's map")
	# An actor outside any world still sees everything, as a bare test scene always did.
	var loose := Node.new()
	root.add_child(loose)
	assert(MissionWorld.of(loose) == root)
	assert(MissionWorld.in_group(loose, &"interactable").size() == root.get_tree().get_nodes_in_group(&"interactable").size())
	loose.free()

	# --- Presentation: this peer shows home. The site is hidden but keeps simulating.
	assert(session.presented == home and home.is_presented and not site.is_presented)
	assert(home.visible and home.hud.visible and home.hud.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(not site.visible and not site.hud.visible and site.hud.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(MissionWorld.presented(operative) and not MissionWorld.presented(sentry))
	var home_holders := home.find_children("*", "WorldEnvironment", true, false)
	assert(not home_holders.is_empty(), "The SGC has an environment to hand over")
	var home_environment := (home_holders[0] as WorldEnvironment).environment
	assert(home_environment != null and active_environment() == home_environment)
	var walked := 0.0
	var before: Array[Vector3] = []
	for jaffa in sentries():
		before.append(jaffa.global_position)
	await frames(180)
	for i in range(sentries().size()):
		walked = maxf(walked, sentries()[i].global_position.distance_to(before[i]))
	assert(walked > 1.0, "Patrols in the hidden world keep walking: " + str(walked))
	for jaffa in sentries():
		assert(jaffa.awareness_level == JaffaPerception.Level.UNAWARE, "Nobody in the SGC is seen from the site")
	assert(site.alert.alert_level == MissionAlert.Level.CALM)

	# --- Hand the operative to the site by hand (travel itself is GT-2).
	var profile := operative.class_id
	operative.free()
	session.place(1, site)
	assert(site.hosts_peer(1) and not home.hosts_peer(1))
	site._spawn_player(1, profile, (site.spawns_container.get_child(0) as Node3D).global_position)
	await frames(3)
	operative = site.players_container.get_node("1") as PlayerController3D
	assert(home.players_container.get_node_or_null("1") == null)
	assert(operative.global_position.distance_to((site.spawns_container.get_child(0) as Node3D).global_position) < 1.0,
		"An operative created in the site stands at the site's spawn point, 2 km out")
	# Gadgets are placed beside the operative, not at the same numbers nearer the origin.
	var beside := MissionWorld.local(site.players_container, operative.global_position)
	assert(beside.distance_to(operative.position) < 0.001 and beside.x < 500.0)
	assert(MissionWorld.of(operative) == site)
	assert(site.hud.local_player == operative, "The site's HUD follows the operative")
	# The operative's own world is now the one this peer shows.
	assert(session.presented == site and site.is_presented and not home.is_presented)
	assert(site.visible and site.hud.visible and site.hud.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(not home.visible and not home.hud.visible and home.hud.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(active_environment() != home_environment, "The hidden SGC's environment no longer applies")
	session.present(home)
	assert(active_environment() == home_environment, "And it returns with the SGC")
	session.present(site)
	operative.health_component.current_health = 1000000.0
	# The fault this milestone fixes: with the SGC loaded first, sentries looked for
	# operatives in the SGC and could not see one standing in front of them.
	assert(await noticed_by_a_sentry(operative), "A sentry notices an operative in its own world")

	# --- Losing: only when every operative in both worlds is down (decision D-017).
	home._spawn_player(77, SGCNetworkManager.CLASS_CARTER_TECH, (home.spawns_container.get_child(0) as Node3D).global_position)
	await frames(3)
	var stayed := home.players_container.get_node("77") as PlayerController3D
	assert(home.squad_state() == Vector2i(1, 1) and site.squad_state() == Vector2i(1, 1))
	operative.health_component.current_health = 10.0
	operative.health_component.take_damage(500.0, null, "bullet")
	await frames(3)
	assert(operative.health_component.is_downed)
	assert(site.squad_state() == Vector2i(1, 0), "The whole away team is down")
	assert(session.result == -1 and site.mission_result == -1 and home.mission_result == -1,
		"The mission continues while someone in the SGC is standing")
	stayed.health_component.take_damage(5000.0, null, "bullet")
	await frames(3)
	assert(stayed.health_component.is_downed or stayed.health_component.is_dead)
	assert(session.result == 0, "Everyone in both worlds is down: the mission is lost")
	assert(home.mission_result == 0 and site.mission_result == 0, "Both worlds show the result")
	assert(site.hud.is_mission_ended and home.hud.is_mission_ended)

	# --- Retry replaces both worlds and starts everyone at home again.
	var old_home := home.get_instance_id()
	var old_site := site.get_instance_id()
	var old_session := session.get_instance_id()
	assert(net.request_restart_game())
	await launch(old_home)
	assert(site.get_instance_id() != old_site and session.get_instance_id() != old_session)
	assert(not is_instance_id_valid(old_home) or not (instance_from_id(old_home) as Node).is_inside_tree())
	assert(main.world_container.get_child_count() == 2, "No world left over from the first attempt")
	assert(session.result == -1 and home.mission_result == -1 and site.mission_result == -1)
	assert(home.players_container.get_node_or_null("1") != null and site.squad_state() == Vector2i.ZERO)
	assert(session.presented == home and not site.visible)
	assert(sentries().size() == 6)

	# --- A single-world mission has no session and is unchanged.
	main._load_lobby()
	await frames(2)
	net.disconnect_game()
	await frames(5)
	assert(main.world_container.get_child_count() == 0 and main.session == null and main.current_site == null)
	assert(main.get_node_or_null("MissionSession") == null)
	net.selected_mission_id = SGCNetworkManager.MISSION_SGC_UAT
	assert(net.host_game(0) == OK)
	net.request_start_game()
	await frames(10)
	var alone := main.current_gate_room as GateRoom
	assert(alone != null and alone.session == null and alone.is_presented and main.session == null)
	assert(alone.hosts_peer(1) and alone.hosts_peer(42))
	assert(alone.players_container.get_node_or_null("1") != null)
	print("PASS test_world_coexistence")
	quit(0)
