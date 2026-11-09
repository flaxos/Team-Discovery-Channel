# Agent 5 — test infrastructure and CI

> Historical record: findings, branch states, counts and environment limits below apply to the stated baseline. See the [current documentation index](../README.md) and [testing guide](../TESTING.md) for present behavior and commands.

Baseline: `62d15bf`, Godot `4.4.1.stable.official.49a5bc7b6`, Python 3.11. Work is limited to runner/CI infrastructure; no gameplay or existing game-test assertions were changed.

## Confirmed defects

| Severity | Evidence | Correction |
| --- | --- | --- |
| P1 | Old runner selected only 21 of 42 `client/tests/test_*.gd` files without a complete inventory. | Full profile discovers every test file; none is silently excluded. Explicit fast/multiplayer profiles report all unselected names. New multiplayer tests are discovered by naming. |
| P1 | Fresh worktree lacks Godot global-class import cache. | Strict runner performs an editor import before tests and checks output as well as exit status. |
| P1 | First actual editor import exited zero while logging DeployableShield `Parse Error: Busy` and ObjectDB leaks. | Runner rejects the import and does not pretend the game tests ran. Gameplay root cause belongs to Combat/Architecture; this infrastructure does not suppress it. |
| P1 | No CI workflow or failure-reporting contract tests existed. | Added independent contract tests, official pinned-engine installation, PR/push/nightly/manual workflows and retained diagnostic artifacts. |

## Commands and evidence

- `python3 -m unittest discover -s tools/tests -v`: **9/9 passed**. Includes a deliberate assertion followed by “ALL PASSED” with process exit zero; the runner correctly exits 1. Other cases cover failed zero-exit import, crash, timeout, wrong engine, ANSI error output, complete inventory and isolated two-process persistence phases.
- `python3 tools/run_godot_tests.py --godot /home/flax/bin/godot --profile full --output /tmp/tdc-qa-clean-baseline --timeout 20`: **failed at project import**, with the confirmed errors above. Logs and JSON/JUnit reports retained there.
- Diagnostic follow-up: `python3 tools/run_godot_tests.py --godot /home/flax/bin/godot --profile full --skip-import --output /tmp/tdc-qa-baseline-full --timeout 12`. This deliberately does not constitute clean-checkout acceptance; full baseline inventory was still running at this initial handoff. Progress: `/tmp/tdc-qa-baseline-progress.log`; final `summary.json` records exact per-suite outcomes when complete.
- `python3 tools/run_godot_tests.py --profile full --list`: **42 existing test files**, with no full-profile exclusions. Inventory saved at `/tmp/tdc-qa-inventory.txt`.
- `git diff --check`: passed.

## CI contract

`.github/workflows/validation.yml` runs independent runner-contract, Godot fast/multiplayer/full, and Alignment API/build jobs. Godot is the official **4.4.1** Linux x86_64 release; the installer checks the archive against the release's published SHA512 checksum before execution. CI uses Python **3.11**, Node **22.14.0**, Ubuntu **22.04**, read-only repository permissions and no deployment credentials. It retains stdout/stderr, engine logs, JSON and JUnit reports, and backend/build logs for 14 days, including failed jobs.

The complete profile selects every `test_*.gd`; fast is the small controls/gate/menu smoke set, and multiplayer includes existing network/authority suites plus discovered new multiplayer/combat/state test names. `test_keybinding_restart` launches writer and reader separately with shared temporary user data. No test is intentionally excluded from the full profile. Future non-test helper scripts should not use the `test_*.gd` naming contract.

## Remaining limits

- Workflows have been authored and runner contracts verified locally; hosted GitHub Actions execution requires the final branch to be pushed and a PR opened by the lead.
- The official checksum download returned HTTP 504 in this environment, so actual CI installer download/execution remains unverified here. The installer fails closed on download/checksum failure.
- Full baseline results contain confirmed failures and are not represented as green. Agents 2/3 own implementation/test-fixture fixes; root must rerun the full strict profile after integration, from a clean `.godot` cache.
- Backend's new HTTP tests and combat/state new suites are not yet present in this initial infrastructure commit. CI globs/discovery include them once integrated.
- No headless result establishes graphical quality, combat feel, LAN latency tolerance or human playtest acceptance.
