# Sprint 20 validation

> Historical record: findings, branch states, counts and environment limits below apply to the stated baseline. See the [current documentation index](../README.md) and [testing guide](../TESTING.md) for present behavior and commands.

Validated with Godot 4.4.1 on 8 November 2026, based on Sprint 19 takeover commit `0031510`.

`python3 tools/run_godot_tests.py --output /tmp/tdc-release-validation --timeout 30` passed all 11 suites. The persistence suite launches a writer and a separate reader process using isolated user data. The runner rejects engine/script errors, assertions, leaks and timeouts even when a test exits zero.

Coverage includes canonical action/UI binding coverage, keyboard and all requested mouse inputs, physical codes/modifiers, conflict swap/replace/cancel, invalid entries and file versions, save errors, default restoration, live prompt refresh, menu viewport bounds, ADS radial selection across all five slices/deadzone, look freeze/resume, locked target, duplicate release prevention, remapped weapon and actual interact input, focus cancellation and remote actor teardown isolation. Existing camera/AI/level suites remain green. Two-peer ENet elevator replication and continuous stair traversal remain green.

`node --test alignment-app/server/repoExport.test.js` passed both export security tests. JavaScript syntax, Python syntax and `git diff --check` passed.

A remapped interact event exposed duplicate elevator input handlers; interaction now routes once through the player controller. Deferred prompt registration uses weak references so short-lived remote nodes cannot cause calls with freed arguments.

No graphical display is available in this environment. Graphical playtesting of the wider spiral stairs, controls-menu appearance and combat feel remains outstanding; the automated layout check verifies viewport bounds only. No claim of visual UAT is made.
