# Alignment & Voting app

This is the separate React/Vite planning app and Express API in `alignment-app/`. Godot game networking does not depend on this service.

## Development and production

`alignment-app/package.json` requires Node **22.12.0 or later**; CI uses 22.14.0. From the repository root:

```sh
npm ci --prefix alignment-app
npm run dev
```

The frontend uses port **5173**; the API defaults to **127.0.0.1:4100**. Open the frontend and enter the access token obtained locally with:

```sh
npm --prefix alignment-app run auth-token
```

The browser keeps the token in the tab session. Use its disconnect control to clear access. Do not commit tokens or paste them into issue/PR logs.

For a built frontend served by Express:

```sh
npm run build
npm start
```

The server serves `alignment-app/dist/` when it exists. API routes other than `/api/health` require `Authorization: Bearer <access-token>`, including state and compile reads. Mutations require JSON and validated bounded payloads. Loopback requests do not bypass authentication.

## Configuration

| Environment variable | Purpose |
| --- | --- |
| `PORT` | API port, default 4100. |
| `ALIGNMENT_HOST` | Bind address, default `127.0.0.1`; set deliberately for non-loopback access. |
| `ALIGNMENT_DATA_DIR` | State/token directory, default `alignment-app/server/data/`. |
| `ALIGNMENT_API_TOKEN` | Optional configured access token, at least 32 characters; otherwise a local `.api-token` is created with mode 0600. |
| `ALIGNMENT_ALLOWED_ORIGINS` | Comma-separated exact browser origins. Defaults cover localhost/127.0.0.1 on 5173 and 4100. |
| `ALIGNMENT_ALLOW_GIT_EXPORT` | `1` enables the separate Git-export capability; disabled by default. |
| `ALIGNMENT_EXPORT_TOKEN` | Distinct token of at least 32 characters required when enabling Git export. |

For a remote browser/tunnel origin, configure that exact origin and provide the API token. The `npm run tunnel` helper forwards port 4100 via an installed `cloudflared`; it does not configure authentication or allowed origins. No operational tunnel acceptance is implied by local tests.

## Documents and Git export

Successful authenticated mutations and explicit exports write only these planning snapshots:

- `docs/generated/BOOTSTRAP_PROMPT.md`
- `docs/generated/GDD.md`
- `docs/generated/ROADMAP.md`
- `docs/generated/TEAM_CONTRACT.md`

They describe vote choices, not delivered game features. Root project documents and manual developer notes are maintained separately and preserved. Review generated changes before committing them.

`POST /api/export-to-repo` accepts `gitCommit`, `gitPush` and an optional `commitMessage`. Ordinary export needs the API bearer token. Git commit/push additionally requires enabled Git export and `X-Alignment-Export-Token`; it must run on a feature branch. Generated-document commits use only those four paths, excluding unrelated staged files. Push requires an explicit `gitPush` request and `gitCommit`.

Run API tests and the frontend build using the [testing guide](TESTING.md#other-repository-checks). Do not infer hosted deployment or external-export acceptance from local API fixtures.
