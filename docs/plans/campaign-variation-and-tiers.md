# CA-2: Campaign Variation, Difficulty Tiers & Replayability

Status: Implementing  
Workstream: L — Campaign and replayability (`CA-2`)  
Prerequisite: `CA-1` (Operation Ha'tak Strike, `GT-3`, `SW-2`)

## Overview

`CA-2` extends the three-stage `Operation Ha'tak Strike` campaign and selectable offworld missions with:

1. **Offworld Difficulty Tiers (`Easy`, `Medium`, `Hard`)** with deterministic tactical scaling across patrol strength, shielded Horus officer promotions, sentry notice speed, alarm escalation cadence, extraction timer pressure, and stage-to-stage carryover floors.
2. **Deterministic Per-Run Seed & Stage Variation (`run_seed`, `stage_variants`)** combining patrol route reversal/start-waypoint rotation and data-driven `MissionObjectiveVariant` bonus steps so replays reshuffle security without changing valid mission topology or introducing unauthored rooms.
3. **Composable Operational Mutators** (`shielded_vanguard`, `rapid_response`, `heightened_watch`, `tight_extraction`, `iron_discipline`) configurable by the host or CLI (`--seed`, `--modifier`).
4. **Replayability, Tactical Rating & Persistent Career Records** computing stage and campaign grades (`S`, `A`, `B`, `C`, `F`) and honors (`GHOST SQUAD`, `NO ONE LEFT BEHIND`, `SYSTEM LORD SLAYER`, `MUTATOR VETERAN`), persisted in `user://campaign_records.json` across `reset_campaign()` and `replay_campaign()`, and surfaced on `SGCBriefingTerminal`, mission debriefs, and the Lobby UI.

## Difficulty Tier Matrix

| Tier | Patrol Size Bonus | Shield Officer Promotions | Reinforcement Lead Shield | Reinforcement Delay Scale | Alarm Raise Time Scale | Timer Scale | Sight Notice Scale | Carryover HP Floor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `Easy (0)` | `+0` | `0` | Only group 0 with `shielded_vanguard` | `1.00x` | `1.00x` | `1.00x` | `1.00x` | `25.0 HP` |
| `Medium (1)` | `+0` | `1` | Group 0 (or all w/ `shielded_vanguard`) | `0.80x` | `0.85x` | `0.85x` | `0.85x` | `25.0 HP` |
| `Hard (2)` | `+1` (max 3 on multi-room patrols) | `2` | All reinforcement leads | `0.65x` | `0.70x` | `0.75x` | `0.72x` | `20.0 HP` |

Notes:
- `DIFFICULTY_EASY` preserves exact baseline sentry counts (`6` on `goauld_infiltration`) and timings so existing single-mission and CA-1 regression fixtures remain unchanged.
- `iron_discipline` lowers the stage carryover HP floor to `15.0 HP`.
- Mutators stack multiplicatively down to safe lower bounds (`>= 0.40x` reinforcement delay, `>= 0.45x` alarm raise / sight notice, `>= 0.50x` timer scale).

## Deterministic Variation & Network Authority

- The host generates a positive `run_seed` on `CampaignManager.start_campaign()` (or accepts an explicit host/CLI seed) and derives `stage_variants` deterministically per stage index.
- `run_seed`, `campaign_difficulty`, `active_modifiers`, and `stage_variants` are saved in `user://campaign_save.json` (`version: 2`, backwards-compatible with `version: 1`) and replicated via `CampaignManager.sync_campaign_state` both on stage transitions and before `NetworkManager.start_game` on peer join/late join.
- Clients cannot mutate `mission_difficulty`, `run_seed`, `campaign_difficulty`, or `active_modifiers`; server-side guards reject client RPC/local mutation attempts.
- Retries (`request_restart_game`) preserve the active run's seed, tier, mutators, and stage variant identically; `replay_campaign()` preserves `career_records` while rolling a fresh campaign run.

## Verification

- Single-process suite: `client/tests/test_campaign_variation_and_tiers.gd`
- Listen-host & late-join multiplayer suite: `client/tests/test_campaign_variation_multiplayer.gd`
- Dedicated server suite: `client/tests/test_campaign_variation_dedicated.gd`
