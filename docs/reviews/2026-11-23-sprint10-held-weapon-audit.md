# Sprint 10 — Held-weapon audit

**23 November 2026.** Reviewed the six existing player-held visuals from the merged Sprint 9 gameplay baseline, `0cba597`, in SGC UAT and Goa’uld Infiltration. All six loaded their textured GLBs in both missions and in a clean Linux release pack. The review identifies two presentation issues for owner review: the M249's fixed extended bipod dominates its aimed silhouette, and both sidearms appear very small in the downed camera.

## Mission views

The fixture selects a real operative class, loads the mission through the lobby and equips the weapon through its class slot. Images use the current aim state, camera, HUD, scene lighting and D-015 matte overrides. Goa’uld Infiltration uses the existing greybox insertion lighting. Procedural bodies can enter the foreground with this camera, particularly when aimed offworld. Close views use the existing diagnostic camera.

| Weapon and operative | SGC UAT | Goa’uld Infiltration |
|---|---|---|
| M9, O’Neill | [Aim](sprint10-captures/sgc-m9-aim.png) | [Aim](sprint10-captures/offworld-m9-aim.png) |
| P90, O’Neill | [Aim](sprint10-captures/sgc-p90-aim.png) | [Aim](sprint10-captures/offworld-p90-aim.png) |
| MP5SD, Carter | [Aim](sprint10-captures/sgc-mp5-aim.png) | [Aim](sprint10-captures/offworld-mp5-aim.png) |
| M249, SG3 Heavy | [Aim](sprint10-captures/sgc-m249-aim.png) · [Close](sprint10-captures/sgc-m249-close.png) | [Aim](sprint10-captures/offworld-m249-aim.png) · [Close](sprint10-captures/offworld-m249-close.png) |
| Staff, Teal’c | [Aim](sprint10-captures/sgc-staff_weapon-aim.png) | [Aim](sprint10-captures/offworld-staff_weapon-aim.png) |
| Zat, Carter | [Aim](sprint10-captures/sgc-zat-aim.png) | [Aim](sprint10-captures/offworld-zat-aim.png) |

**M249 disposition.** Keep the current realistic model for review. Its legs are fused into the source mesh and the loaded visual spans 0.467 m across them. The open V is conspicuous beside the reticle in both aimed views. Sprint 10 mesh acceptance remains open on this point. If the owner rejects the carried silhouette, source or author a carried configuration with documented provenance and compare it against these same views before swapping the visual. The final SG3 Heavy grip and animation review belongs to Sprint 25.

## Downed sidearms

The fixture damages the operative and lets the normal downed handler select slot 2. It suppresses the one-operative mission-loss callback so the downed HUD and camera remain visible. O’Neill and SG3 Heavy draw the M9. Carter and Teal’c draw the Zat. In these views the HUD identifies the sidearm while its end-on mesh is small and difficult to identify. Review sidearm readability with the relevant grip and pose in Sprints 22–25.

| Operative | Slot 2 | SGC UAT | Goa’uld Infiltration |
|---|---|---|---|
| O’Neill | M9 | [Downed](sprint10-captures/sgc-oneill-recon-downed.png) | [Downed](sprint10-captures/offworld-oneill-recon-downed.png) |
| Carter | Zat | [Downed](sprint10-captures/sgc-carter-tech-downed.png) | [Downed](sprint10-captures/offworld-carter-tech-downed.png) |
| Teal’c | Zat | [Downed](sprint10-captures/sgc-tealc-jaffa-downed.png) | [Downed](sprint10-captures/offworld-tealc-jaffa-downed.png) |
| SG3 Heavy | M9 | [Downed](sprint10-captures/sgc-sg3-heavy-downed.png) | [Downed](sprint10-captures/offworld-sg3-heavy-downed.png) |

## Runtime cost

Godot 4.4.1 queried the loaded mesh surfaces and each material's unique texture resources. Cold and cached times are wall-clock samples for adding a weapon in a fresh headless process and then adding another copy of the same weapon. The second copy shared meshes and materials in every case.

| Weapon | Triangles | Materials / surfaces | Surfaces with LODs | Unique maps | Decoded mip chains | Cold / cached |
|---|---:|---:|---:|---|---:|---:|
| M9 | 10,185 | 2 / 2 | 0 | 6 × 1024² | 24.00 MiB | 60.871 / 0.064 ms |
| P90 | 38,083 | 1 / 1 | 0 | 3 × 1024² | 12.00 MiB | 72.290 / 0.037 ms |
| MP5SD | 10,669 | 2 / 2 | 0 | 6 × 2048² | 117.33 MiB | 415.050 / 0.038 ms |
| M249 | 13,328 | 1 / 1 | 0 | 3 × 1024² | 12.00 MiB | 56.338 / 0.048 ms |
| Staff | 9,216 | 1 / 1 | 0 | 4 × 1024² | 16.00 MiB | 57.535 / 0.050 ms |
| Zat | 8,448 | 1 / 1 | 0 | 4 × 1024² | 16.00 MiB | 52.097 / 0.038 ms |

