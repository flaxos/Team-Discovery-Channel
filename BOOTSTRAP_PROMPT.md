# Contributor and coding-agent handoff

Project: **Stargate: SG Extraction**, Team Discovery Channel. Contributors: flaxos and Scotty. Repository: https://github.com/flaxos/Team-Discovery-Channel.

This is an existing playable Godot **4.4.1** project, not an instruction to scaffold a new game or server. Continue the current slice and preserve working behavior. The old vote-generated bootstrap vision is represented by [generated planning snapshots](docs/generated/README.md); maintained documentation describes implemented behavior.

## Start here

1. Read [README](README.md), [architecture](docs/ARCHITECTURE.md), [map contract](docs/maps/sgc.md), [testing/UAT](docs/TESTING.md) and the active [work tracker](plan/README.md).
2. Inspect the actual checkout, branch, status and applicable repository/user instructions before editing. Preserve unrelated changes. Historical plans/audits describe their own baseline; they are not new approval or delegation instructions.
3. Launch the `client/` directory of the checkout containing the changes. The development machine's base game is `/home/flax/games/Team-Discovery-Channel`; Orca worktrees are separate. A running game must restart to load updated code/resources.

## Current scope and interfaces

- The normal entry is `client/scenes/main/Main.tscn`, with `MainGameCoordinator`, the lobby and the `NetworkManager` autoload.
- Defense and UAT share the three-level SGC map. UAT uses `SGCUATBase.tscn` and disables automatic hostile activation/waves. Mission/difficulty are host owned and synchronize before world initialization and on join/retry.
- Keep the native ENet server-authoritative combat and interaction paths. Do not add a Node/WebSocket game server; the Alignment app is a separate planning service.
- Gate state/direction belongs to `StargateRing`; wave progression/objective eligibility belongs to `WaveManager`; approved dialing/ROM upload belongs to the dialing console. Preserve reservation and stale-callback protections.
- Use `SGCMapDefinition` regions/connections, `SGCMap` geometry/art slots, `SGCNavigator` for both factions and `SGCEnclosureValidator` for shell validation.
- Preserve the canonical `KeybindingManager`, ADS squad wheel, prompt refresh and single player-controller interaction route. Lockout/upload updates must not open a session panel.

## Map and art constraints

Keep the existing production capsule dimensions. Main floors are 0/5.5/11 m; operations has a 1.5 m offset. Keep sealed observation glazing and side/rear access, the guarded corner spiral and independent control/briefing shutters. Dimensions are SG-1-informed gameplay adaptations; do not invent production-blueprint precision for authored corridors or Level 26 rooms.

Walking portals must share a room boundary and sufficient clearance. Indoor walls, floors, ceilings and shafts must enclose the playable volumes. The bake refuses enclosure failures. Preserve continuous physical stair/lift movement; neither AI nor tests may teleport to pass a route or inject fake upward velocity. Rebuild checked-in navigation when collision/layout changes.

Use existing dimensioned art slots and material briefs. Replacement visuals preserve collision and must fit their envelope. Keep ceiling/shaft-cap bit `128` outside nav baking and in character/weapon queries; do not reuse corpse bit `64`.

## Verification and delivery

```sh
python3 tools/run_godot_tests.py --profile full --timeout 240
```

The last gameplay baseline `a720594` passed 51 local checks; consult current output rather than copying that claim to untested work. Tests reject errors/assertions/leaks even with exit zero. Use targeted checks while developing, then required regression coverage. Follow the documented graphical and two-human UAT route; headless checks do not establish visual quality or game feel.

Update maintained docs and PR descriptions for the final behavior. Keep generated vote snapshots separate. Preserve historical findings as dated records. Describe what changed, what was verified and what human acceptance remains. Do not expand into offworld theaters, new netcode or bespoke art merely because old planning text mentions them.

The [team contract](TEAM_CONTRACT.md) remains the grounding pact: prioritize a playable co-op game and shared components over speculative scope.
