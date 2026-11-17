# Sprint 7: MP5SD intake and distributed credits

Started 18 November 2026 from `ad7320d` (planning PR #78, based on merged Sprint 6 `7982e2b`). Branch `feat/sprint7-mp5-intake`. **Sprint remains in progress: the selected model archive has not been acquired.** No faithful MP5SD replacement or owner art acceptance is claimed.

## Slice and acquisition

One textured MP5SD for the existing Carter loadout in `sgc_uat` and an offworld encounter. Preserve damage 20, 800 rpm, 30/150 ammunition, reload 1.7 s, noise radius 6 m and `MuzzlePoint (0, 0.01, -0.36)`. The current `mp5_silenced.glb` is Kenney’s generic `uziLongSilencer`, not the requested model. Existing D-015 metallic-zero treatment remains unchanged. Rig/grip work belongs to later character slices.

Selected [MP5SD (Silenced MP5), WillyG99](https://sketchfab.com/3d-models/mp5sd-silenced-mp5-2b96ccb2dc51496e93f41734663bcadf): creator-described modelling/texturing, 4K maps, separate sight; public API confirms downloadable and CC BY 4.0, with 12,085 declared faces. Preview is a substantially stronger fidelity lead than the original 2,210-face candidate. Archive topology, dimensions, maps, licence consistency and actual runtime quality are still uninspected. [Listing evidence](../assets/intake/mp5sd/listing-evidence.json), [draft work order/search comparisons](../assets/intake/mp5sd/work-order.json).

Eligible alternatives: Ecler (12,955 declared faces, two texture sets), TORI106 (9,307). MatZaj is nondownloadable with no licence returned; Karnaval uses Free Standard rather than the playbook’s CC0/CC BY route; Wheezy.Media explicitly forbids distributing model/texture files by themselves; game-extracted models are excluded. No paid purchase or generated substitute was made.

### Owner download card

| Field | Required action / evidence |
|---|---|
| Asset / role | WillyG99 MP5SD; Sprint 7 Carter primary |
| Source | [Exact creator listing](https://sketchfab.com/3d-models/mp5sd-silenced-mp5-2b96ccb2dc51496e93f41734663bcadf) |
| Licence | CC BY 4.0 public metadata; inspect archive for consistent terms before insertion |
| Format | Original-format archive including all 4K textures; retain any README/licence and supplementary source files |
| Cost / route | Free listing, account download. Official `/v3/models/2b96ccb2dc51496e93f41734663bcadf/download` returned HTTP 401 without an account session. Browser access host is unavailable |
| Owner location | `~/Downloads/<original archive name>`; reply with filename |
| Agent staging | Copy to `/tmp/tdc-asset-intake/mp5sd/`; preserve the owner’s original |
| Still required | Archive/hash inspection, recipe, measured placement, lossless maps, actual imported combat/multiplayer views, clean exported model and owner review |

This is a concrete acquisition blocker, not a request to approve unfinished art. Independent intake/credit work continues.

## Implemented infrastructure

- `tools/asset_work_order.py` validates Draft 2020-12 plus finite numbers, bounds, decreasing LOD limits, unique anchors and existing references. `asset_intake.py --work-order` requires a ready request, records request/schema hashes and enforces declared triangle/material limits. Drafts and rigid requests that contain rigs/clips are refused. This cannot certify licences, true scene bounds, clip quality or art.
- `tools/requirements.txt` pins `jsonschema==4.23.0`; CI installs it for tooling checks. Legacy inspection without a work order retains its existing interface.
- `tools/sync_asset_credits.py` generates a referenced Godot resource from the maintained attribution manifest and full licence files. CI rejects stale output or missing model credits/modification notices/licences. Current coverage is all seven shipped GLBs; new asset types must extend the coverage rule when first consumed.
- The lobby’s **Community Credits & Licences** button opens readable offline attribution and selectable full legal texts. Resource export includes them without raw-text include filters or paths outside the PCK.
- The previous CC0 file was incomplete (3,099 characters). Replaced with the complete [official CC0 text](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt), 7,048 bytes, SHA-256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`. Existing CC BY file already matches the [official text](https://creativecommons.org/licenses/by/4.0/legalcode.txt), SHA-256 `9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411`.

## Verification so far

- Tooling under the pinned dependency environment: **60 tests pass**, including work-order/intake failure paths and credit coverage/staleness/full-text checks.
- Strict targeted Godot checks: `test_asset_credits` passes real lobby open/select/close and exact licence content; `test_asset_packer_maps` passes a real opaque GLB/PNG round trip, DirectX green flip and R=AO/G=roughness/B=metallic reference pixels. Initial credits check exposed the truncated CC0; corrected and rerun. Alpha/skin support is not claimed.
- Forward+ / RTX 3060 captures from `asset_credits_review.gd` inspected for readability, with an improved read-only text colour. Captures at the default 1280 × 720: [credits](sprint7-captures/credits.png), [licence reader](sprint7-captures/licence.png). Build evidence: `build/asset-review/credits/`. This is credit UI evidence, not MP5 art acceptance.
- Clean Linux 4.4.1 release PCK, launched from `build/asset-review/sprint7-export/`: `test_asset_credits: PASS models=7 licences=2`. Raw credited model files and both exact legal texts are reachable inside the pack. PCK 10,960,960 bytes. Temporary export preset restored exactly; no project copy created.
- Current Kenney MP5 SGC capture retained under `build/asset-review/mp5/` for comparison. The review helper now selects Carter for MP5 captures and prints weapon-local bounds/muzzle measurements. Capturing a stand-in does not complete the slice.

The planning PR #78’s hosted full run failed before this implementation on `test_mission_alert_multiplayer`: the client read an empty runner marker (`get_node("")`). The fixture published the file at open time before its data was written. This change makes that one fixture marker publish by rename after closing the complete file. No gameplay/alert logic changes; the focused fixture is rerun after the full profile.

Full regression and hosted results will be recorded against the delivered change. Actual imported-MP5 tests, four-operative acceptance, export/cost and art remain pending acquisition; old mesh tests cannot establish them.

## Initial coverage ledger

Expand rows to concrete scene/slot variants in their consuming sprint. No category below is declared complete.

| Asset ID / scene | Current source / presentation | Technical / art state | Remaining work / sprint |
|---|---|---|---|
| `mp5` / Carter | Kenney stand-in; WillyG99 selected, unacquired | Existing fallback only / new art pending | Archive → measured recipe/wrapper → combat/export; 7, final grip 23 |
| `m9` / players | emran.bayati realistic import | Integrated / art pending | Mesh/material audit 10, player grip matrix 22–25 |
| `p90` / recon | Rotuma realistic import | Integrated / art pending | Audit 10, grip 22 |
| `m249` / heavy | AK/skaf13 realistic import | Integrated, fused extended bipod / art pending | Bipod/mesh audit 10, grip 25 |
| `staff_weapon` / Jaffa and player | Procedural | Existing gameplay / replacement pending | 8, grips 20/24 |
| `zat` / tech and Jaffa player | Procedural | Existing gameplay / replacement pending | 9, grips 23/24 |
| `DeployableTurret` / M2 | Procedural | Existing gameplay / replacement pending | 11, gunner handling 25 |
| C4 / claymore / smoke / shield | Existing procedural kit | Existing gameplay / replacement pending | Enumerate carried/deployed variants and finish 12 |
| Armoury crates | Poly Haven Plastic Crate 02 | Integrated / art pending, scene cost open | 15 |
| Gate | rossrobotics selected ring/seven inserts | Integrated with recorded evidence gap / art pending | 14/27; preserve approved scope |
| Legacy P90 file | Kenney retained source, no longer active P90 | Packaged and credited | Retain provenance; do not replace realistic P90 with it |
| SGC architectural regions/slots | Native map, dimensioned placeholders | Existing routes / art incomplete | Discover full live slot ledger per region; 13–18 |
| Airman / Jaffa / playable team | Procedural bodies | Existing controllers, no humanoid adapter / art incomplete | 19–25 |
| Civilians | No presentation actor | Not implemented | 26 |
| Offworld rooms / mothership | Sprint 6 corridor subset; other art incomplete | Native geometry preserved / art pending | 27–34; integrated acceptance 35 |

## Resume after the archive arrives

Inspect without executing archive code, record hashes/terms, choose source nodes/maps and measure orientation/bore in Godot. Resolve this draft request’s bounds/anchors/evidence before intake. Use PNG for data maps, compare source normals under light and fit the model to the unchanged muzzle. Finish `test_imported_mp5_visual`, cache/fallback/cost, Carter SGC/offworld captures, four-operative listen/dedicated and travel/late/retry checks, clean exported-model proof and review. Add only the acquired/prepared model to attribution, regenerate credits and rerun relevant checks. Do not start Sprint 8 automatically.
