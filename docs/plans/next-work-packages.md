# Next work: human sessions and the next two agent packages

Written 13 November 2026, after phase 3 landed on `main` (PRs #45, #46 and #49). It continues section 8 of the [master plan](master-development-roadmap.md#8-the-first-three-work-packages), whose three packages (EX-1, ST-1, GI-1) are done. [ROADMAP.md](../../ROADMAP.md) says which of these to pick up; this file holds the detail.

Three things can start now and none blocks another:

| | Work | Who | Needs |
|---|---|---|---|
| **A** | Human play sessions: close the gates, tune the numbers | Two people | A checkout of `main`, this page |
| **B** | Package 4 — GA-0 Goa'uld visual brief and theme-slot audit | Any agent (Codex-class) | Nothing |
| **C** | Package 5 — GT-1 mission session state and host split | Fable-class agent | Decision D-002 confirmed (open question 1) |

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

## C. Package 5 — GT-1 mission session state and host split

1. **Objective.** Separate what survives a world change (roster, objective progress, result) from the world scene, and extract a slim mission host that SGC and modular missions share. No visible change.
2. **Prerequisites.** D-002 confirmed by the owners (the squad always travels together: open question 1). Do the human sessions first if possible, because this touches the most stable code.
3. **Likely files.** `client/scripts/net/NetworkManager.gd`, `client/scripts/main/MainGameCoordinator.gd`, `client/scripts/world/GateRoom.gd`, `client/scripts/mission/ModularMission.gd`, a new session script, the multiplayer suites.
4. **Boundaries.**
   - No travel: no new world, no gate behaviour change. SGC Defense rules unchanged.
   - Every existing join, retry, snapshot and result test passes unchanged.
   - Risks R9 (SGC Jaffa act behind the result) and R11 (SGC coupling) are in scope only if the split makes them cheap to close; otherwise leave them.
   - Keep `ModularMission`'s public behaviour: sentries, alert director, objectives, result.
5. **Acceptance tests.**
   - The full profile is unchanged, including the dedicated, late-join, retry and alert multiplayer suites.
   - A second modular mission definition needs no SGC overrides in its host.
   - A new test builds the session object, changes the world scene under it and shows roster and objective state survive; a late joiner receives the state.
6. **Human verification.** Repeat extraction UAT steps 7–10 and one infiltration session with two people, plus SGC Defense once.
7. **Risks and rollback.** Highest regression risk in the plan. Keep each extraction in its own commit so any can be reverted. If a step needs behaviour change to pass, stop and report rather than adapting the tests.
8. **Done when.** Hosted CI is green, the multiplayer suites pass unchanged, the architecture document names the session and host, and the PR lists the human sessions as pending.

**Handoff prompt**

> Repository `flaxos/Team-Discovery-Channel`, Godot 4.4.1. Read `ROADMAP.md`, then package 5 (GT-1) in `docs/plans/next-work-packages.md`, decision D-002 and D-008 in `docs/DECISIONS.md`, risks R9, R11 and R12 in the master plan, and `client/scripts/world/GateRoom.gd`, `client/scripts/mission/ModularMission.gd`, `client/scripts/net/NetworkManager.gd` and `client/scripts/main/MainGameCoordinator.gd`. Introduce a session object above the world scene that owns roster state, objective progress and the result, and extract the mission host logic that SGC and modular missions share. No behaviour change and no travel. Every existing suite must pass unchanged; write the session survival test first. Work on a new branch from `main` in a separate worktree, in small commits, and preserve uncommitted files in other checkouts. Check `gh pr checks` before calling it green. Stop when ready for review; do not start GT-2. Do not merge.

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
