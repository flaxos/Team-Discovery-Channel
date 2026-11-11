# Team Discovery Channel

Stargate: SG Extraction is a Godot 4.4.1 co-op tactical shooter. The main playable setting is the three-level SGC (Sublevels 28, 27 and 26); a first development mission also runs on a modular offworld-style facility. The repository also contains a separate Alignment & Voting web app for planning.

**What to build next:** see the [roadmap](ROADMAP.md).

## Play locally

From the checkout you want to test:

```sh
godot --path client
```

In the lobby, select a callsign and class, click **ESTABLISH SGC BASE**, choose **LEVEL / MISSION**, then click **LAUNCH SELECTED MISSION**.

| Mission | Behavior |
| --- | --- |
| **SGC Defense — Levels 28/27/26** | Incoming Jaffa, objectives and outbound extraction. The host selects difficulty. |
| **SGC UAT Base — No Hostile Activation** | The same map, equipment and friendly personnel for exploration, with automatic hostile activation and waves disabled. Difficulty is disabled. |
| **Modular Extraction UAT — Development** | A development slice on a modular test facility: reach the command room, use a console and return, with Jaffa patrols. See [its guide](docs/maps/modular-extraction-mission.md). |

To preselect quiet UAT, run `godot --path client -- --mission sgc_uat`, then host and launch in the lobby. This flag selects the mission; it does not bypass the lobby. The normal game directory on the development machine is `/home/flax/games/Team-Discovery-Channel`; it is separate from Orca worktrees. Restart a running game after updating its checkout.

See the [player guide](docs/PLAYING.md) for controls, mission objectives, floor selection, shutters and multiplayer launch commands.

## Current map and validation

Operations is raised above embarkation behind sealed observation glass, with side/rear stair access; briefing overlooks it from Level 27. The gate is 6.7 m across, inside a 24 m wide, 12 m high chamber. These are playable SG-1-informed proportions, with authored peripheral corridors and Level 26 support rooms.

The lift has aimed floor buttons and a floor picker. Both factions navigate the region graph, stairs and lift. Corridor openings are clipped to adjoining rooms; enclosure validation checks the built walls, floors, ceilings and connecting shafts. A failed enclosure check blocks the navigation bake. Buffer-lockout and ROM-upload messages use the objective HUD rather than opening a stuck dialing panel.

The [map authoring contract](docs/maps/sgc.md) covers layout references, schema, art-replacement slots, navigation and enclosure checks. Modular facilities are built with a separate room kit and the shared [AI authoring CLI](docs/maps/ai-level-authoring.md). The [roadmap](ROADMAP.md) distinguishes implemented work from planned stealth, gate travel and faction content.

## Developer checks

```sh
python3 tools/run_godot_tests.py --profile full --timeout 240
```

The full profile discovers every `client/tests/test_*.gd`. The last recorded local result is **69/69 checks** on the PR #40 branch (project import, 67 suites and a persistence reader process). The hosted CI full profile is currently failing on `main` for an environment reason described in [testing](docs/TESTING.md#current-baseline). Neither result is a claim of human multiplayer acceptance. See [testing and UAT](docs/TESTING.md) for profiles, reports, visual captures and the manual acceptance route.

## Alignment & Voting app

```sh
npm ci --prefix alignment-app
npm run dev
```

Open [localhost:5173](http://localhost:5173). Retrieve the local access token with `npm --prefix alignment-app run auth-token` and enter it in the app. The API listens on loopback port 4100 by default. Its authentication, deployment settings and generated-document export contract are in the [Alignment app guide](docs/ALIGNMENT.md).

Voting exports write planning snapshots under `docs/generated/`; they do not replace these maintained project documents.

## Project documentation

Start with the [roadmap](ROADMAP.md) and the [documentation index](docs/README.md). [GDD.md](GDD.md) describes the implemented design and future vision; [BOOTSTRAP_PROMPT.md](BOOTSTRAP_PROMPT.md) is the current contributor handoff; [TEAM_CONTRACT.md](TEAM_CONTRACT.md) records the team's grounding pact. Historical plans and audits are linked separately from current operating instructions.

Contributors: **flaxos** — AI orchestration, core systems and combat; **Scotty** — multiplayer, game feel, weapons and perks.
