# Sprint 25 — SG-3 Heavy and squad weapon handling

The slice starts from merged PR #101 at `25b4264` in the existing checkout. The playable target is one `sg3_heavy` appearance on the existing Airman skeleton in `Player.tscn`. The existing credited M249, M9, M2 and four field-kit exteriors supply the equipment. SGC UAT Base and the Goa’uld Infiltration travel mission supply lighting, deployment, recovery and peer views.

Acceptance covers ready, walk, sprint, turn, crouch, aim, firing, magazine reload or heat, slot switching, downed sidearm, crawl, drag, revive, and death across the four playable classes. M2 views cover deployment, the signed rear offset through receiver rotation, both hand contacts, authoritative fire and dismount. The previous front-of-gun report and the 0.467 m carried bipod span are the two starting review issues. [Sprint 15 M2 fix](2026-11-24-sprint15-sgc-armoury.md) · [M249 visual measurement](2026-11-16-ap1f-m249.md).

## Appearance and fit

Heavy uses olive fatigues with a low chest panel, two front ammunition pouches and a rear utility sleeve. Ten native meshes attach to the upper chest and follow the existing camera proximity fade. The uniform variants share the Airman fabric and normal maps. The generic masked face and original class identity remain in use. [Carrier scene](../../client/scenes/entities/SGCHeavyCarrier.tscn) · [Airman source and licences](2026-11-25-sprint19-airman-rig.md).

The M249 palm centres sit at the right grip and the left handguard. The M9 uses a compact two-handed brace while standing and a right-hand hold when downed. The arm solver keeps the palms on their targets through the ±45° pitch sweep. Magazine weapons share the existing cosmetic reload tilt. The staff and Zat use their existing heat behavior. Every cosmetic model still follows its weapon orientation outside reload, and the shot effect follows the visible muzzle. Firing origins, controller, camera, capsule and replication are unchanged. [M249 source and fit](2026-11-16-ap1f-m249.md) · [M9 source and fit](2026-11-16-ap1d-beretta-m9.md).

The chosen right and left palm centres sit 16.70 mm and 10.84 mm from the nearest fitted M249 vertices, and 4.83 mm and 11.18 mm from the nearest fitted M9 vertices. These model-space measurements complement the moving palm-to-target measurements below. [Grip reference points and mesh bounds](../../build/sprint25/heavy-grip-measurements.json).

| Existing credited model | SHA-256 |
|---|---|
| `sgc_airman.glb` | `a6af0b258f34b2c0a1d87339a65228306220a3bc89e5be2fc6d4ae449c0cdeff` |
| `m249.glb` | `d5e6a807aba10cb621293b18246ef60e8bbc0fec7c048487323764dc8311a0c7` |
| `beretta_m9.glb` | `17ce228acc90eb3a25dd43158c44db7a3b08ead5ef9dab3f1c865cf7be97436a` |
| `browning_m2.glb` | `364611bba23b5cb7ac3b39885a48c79ff6cebc810e991f116a5c7214af650041` |

## Squad and field-kit matrix

Both slots on all four actors in the live SGC scene pass ready, walk, sprint, turns in both directions, aim, crouch, firing from the original muzzle, magazine reload or heat, and switching. Every actor also passes downed sidearm selection and firing, self-crawl, drag, revive, stun, recovery and death. The movement fixture stages actor displacement and aim pitch so it can compare both palm contacts for each clip at a fixed step.

| Class | Primary peak palm gap | Secondary peak palm gap |
|---|---:|---:|
| O’Neill Recon | P90, 1.10 mm | M9, 1.10 mm |
| Carter Tech | MP5SD, 1.10 mm | Zat, 1.10 mm |
| Teal’c | Staff, 3.61 mm | Zat, 1.10 mm |
| SG-3 Heavy | M249, 0.01 mm | M9, 0.01 mm |

The Heavy fit shifts the M249 to the right of the carrier and brings the M9 forward. The clearance probe checks the weapon vertices against four carrier meshes at 392 pose-and-mesh samples per weapon. It found no M9 overlap. The seven M249 overlaps were confined to the first few frames of abrupt 63° turns, with a maximum measured depth of 21 mm at the right pouch. The adjustment prioritizes palm contact when the torso is still turning. [Carrier clearance measurements](../../build/sprint25/carrier-clearance.json).

