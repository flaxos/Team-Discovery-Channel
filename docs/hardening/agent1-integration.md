# Agent 1 — Git integration and baseline recovery

Audit date: 8 November 2026. No shared history was rewritten, no force-push was used and no merge into main was performed.

## Confirmed finding

| Severity | Finding | Evidence | Correction |
| --- | --- | --- | --- |
| P0 | Sprint 20 was merged into the Sprint 19 feature branch rather than main, so current main lacked persistent remapping and its associated controls fixes/tests. | GitHub PR #19 merged at `a81304e8c002d64da03d1f49e0edd456385dbfd5` into main. PR #20 merged at `5b219b9bb7820a62dfa51ed6963567d562a167bf` into `feat/sprint19-cursor-confinement-ads-zoom-fade`. Current fetched main is `a81304e`; it has no `client/scripts/input/KeybindingManager.gd`. | Apply the exact Sprint 20 squash delta to a new main-based integration branch. |

The graph and tree comparison establish that Sprint 20 can be recovered without replaying earlier Sprint 19 changes:

- `git diff 250ad47 a81304e` is empty: the Sprint 19 branch tip and its main squash have identical trees.
- `git diff 2e224b8 5b219b9` is empty: the pre-squash Sprint 20 branch tip and PR #20 squash have identical trees.
- Prior unfinished cleanup was preserved separately by the lead agent at `b70ed190d1c0c58c0c96f3e95eefa91cbbb14be3`, whose parent tree matches the Sprint 20 squash.

## Integration history

Branch: `stabilisation/release-candidate`, based directly on fetched `origin/main` (`a81304e`).

1. `0d9dcce` — exact cherry-pick of PR #20 squash `5b219b9`. Restores the canonical KeybindingManager autoload, interactive remapping, persistence, ADS/squad routing, dynamic prompts and tests.
2. `0bb2d1b` — exact cherry-pick of preservation checkpoint `b70ed19`. Preserves already-authorized unfinished map accessibility, gate/mode lifecycle and retry changes for the specialist workstreams to audit and complete. These changes are not represented as validated production readiness.
3. This report commit adds integration evidence and the three UID sidecars generated for the preserved gate tests.

No cherry-pick conflicts occurred. The integration tree at `0bb2d1b` is byte-identical to `b70ed19`. `origin/main` is an ancestor of the integration branch, and `git diff --check` passes. Later hardening work should start from this baseline and remain in isolated worktrees until integration.

## Verification

Engine: `/home/flax/bin/godot`, version `4.4.1.stable.official.49a5bc7b6`. Tests use isolated XDG data/config/cache directories via the existing error-sensitive runner.

Clean-worktree attempt:

```bash
GODOT=/home/flax/bin/godot python3 tools/run_godot_tests.py \
  test_sprint20_ads_submenu_and_remapping test_keybinding_restart \
  test_sprint19_zoom_fade_cursor test_ads_pitch_alignment \
  test_squad_radial_wheel test_keybindings_modal test_elevator_replication \
  --output /tmp/tdc-hardening-agent1 --timeout 30
```

Result: failed as expected for six suites with unresolved global `class_name` types because no Godot import cache existed. `test_keybinding_restart` passed. This confirms a clean-checkout bootstrap gap, not a controls regression. The runner correctly returned nonzero and did not treat printed success as sufficient.

Explicit bootstrap:

```bash
/home/flax/bin/godot --headless --editor --path client --quit
```

Its exit code was zero, but `/tmp/tdc-hardening-agent1-import.log` contains `Parse Error: Busy` loading `DeployableShield.tscn:37` and an ObjectDB leak warning. These diagnostics are an unresolved clean-import issue, likely involving the cyclic script/resource graph. They must not be hidden by CI or reported as a clean bootstrap.

After import generated class/resource caches, the same seven-suite command with output `/tmp/tdc-hardening-agent1-imported` passed all seven suites with no error-sensitive runner failures:

- `test_sprint20_ads_submenu_and_remapping`
- `test_keybinding_restart` (separate writer and reader processes)
- `test_sprint19_zoom_fade_cursor`
- `test_ads_pitch_alignment`
- `test_squad_radial_wheel`
- `test_keybindings_modal`
- `test_elevator_replication` (separate native multiplayer contexts)

## Limitations and handoff

- The baseline recovery is complete; overall multiplayer stabilisation is not.
- QA/architecture must repair or explicitly handle clean-checkout import initialization and investigate the busy-resource diagnostics before declaring CI green.
- Preserved mission, map and restart changes still require full regression/integration verification by their specialist owners.
- These tests establish controls, persistence and elevator regression behavior headlessly. They do not establish graphical quality, combat authority or a complete human multiplayer session.
- No GitHub push or PR merge was performed by this agent. The lead owns final sequential integration and delivery.
