# Agent 4 — Alignment API security and document safety

> Historical record: findings, branch states, counts and environment limits below apply to the stated baseline. See the [current documentation index](../README.md) and [testing guide](../TESTING.md) for present behavior and commands.

Worktree: `/tmp/tdc-hardening/backend`, branch `stabilisation/backend`. Implementation starts from recovered baseline `0bb2d1b` on current main. No gameplay files changed.

## Confirmed defects and evidence

| Severity | Defect | Evidence / root cause | Correction |
| --- | --- | --- | --- |
| P1 | Mutation routes accept unauthenticated requests | Baseline temporary-server probe: unauthenticated loopback `POST /api/vote` returned 200 | Every API operation except minimal health requires bearer authentication; no localhost bypass |
| P1 | Sensitive export trusts localhost | Same baseline probe: unauthenticated loopback export returned 200 | Explicit API authentication; Git operations additionally require a distinct operator token and opt-in configuration |
| P1 | Ordinary voting destroys maintained documents | Baseline vote changed root GDD sentinel; baseline export changed root README sentinel | Fixed `docs/generated/` destination; maintained documents never become export targets |
| P1 | Invalid IDs/types can create malformed state | Original rank/vote accepted unknown option/member IDs and wrote arbitrary member keys; non-string fields reached `.trim()` | Bounded payload schemas, known IDs, reserved-key rejection, candidate-state mutation before atomic persistence |
| P1 | Git export can commit unrelated staged work and implicitly push | Original helper used ordinary `git commit`; export always attempted push after commit | Feature-branch guard, literal arguments, fixed generated paths and `git commit --only`; separate explicit push flag |
| P2 | CORS accepts arbitrary sites; errors/UI fail silently | Original unconditional CORS and mutation handlers ignored non-2xx responses | Exact configured origin allowlist and authenticated browser API helper with visible errors |

Baseline reproduction copied the four server modules from `0bb2d1b` into an isolated temporary repository and ran the original server. Output: `unauthenticatedVoteStatus=200`, `normalVoteOverwroteRootGDD=true`, `unauthenticatedLoopbackExportStatus=200`, `exportOverwroteRootReadme=true`. No actual project state or maintained documents were changed. Probe: `/tmp/tdc-backend-baseline-probe.js`; evidence: `/tmp/tdc-backend-baseline-probe.log`.

## Implemented contract

- `createApp(options)` creates an isolated Express application without starting a listener when imported. Native HTTP tests inject temporary repository/data directories.
- `ALIGNMENT_API_TOKEN` must contain at least 32 characters. If absent, startup creates a stable, ignored, mode-0600 `alignment-app/server/data/.api-token`. `npm run auth-token` is an explicit local operator command; no HTTP bootstrap returns secrets. Do not commit or publish the token.
- The React login accepts the operator token and keeps it in tab-local session storage. All API requests attach it through one helper. Tokens are not put in URLs or logs.
- Defaults bind API and Vite to loopback. For a tunnel or remote host, configure `ALIGNMENT_HOST` and exact comma-separated `ALIGNMENT_ALLOWED_ORIGINS`; supply the access token to authorized users and use HTTPS. Requests without an Origin still require authentication.
- API bodies are JSON, limited to 64 KiB, with bounded fields and validated IDs. Unknown properties and dangerous member IDs are rejected. Existing stored data loads unchanged; malformed stored JSON stops startup and remains available for recovery rather than being reset silently.
- Authenticated ordinary votes/comments still update planning snapshots, but only in `docs/generated/`. Root README/GDD/roadmap/contract and implementation history are never generation targets. Symlink redirects are rejected; writes use unique temporary files and atomic replacement.
- Ordinary authenticated exports only write generated files. Git operations require `ALIGNMENT_ALLOW_GIT_EXPORT=1` plus a distinct `ALIGNMENT_EXPORT_TOKEN` of at least 32 characters, sent as `X-Alignment-Export-Token` in addition to API authorization. Git commits refuse main/master/detached HEAD. Push requires an explicit `gitPush: true` together with `gitCommit: true`; the UI defaults to export without Git and offers an explicit local commit option.
- The editor token grants shared team editing authority, including reset/delete. The API is not an individual-user identity/RBAC service. The separate Git token is an operator capability.

## Validation

Environment: Node 24.19.0, npm 11.17.0 on Linux; package minimum is Node 22.12.0. No dependencies added.

Commands:

```sh
npm ci --prefix alignment-app --no-audit --no-fund
node --test alignment-app/server/*.test.js
node --check alignment-app/server/index.js
node --check alignment-app/server/auth.js
node --check alignment-app/server/validation.js
npm run build
/usr/bin/git diff --check
```

All 14 Node tests pass. Coverage includes every unauthorized mutation route and DELETE preserving byte-identical state, exact CORS/tunnel configuration, malformed JSON/size/types/IDs/prototype keys, voting/ranking/comments/member management/reset persistence, existing repository-state compatibility, safe Unicode member names, final-member protection, reload persistence, manual-document sentinels, symlink/corrupt-state handling, private token storage, browser request/error handling, Git privilege configuration, literal malicious message arguments, and a real temporary Git repository proving unrelated staged changes remain staged after export.

Frontend production build succeeds. Logs: `/tmp/tdc-backend-tests.log`, `/tmp/tdc-backend-build.log`, `/tmp/tdc-backend-npm-ci.log`.

Remaining limitations: browser layout and human authentication/tunnel workflow have not received graphical UAT. No external tunnel or real remote Git push was performed. HTTP tests use local fixtures, including an injected Git runner for explicit push authorization. Git subprocess errors return a generic API failure; a failed optional Git operation does not roll back already generated planning snapshots. API credentials must be handled by the operator and protected with HTTPS outside loopback.