The front-of-gun report did not reproduce. The previous Sprint 15 seat positioning holds through 25 samples of the full receiver turn. Heavy stays 1.0 m behind the live receiver, facing it with the carried weapon stowed. Both palms stay within 35 mm of the handle markers and the input heading and muzzle transform stay fixed in the test. Dismount restores the carried weapon. The mounted crouch moves around the rear position as the gun turns. Planted footwork while mounted remains open for motion review. [Sprint 15 positioning fix](2026-11-24-sprint15-sgc-armoury.md#m2-operator-positioning-follow-up).

Sprint 12's remote and timed C4 shell, claymore arming, smoke canister and cloud, and shield hit and collapse states retain their verified placement, cues, effect origins and removal. The listen and dedicated regressions confirm that props stay in their original world, stocks follow the operative through travel, a late joiner sees the deployed state and retry restores the starting stocks. M2 deployment uses Heavy’s existing gadget input. The placed field-kit items use the existing inventory actions. [Sprint 12 deployment ledger](2026-11-23-sprint12-field-kit.md) · [Sprint 10 held-weapon ledger](2026-11-23-sprint10-held-weapon-audit.md).

## Verification

The four-operative roster, M2 and field-kit fixtures each passed on listen and dedicated in the final six-suite rerun. The M2 sessions use four distinct classes. The server authenticates the remote deployment and fires from the existing marker. The owning client and every observer, including the replacement during gate travel, see the same mounted operator and aim past 90°. Both retries check the current visual loadouts. The retry after deployment also checks the empty deployment container on server and clients. The Python tools passed all 60 checks. [Final multiplayer results](../../build/sprint25/final-network/summary.json).

Both Linux packs booted under the Godot 4.4.1 release template. The Linux debug template loaded the same packs to run the scripted assertions. The standard pack passed the squad matrix, all six held-weapon wrappers, M2, field kit, SGC materials and distributed credits. The second pack excludes the Airman, M2, C4 and smoke GLBs and passed the procedural fallback checks. [Export results and pack hashes](../../build/sprint25/linux-export.log) · [Standard pack](../../build/sprint25/export/standard/game.pck) · [Fallback pack](../../build/sprint25/export/fallback/game.pck).

All 135 Godot suites passed across the strict full run and the isolated reruns. In the full run, the dedicated ring-transport fixture stopped after the return trip and both SGC result fixtures logged stale-node RPC errors during teardown. All three passed the isolated rerun. The full run uses `python3 tools/run_godot_tests.py --profile full --timeout 240 --output build/sprint25/godot-full` under the shared network lock. [Full Godot results](../../build/sprint25/godot-full/summary.json) · [Isolated rerun](../../build/sprint25/godot-retry/summary.json) · [Final squad matrix](../../build/sprint25/matrix-probe.log) · [Python results](../../build/sprint25/python.log).

## Owner art acceptance

The owner accepted Sprint 25 on 26 November 2026. The extended M249 bipod, brief pouch overlap on sharp turns, downed sidearm readability and mounted M2 footwork remain documented. Dedicated reload manipulation, field-kit hand actions and the rescuer’s hand pose during a drag remain follow-ups.

The local captures use Godot Forward+ on Mesa llvmpipe. Diagnostic cameras show fit in the actual missions. The stock-camera captures use the operative’s camera and HUD. Generated evidence is under the checkout’s ignored build directory. [Screenshot contact sheet](../../build/sprint25/captures/contact.jpg).

- [Squad primaries](../../build/sprint25/captures/sgc-squad-primaries.png) and [sidearms](../../build/sprint25/captures/sgc-squad-sidearms.png). Shows role readability and hand placement.
- The Heavy carrier shape and moving pose show the 0.467 m extended bipod and brief overlap on abrupt turns. [Normal SGC lighting](../../build/sprint25/captures/sgc-heavy-m249.png) · [SGC alarm lights](../../build/sprint25/captures/sgc-heavy-alarm.png) · [Offworld lighting](../../build/sprint25/captures/offworld-heavy-m249.png) · [SGC aim camera](../../build/sprint25/captures/sgc-heavy-m249-stock-camera.png) · [Rear carrier](../../build/sprint25/captures/sgc-heavy-carrier-back.png) · [Crouched M249](../../build/sprint25/captures/sgc-heavy-m249-crouch.png) · [Moving M249](../../build/sprint25/captures/sgc-heavy-running.webp).
- [Standing M9](../../build/sprint25/captures/sgc-heavy-m9.png), [downed close](../../build/sprint25/captures/sgc-heavy-m9-downed-close.png) and [downed stock camera](../../build/sprint25/captures/sgc-heavy-m9-downed-stock-camera.png). Both sidearm families remain hard to read in the stock downed camera.
- [Mounted M2 at start](../../build/sprint25/captures/sgc-heavy-m2-start.png) and [after a 145° turn](../../build/sprint25/captures/sgc-heavy-m2-turned.png). The views show the crouch, hands and lower-body pose.
