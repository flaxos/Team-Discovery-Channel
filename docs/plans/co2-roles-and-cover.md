# CO-2 chunk 2: Squad roles, field medic aid, offworld deployable cover, and lobby/HUD alignment

Sprint H completes `CO-2` alongside chunk 1's ammunition sharing (`docs/plans/ammunition-sharing.md`).

## Field Medic & Role Differentiation

All four selectable SGC classes preserve their authored weapons, hit points, and speeds, with explicit tactical role differentiation:

- **SG-3 Heavy Support (`sg3_heavy`)**: M249 SAW + Beretta M9 (`150 HP`, `6.0 m/s`), deployable `.50 cal` M2 tripod (`[G]`, `30 s` cooldown).
- **Tech Specialist & Field Medic (`carter_tech`)**: Suppressed MP5SD + Zat'nik'tel (`100 HP`, `6.8 m/s`), plus:
  - **2× Revive Speed & Trauma Recovery**: Revives downed operatives and allied SGC Airmen in `1.25 s` (vs `2.5 s` baseline) and restores `75%` maximum HP (vs `40%` baseline), enforced authoritatively on the server.
  - **Field Medkit (`[G]`, `2` charges)**: Restores up to `+50 HP` (`MEDKIT_HEAL_AMOUNT`) to an aimed standing/crouched teammate or allied Airman within `3.0 m` with a clear torso-to-torso path (`collision_mask = 1 | 128`), or applies trauma care to self when injured and no teammate is targeted. Downed allies still use `[E]` revive, full-health targets do not waste charges, and server sequence/incarnation validation prevents replays or overhealing. Medkit charges carry across Stargate travel (`MissionSession`) and campaign stages (`CampaignManager`), and restock at SGC and offworld `ArmoryResupplyStation` munitions stations.
- **Pointman / Recon Leader (`oneill_recon`)**: FN P90 + Beretta M9 (`120 HP`, `7.2 m/s`), `2` remote/timed C4 satchels (`[G]` deploy/detonate, `[T]` timer mode).
- **Allied Jaffa / Tok'ra Infiltrator (`tealc_jaffa`)**: Ma'Tok Staff + Zat'nik'tel (`160 HP`, `6.5 m/s`), heat-based energy arsenal requiring no ammunition pickups; staff plasma drains Goa'uld personal shields.

Every perk listed in `NetworkManager.CLASS_PROFILES`, `LobbyUI`, and `TacticalHUD` agrees 1:1 with the server implementation.

## Offworld Deployable Cover (`DeployableShield`)

`PlayerController3D.validate_shield_placement()` validates server-side placement before consuming a shield charge (`deployable_shields_count`):

- Forward wall/obstacle clearance and lateral width checks prevent deploying shields clipped inside walls or sealed bulkheads.
- Floor support raycasting snaps shields cleanly onto sloped ramps/steps while keeping flat surface placement deterministic.
- In modular offworld missions (`ModularMission`), placement checks against the baked `LevelAssembly` navigation map so shields land on walkable deck space, and anti-stacking prevents overlapping another live shield.
- Rejected placements preserve the operative's charge and surface a clear HUD toast reason.

Once deployed offworld, a `DeployableShield` (`600 HP`, `"cover"` + `"deployable_shield"` groups):

- Triggers operative auto-cover (`is_in_cover`) and crouch protection (`-65%` non-bypassable damage).
- Occludes Jaffa sightlines (`JaffaAI._has_line_of_sight`) when the operative ducks into cover without peeking, and intercepts incoming Ma'Tok `PlasmaBolt` impacts up to `600 HP`.
- Registers with `LevelNavigator.cover_props()` / `prop_blocks()` so tactical AI also treats deployed shields as valid low cover.
- Stays in the world where deployed across gate travel (`FieldKitNetwork`), replicates on late join, and clears cleanly on mission retry.

## Acceptance & Regression Tests

- `client/tests/test_co2_roles_and_cover.gd`: single-process verification of medic revive speed/HP ratio, Field Medkit healing/validation/restock/carryover, offworld `DeployableShield` placement/cover/LOS/bolt blocking/destruction, and lobby/HUD class alignment.
- `client/tests/test_co2_roles_and_cover_multiplayer.gd` & `client/tests/test_co2_roles_and_cover_dedicated.gd`: 2-peer listen server and pawnless dedicated server ENet suites covering server-authoritative fast medic revive, remote Field Medkit healing + replay/range rejection, offworld shield replication + late join, and coordinated retry restock/cleanup.
