# Sprint 21 — Horus Jaffa

Fit one falcon helmet and armour finish to the existing shock guard. Goa’uld Infiltration already requests shock guards in the second alarm reinforcement wave at the barracks. Use that encounter and the standard Serpent patrol for the comparison. The preview inherits the Sprint 20 guard rig from PR #99. [Mission definition](../../client/resources/missions/goauld_infiltration.tres) · [Sprint 20 preview](2026-11-25-sprint20-serpent-jaffa.md) · [PR #99](https://github.com/flaxos/Team-Discovery-Channel/pull/99).

The existing shock guard uses a 2.0 m high, 0.5 m radius capsule. Its authored helmet placeholder reaches 2.175 m. The awareness marker sits at 2.45 m. Fit the hooked beak and swept crown below that marker and check the base of the helmet against the collar and shoulder plates while turning, crouching and taking a hit. Compare front, rear and side profiles with the ready Serpent under the same light. Exercise the existing alarm wave, staff fire, stun and retry paths.

## Source search

| Candidate | Result |
|---|---|
| 3D-COLLECTION’s Horus print | Pinshape lists `horus_stargate.stl` at 97.3 MB under CC0, with an account required to download. Keep it as a geometry comparison lead. STL would require topology, UV and surface-material work before a game import. [Pinshape listing](https://pinshape.com/items/46689-horus-stargate-sg1-helmet-model) |
| lexruel’s Stargate Jaffa Helmet | The creator’s Sketchfab metadata identifies CC BY-NC 4.0. The playbook excludes the asset. [Sketchfab model](https://sketchfab.com/3d-models/stargate-jaffa-helmet-45e9dcaa597c4c23bcb0e829123df0ef) |
| Pigcraft’s Egyptian Falcon Guardian | The creator listing identifies CC BY 4.0. The 924,802-face upper body has no published rig or separately downloadable lightweight helmet. The description lacks a direct authorship statement. [Sketchfab model](https://sketchfab.com/3d-models/egyptian-falcon-guardian-a1ad4a9742da48789ca1ee856448f9d4) |
| 3Demon’s Horus helmet | The creator offers detailed printable geometry as a paid asset. Public source redistribution has not been established. [Creator listing](https://3d-mon.com/products/horus-helmet/) |

An original native helmet lets the rig, silhouette and encounter tests proceed. Its forward hooked bill, swept crest and cool visor contrast with the brass Serpent armour and hood. The generation work order records the PBR and fit requirements for the remaining art. [Helmet work order](../assets/intake/sprint21-horus-helmet-work-order.json).

## Playable preview

The native falcon headpiece uses 1,700 triangles and four shared, solid material surfaces. The shock guard uses blue-black armour with brass edging and a separate cyan visor surface. Its ready bounds in the guard frame measured 0.329 × 0.492 × 0.505 m, with the crown at 1.875 m below the awareness marker. The existing movement, aim, shot and health cues drive the rig. [Horus close-up](sprint21-horus-preview.webp).

To compare the two variants, run `godot --path client -- --serpent-preview --horus-preview` and start Goa’uld Infiltration. The second alarm reinforcement wave carries the Horus look. Both previews use ordinary guard simulation and the existing muzzle anchors. The local Mesa llvmpipe captures show the fitted community Serpent and the native Horus under the same light. [Front comparison](../../build/asset-review/sprint21-horus/comparison.png) · [Rear comparison](../../build/asset-review/sprint21-horus/rear-comparison.png) · [Crouch](../../build/asset-review/sprint21-horus/horus-crouch.png) · [Zat stun](../../build/asset-review/sprint21-horus/horus-stunned.png).

Five targeted suites passed on the normal game path. A two-peer listen session verified the Horus wave and shared head mesh on the host and late-joining client, then verified a fresh wave after retry. The local and exported Linux fixtures passed ready, crouch, staff fire, stun and death with the existing staff muzzle and visible Zat effect.

The local preview covers the source comparison and rig fit. Final material detail, full motion and distance review, and owner art acceptance remain open.