All six currently render LOD0. Every image has a full mip chain, 11 levels at 1024² and 12 levels at 2048² including the base image. Together they account for 197.33 MiB of decoded image data when cached in one process. This figure describes the decoded byte count. GPU residency and total process memory require separate measurements. The MP5SD stays within its approved 128 MiB exception and accounts for about 59% of the total. It also has the longest cold load in the checkout and exported pack. The other five fit the provisional 64 MiB per-weapon target. This establishes a baseline for any later resolution or LOD changes. [Texture contract](../assets/texture-import-contract.md).

On the RTX 3060 at 1440 × 900 with Forward+, 60-frame samples from the stock game camera gave median ranges of 6.55–10.81 ms in SGC UAT and 1.61–2.30 ms in Goa’uld Infiltration. Approximate 95th percentiles were 14.43–17.41 ms and 9.85–12.21 ms respectively. These are whole-scene observations at the review spawns. Exact draw counters, frame interval summaries, weapon-local visual bounds, map slots, pack hash and release timings are recorded with the capture inventory. [Measurement record](sprint10-measurements.json).

## Coverage ledger

All six rows passed the runtime mesh, cache, packaged model and attribution checks. Sprint 25 closes the playable palm-contact and weapon-anchor verification for both weapon slots of all four classes. The owner accepted the Sprint 25 fit with the limitations recorded below. The original mesh and material reviews retain their own status. [Sprint 25 matrix and captures](2026-11-26-sprint25-sg3-heavy.md).

| Asset and live slot | Provenance and recipe | Fallback | Pending review |
|---|---|---|---|
| M9, O’Neill and SG-3 Heavy sidearm | `emran.bayati`, CC BY 4.0. [Intake](../assets/intake/beretta_m9.json) · [Recipe](../assets/intake/beretta_m9/recipe.json) | Two procedural boxes | Both roles’ grips and downed selection verified. Downed camera readability remains open. |
| P90, O’Neill primary | Rotuma, CC BY 4.0. [Intake](../assets/intake/p90.json) · [Recipe](../assets/intake/p90/recipe.json) | Procedural bullpup | Grip and reload posture verified. LOD0 remains the highest triangle count in this set. |
| MP5SD, Carter primary | WillyG99, CC BY 4.0. [Intake](../assets/intake/mp5sd.json) · [Recipe](../assets/intake/mp5sd/recipe.json) | Procedural SMG | Grip and reload posture verified. The 2K exception and cold-load cost remain recorded above. |
| M249, SG-3 Heavy primary | AK / skaf13, CC BY 4.0. [Intake](../assets/intake/m249.json) · [Recipe](../assets/intake/m249/recipe.json) | Procedural receiver, drum and barrel | Grip and reload posture verified. The fixed extended bipod remains on the accepted Sprint 25 fit. |
| Staff, Teal’c primary and both Jaffa variants | Original project tri-vane staff. [Work order](../assets/intake/staff/work-order.json) · [Recipe](../assets/intake/staff/pack.json) | Existing procedural staff visuals | Moving player grips and muzzle verified. The NPC evidence remains in the [Sprint 8 review](2026-11-23-sprint8-staff-intake.md). |
| Zat, Carter and Teal’c sidearm | Original project loop-frame Zat. [Work order](../assets/intake/zat/work-order.json) · [Recipe](../assets/intake/zat/pack.json) | Procedural box and sphere | Both roles’ grips and downed selection verified. Downed camera readability remains open. |

Distributed attribution and the full applicable licence texts are accessible in the lobby and checked against the maintained manifest. [Attributions](../../credits/ATTRIBUTIONS.md).

## Reproduce

```sh
godot --headless --path client --script res://tests/support/held_weapon_audit.gd
godot --path client --script res://tests/support/weapon_visual_review.gd -- --audit --weapon m249 --mission sgc_uat --downed
```

The visual helper writes the normal camera, aim, after-aim, close and source-metallic views in the ignored `build/asset-review/sprint10/` tree. Use a primary with `--downed` to capture the actual switch to its class sidearm. For the packaged check, use the Linux release template and export into an empty directory. Run the audit, credits and six imported-visual scripts with the exported executable and `--main-pack game.pck` from that directory. The measured 30,543,616-byte pack passed all eight checks, including the distributed credits and both full licence texts.

Sprint 11 is the next planned slice, the mounted and deployable M2 visual. The current held-weapon art decisions remain recorded above. [Sprint programme](../plans/asset-vertical-slices.md).
