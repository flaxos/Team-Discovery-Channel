# Next work: human sessions and the next two agent packages

Written 13 November 2026, after phase 3 landed on `main` (PRs #45, #46 and #49). It continues section 8 of the [master plan](master-development-roadmap.md#8-the-first-three-work-packages), whose three packages (EX-1, ST-1, GI-1) are done. [ROADMAP.md](../../ROADMAP.md) says which of these to pick up; this file holds the detail.

**Update, 14 November 2026.** An owner played both new missions alone and accepted phases 1 to 3 ([record](../reviews/2026-11-14-owner-solo-uat.md), [D-014](../DECISIONS.md)); the two-player sessions in part A are deferred, not cancelled. Package 4 (GA-0) is done: see the [Goa'uld visual brief](../maps/goauld-visual-brief.md). Package 5 (GT-1) was paused when the owners decided players may be in different worlds ([D-013](../DECISIONS.md)); the [split-world design](gate-travel-split-worlds.md) (GT-0) is now written and the package is rewritten from it. [ROADMAP.md](../../ROADMAP.md#pick-up-here) has the current list.

As written on 13 November, three things could start and none blocked another:

| | Work | Who | Needs |
|---|---|---|---|
| **A** | Human play sessions: close the gates, tune the numbers | Two people | A checkout of `main`, this page |
| **B** | Package 4 — GA-0 Goa'uld visual brief and theme-slot audit | Any agent (Codex-class) | Nothing |
| **C** | Package 5 — GT-1 worlds that can coexist | **Done** (14 November 2026) | Next is GT-2, outbound travel: [design, section 7](gate-travel-split-worlds.md#7-milestones) |

Phase 6 work (EV-2, TA-3, TA-2, CO-1, SW-1) should wait for A: it is better designed from what the sessions find.

## A. Human play sessions

Nothing an agent can do replaces these. They close the **EX-2**, **Stealth**, **Infiltration greybox** and **Infiltration complete** gates in [ROADMAP.md](../../ROADMAP.md#near-term-acceptance-gates) and supply the evidence for tuning every provisional value.

### Get a build to play

The play machine's main checkout (`/home/flax/games/Team-Discovery-Channel`) is on an old branch with local edits. **Do not switch it.** Make a separate checkout of `main`:

```sh
cd /home/flax/games/Team-Discovery-Channel
git fetch origin
git worktree add ../tdc-play origin/main --detach
godot --path ../tdc-play/client -- --mission goauld_infiltration
```

Record `git -C ../tdc-play rev-parse --short HEAD` in the record. Godot must be **4.4.1**. A running game must be restarted to load changes.

Two players: one hosts from the lobby; the other joins with `godot --path ../tdc-play/client -- --connect <host-ip> --port 7777 --name Carter --class carter_tech`. For a dedicated server: `godot --headless --path ../tdc-play/client -- --server --port 7777 --mission goauld_infiltration`. Flags are listed in the [player guide](../PLAYING.md).

### Session plan (about two hours for two people)

| Order | Session | Script | Record in |
|---|---|---|---|
| 1 | Extraction UAT, listen host | The eleven-step checklist in the [extraction guide](../maps/modular-extraction-mission.md#human-uat-checklist-pending-sign-off) | `docs/reviews/YYYY-MM-DD-extraction-uat.md` |
| 2 | Extraction UAT, dedicated server | Steps 7–10 of the same checklist, one client on a headless server | same file |
| 3 | SGC Defense, two humans | Item 7 of the [human acceptance route](../TESTING.md#graphical-and-human-uat): complete Defense, checking objectives, gate direction, revive, late join and retry | same file |
| 4 | Infiltration, quiet route | Items 1, 2, 5, 7 of the [infiltration checklist](../maps/goauld-infiltration-mission.md#human-uat-checklist-pending) | `docs/reviews/YYYY-MM-DD-infiltration-playtest.md`, from the [template](../reviews/infiltration-playtest-template.md) |
| 5 | Infiltration, loud route | Items 3, 4, 8, 9 (get spotted on purpose, stop the runner, let the alarm sound) | same file |
| 6 | Infiltration, two players, mixed | Items 6, 10, 11 (one quiet and one loud; consoles disabled; MP5 against a rifle) | same file |

Fill in the template's questions and gate verdicts while it is fresh. File each defect as an issue with the peer that saw it.

### Tuning values to adjust from what you find

All are provisional. Change them in the file named, one at a time, and re-run the suite listed.

| Value | Where | Suite to re-run |
|---|---|---|
| View range 24 m, cone 110°, notice 0.8 s near / 2.5 s far, forget 3 s | `JaffaAI.gd` exports under *Sentry perception* | `test_jaffa_perception`, `test_goauld_infiltration_mission` |
| Lose target 1.5 s, look-round 3 s, search points 3 at 5 m, 1.5 s each | same exports | `test_jaffa_perception`, `test_jaffa_hearing` |
| Noise radii (P90 30, M9 25, M249 40, staff 30, Zat 10, MP5 6, C4 45, claymore 40, turret 35) | `noise_radius` on each `Weapon*.gd`; `NOISE_RADIUS` on `C4Satchel`, `ClaymoreMine`, `DeployableTurret` | `test_jaffa_hearing` |
| Alarm raise time 2.5 s; calm-down 8 s | `MissionAlarm.raise_time` in `goauld_infiltration.tres`; `MissionAlert.CALM_DELAY` | `test_mission_alert` |
| Reinforcements: 2 after 6 s, 2 shock guards after 20 s | `MissionReinforcement` entries in `goauld_infiltration.tres` | `test_mission_alert`, `test_goauld_infiltration_loud` |
| Cover range 3 m; peek 0.7 s | `LevelNavigator.PROP_COVER_MIN_RANGE`; `JaffaAI._hold_prop_cover` | `test_jaffa_prop_cover` |
| Patrol routes and sizes | `MissionPatrol` entries in `goauld_infiltration.tres` | `test_goauld_infiltration_mission` (the quiet route must stay possible) |

When the template's **Infiltration complete** line can be ticked, update ROADMAP.md's gate table and change this section's status here.

## B. Package 4 — GA-0 Goa'uld visual brief and theme-slot audit

**Done 14 November 2026.** Result: [Goa'uld visual brief](../maps/goauld-visual-brief.md). Open question 7 was answered the same day ([D-012](../DECISIONS.md)), so GA-1 can start.

1. **Objective.** Give art a written target and an exact list of what the theme system can already render, so the first themed slice (GA-1) starts without rework.
2. **Prerequisites.** None. Documentation and read-only inspection only.
3. **Likely files.** New `docs/maps/goauld-visual-brief.md`; `client/resources/level_themes/goauld.tres` and `neutral.tres` (read); `client/scripts/level/LevelThemeResolver.gd` (read); `docs/maps/ai-level-authoring.md` and `docs/maps/modular-levels.md` (link to the new brief); `docs/README.md` index; `ROADMAP.md` status.
4. **Boundaries.**
   - No gameplay scripts, scenes, resources or tests change.
   - Original designs inspired by the setting. No copied production assets or screenshots.
   - Do not decide how art is made (open question 7); list the options with costs, and say what each needs from the theme system.
   - Do not move sockets, footprints, collision or navigation. Decision D-010: themes never change them.
5. **Deliverables.**
   - Design language: silhouettes, door proportions, rib spacing, palette, lighting mood, what makes Goa'uld rooms different from the neutral greybox; each stated as a dimension or a colour so it can be checked.
   - A table of the five theme slots (`wall_panels`, `floor_detail`, `ceiling_detail`, `door_frame`, `room_detail`): what each renders today in `LevelThemeResolver`, which modules and presets reach it, and any gap.
   - The list of rooms in the infiltration compound ranked by how much time a player spends in them, from the patrol and route data, so GA-1 and GA-2 are ordered by use.
   - Readability constraints from play: awareness tells (**?**, **!**, **!!**), cover props and doors must stay visible against the palette.
   - A short paragraph per art-method option for open question 7, with what each needs and what it risks.
6. **Acceptance.** A reviewer can pick one corridor, one door frame and one 8 × 8 m chamber from the document alone. Every statement about the resolver cites a file and line. `git diff --stat` shows only documents.
7. **Human verification.** The owners choose the art method and approve the palette before GA-1 starts.
8. **Done when.** The brief is merged, the index and roadmap link it, and open question 7 is either answered or has a recommendation.

**Handoff prompt**

> Repository `flaxos/Team-Discovery-Channel`, Godot 4.4.1. Read `ROADMAP.md`, then package 4 (GA-0) in `docs/plans/next-work-packages.md`, section 6 of `docs/plans/master-development-roadmap.md`, decision D-010 in `docs/DECISIONS.md`, `client/resources/level_themes/goauld.tres`, `neutral.tres` and `client/scripts/level/LevelThemeResolver.gd`. Write `docs/maps/goauld-visual-brief.md` with the design language, the theme-slot audit, the compound's rooms ranked by use and the art-method options, as the package describes. This is documentation only: change no code, scene, resource or test. Work on a new branch from `main` in a separate worktree and preserve uncommitted files in other checkouts. Stop when the brief and index changes are ready for review; do not start GA-1. Do not merge.

## C. Package 5 — GT-1 worlds that can coexist

**Done 14 November 2026.** What was built and how it differs from the list below is in [the design, GT-1 as built](gate-travel-split-worlds.md#gt-1-as-built). The text is kept as the record of what was asked.

Rewritten 14 November 2026 from the [split-world travel design](gate-travel-split-worlds.md). The earlier text, which assumed the squad always travels together, is in this file's history.

1. **Objective.** Make it correct to run the SGC and an offworld site side by side in one process. No travel and no visible change.
2. **Prerequisites.** The design ([D-016](../DECISIONS.md)) and the owners' rules ([D-017](../DECISIONS.md)). Both exist.
3. **Likely files.** A new `MissionWorld` helper and `MissionSession` script; the twelve scripts with whole-game lookups listed in section 4.3 of the design; `GateRoom.gd`, `MainGameCoordinator.gd`, `NetworkManager.gd`; new suites.
4. **Boundaries.**
   - No travel, no lobby entry, no change to how any existing mission plays.
   - Every existing suite passes unchanged. If one needs editing to pass, stop and report.
   - No host split: `ModularMission` goes on extending `GateRoom` (risk R11 stays open).
5. **Acceptance tests.**
   - The full profile is unchanged.
   - A coexistence suite loads the SGC and the compound together in both orders: a sentry notices an operative in its own world and not one in the other; airmen likewise; each world counts its own squad.
   - The session places peers: a world spawns only its own, a late joiner goes home, and the mission fails only when every world's operatives are down.
   - A hidden world is not drawn, has no HUD and no active environment, and keeps simulating.
   - A static check fails on a new whole-game lookup by name.
6. **Human verification.** One SGC Defense and one infiltration session to confirm nothing changed. Frame time with two worlds loaded, on a display.
7. **Risks and rollback.** A missed lookup fails silently, so the coexistence suite runs both load orders. Keep the lookup changes in commits by script so any can be reverted.
8. **Done when.** Hosted CI is green, the suites above pass, the frame-time figures are in the pull request, and the architecture document names the session and the world helper.

**Handoff prompt**

> Repository `flaxos/Team-Discovery-Channel`, Godot 4.4.1. Read `ROADMAP.md`, `docs/plans/gate-travel-split-worlds.md`, package 5 (GT-1) in `docs/plans/next-work-packages.md`, and decisions D-016 and D-017. Add `MissionWorld.of(node)` and move every whole-game lookup by name to it; classify the group lookups. Add a `MissionSession` above the worlds that places peers and applies the fail rule, let `MainGameCoordinator` load one world or two, and add `set_presented` to a world. No travel, no lobby entry, no behaviour change: every existing suite must pass unchanged. Write the coexistence suite first and watch it fail on the sentry. Work on a new branch in a separate worktree, in small commits, and preserve uncommitted files in other checkouts. Check `gh pr checks` before calling it green. Stop when ready for review; do not start GT-2. Do not merge.

## Merging dependent pull requests

The repository allows squash, merge-commit and rebase merges, and the owner squash-merges. A squash replaces a PR's commits with one new commit on `main`. Any other open PR that still contains the original commits then reports **conflicts**, although its content is identical. This happened twice in phase 3 (after #45 and after #46).

- **Prefer one PR per milestone from `main`**, merged before the next is started, so nothing is stacked.
- **If milestones must be built before the previous one is merged**, make each PR contain its predecessors and merge **only the last**. Close the others.
- **If PRs are merged one at a time**, use *Create a merge commit* for them, or ask the agent to clear the conflicts afterwards. The fix, valid only when `main`'s tree equals the squashed branch's tree (check with `git diff --quiet`), is `git merge -s ours origin/main` on the lowest remaining branch, then `git merge` that branch forward.
- Never ask for a force-push; carry fixes forward with merges.

## After these

| Next | When |
|---|---|
| GA-1 Goa'uld vertical slice | After GA-0 and the art-method decision |
| GT-2 Outbound travel, GT-3 Return and debrief | After GT-1 |
| TA-3 Rerouting, avoidance, door closing; then EV-2 Stages, triggers and door actions | After the human sessions show whether lockdown is wanted |
| CO-1 Co-op kit (resupply), SW-1 Takedowns and quiet weapons | After the human sessions |

Details for each are in section 5 of the [master plan](master-development-roadmap.md#5-milestones).
