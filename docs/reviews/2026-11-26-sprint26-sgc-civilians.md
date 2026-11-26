# Sprint 26 — SGC civilians

Sprint 26 uses the merged Sprint 25 baseline `b8497a4` on `feat/sprint26-sgc-civilians`. SGC UAT Base and SGC Defense inherit the three authored marks in `GateRoom/CivilianStations`. Their furniture and region bounds come from the existing SGC layout and retained prop scenes. [Sprint 25 merge](https://github.com/flaxos/Team-Discovery-Channel/pull/102) · [Native station markers](../../client/scenes/main/GateRoom.tscn) · [SGC map contract](../maps/sgc.md).

| Role | Authored station | Foot position in metres | Margin to the nearest same-floor passage |
|---|---|---|---:|
| Laboratory | Level 28 east research bench, near the microscope | `(33.35, 0, 53)` | 8.86 m |
| Medical | Level 26 staging workbench, on the medical supply route | `(10, 11, 23.7)` | 2.61 m |
| Administration | Level 27 command desk, on the side away from the defense terminal | `(13.1, 5.5, 16.6)` | 4.61 m |

The starter probe verifies the expected live region, floor contact, standing capsule clearance, navigation proximity and facing toward the furniture in both SGC scenes. It also verifies that the civilian station branch is exclusive to the SGC worlds. The passage margin subtracts half the authored connection width from the distance to its nearest route point. Project import, the SGC map contract and SGC UAT mission selection passed. [Probe and measurements](../../build/sprint26/stations.log) · [Live authoring catalogue](../../build/sprint26/catalogue.json) · [Kickoff test results](../../build/sprint26/kickoff-tests/summary.json).

## Appearances and work cycle

The lab technician wears a light jacket and gloves and handles a clipboard at the east bench. The medic wears teal workwear with a stethoscope and checks a sample case. The administrator wears a blue shirt, collar and tie and reads an open folder. The lab fixture keeps the west ROM approach free, and the administrator stands clear of the defense terminal. [Lab and medical route](2026-11-24-sprint16-sgc-lab-support.md) · [Command route](2026-11-24-sprint17-sgc-briefing-command.md).

Each appearance is a scene child of its marker. Four skinned clothing meshes retain the shared Airman skeleton and fabric normal map. The civilian script samples the start of the idle clip, plants both feet and turns the head and hands toward the role's prop during an eight-second work cycle. The left palm supports the prop. The right palm approaches the work surface and lifts up to 20 mm during its gesture. The collision-free presentation runs locally on rendering peers, independent of gameplay interactions, combat, health and network authority. [Civilian visual](../../client/scripts/entities/SGCCivilianVisual.gd) · [Shared Airman rig](2026-11-25-sprint19-airman-rig.md).

## Head source and rendering cost

The shared generic head uses the official MakeHuman base with CC0 system skin, eye and Short01 hair assets. The preparation script trims below the neck and conforms the eye and hair proxies to the base. The prepared RGB skin and eye maps and RGBA hair map retain their UV correspondence. The hair uses alpha testing and runtime mipmaps. The Blender Studio CC0 bundle offered realistic bases that would require a separate head preparation path. Quaternius offered a ready humanoid kit with a different stylized silhouette. The MakeHuman head fits the cleared shared rig with a single rigid attachment. [Pinned source, archive and file hashes](../assets/intake/sprint26-civilian-head.json) · [Preparation script](../../tools/prepare_sprint26_civilian_head.py) · [MakeHuman licence](https://www.makehumancommunity.org/about/license.html) · [Blender Studio bundle](https://www.blender.org/download/demo-files/) · [Quaternius kit](https://quaternius.com/packs/universalbasecharacters).

The head GLB has 14,202 triangles and three surfaces, with zero Khronos validator issues. Running the preparation script against the staged sources reproduced the runtime GLB byte-for-byte. In the live SGC fixture the lab technician draws 20,246 triangles across 15 visible surfaces, the medic 20,618 across 15, and the administrator 20,234 across 14. Their four unique active maps use 6,903,121 decoded bytes including mipmaps. On the local i7-7700K the first headless instance took 260 ms to set up, including preparation of the shared Airman rig. Three cached instances took 1.6–2.8 ms each. The three actors own independent skeletons and share the imported head mesh and maps. [Live scene cost](../../build/sprint26/cost.log) · [Cold and cached load cost](../../build/sprint26/civilian-load-cost.log) · [Intake inspection](../../build/sprint26/head-intake.json) · [Validator report](../../build/sprint26/head-validator.json) · [Reproduction log](../../build/sprint26/head-repro.log).

## Coverage ledger

Sprint 26 owns the three `GateRoom/CivilianStations` slots. Each role uses the credited Airman clothing and the prepared MakeHuman head. The native wardrobe scenes supply the role trim and props. The procedural figure keeps the role colors and prop when the character assets are unavailable.

| Station slot | Prepared wardrobe | Sourcing | Technical | Owner art review |
|---|---|---|---|---|
| `Laboratory/Civilian` | [Lab jacket and clipboard](../../client/scenes/entities/SGCLabWardrobe.tscn) | Integrated | Pose, placement and fallback passed | Open for jacket and clipboard readability |
| `Medical/Civilian` | [Medical workwear and sample case](../../client/scenes/entities/SGCMedicalWardrobe.tscn) | Integrated | Pose, placement and fallback passed | Open for stethoscope and sample-case readability |
| `Administration/Civilian` | [Office shirt and folder](../../client/scenes/entities/SGCAdminWardrobe.tscn) | Integrated | Pose, placement and fallback passed | Open for shirt, tie and folder readability |

## Verification

The focused civilian fixture sampled the idle and work cycle in the live SGC. The anchors remained fixed, hand positions stayed within the measured contact bounds and the skinned boot soles met the floor. The map contract, UAT selection and lobby credits fixtures passed, along with all 60 Python checks. [Pose and clearance results](../../build/sprint26/civilian-direct.log) · [Focused Godot results](../../build/sprint26/focused/summary.json) · [Python results](../../build/sprint26/python.log).

Both four-operative fixtures passed on local listen and dedicated servers. Every peer agreed on the three station transforms across delayed loading, outbound and return gate travel, a replacement late join during travel, and two retries. Offworld peers kept the SGC stations hidden until they returned. The four-operative fixtures stage objective completion to exercise the return gate. The separate gate-return suite plays through those objectives. [Four-operative results](../../build/sprint26/round-trip/summary.json) · [Station and operative snapshots](../../build/sprint26/round-trip/station-snapshots.json).

All 136 Godot suites passed across the strict full profile and isolated reruns. The full run used `python3 tools/run_godot_tests.py --profile full --timeout 240 --output build/sprint26/godot-full` under the shared network lock and reported 133 of 138 checks passing, including project import and both keybinding persistence phases. An early gate assertion interrupted both lifecycle and both iris suites. All four passed after the fixture correction. The dedicated SGC result suite failed during its first retry sequence, then reproduced the stale operative RPC errors previously seen during Sprint 25 peer teardown. It passed the final isolated run. The intermittent teardown error remains open. [Full results](../../build/sprint26/godot-full/summary.json) · [Rerun results](../../build/sprint26/godot-retry/summary.json) · [Final dedicated SGC result](../../build/sprint26/sgc-result-isolated/summary.json) · [Sprint 25 baseline](2026-11-26-sprint25-sg3-heavy.md#verification).

All three Linux packs booted under the Godot 4.4.1 release template. The Linux debug template loaded the same packs for scripted assertions. The standard pack passed the civilian, map and credits fixtures. The pack with both character GLBs excluded passed the procedural civilian and Airman fixtures. The pack with only the civilian head excluded passed the work cycle with the fallback head on the imported rig. [Linux export results and pack hashes](../../build/sprint26/linux-export-final.log).

## Owner art review

The three civilian appearances share the same generic face and body dimensions. The in-game captures use Godot 4.4.1 Forward+ on Vulkan through Mesa llvmpipe. Diagnostic views show the poses at each authored station under ordinary lighting and the standard SGC alarm strobe. Player views use the existing third-person camera and HUD. The owner review covers role readability, the shared face and body silhouettes, and the hand and head gestures. [Screenshot contact sheet](../../build/sprint26/captures/contact.jpg) · [Laboratory motion](../../build/sprint26/captures/laboratory-motion.webp) · [Medical motion](../../build/sprint26/captures/medical-motion.webp) · [Administration motion](../../build/sprint26/captures/administration-motion.webp).
