# Sprint 16 — SGC laboratory and medical support

Started on `feat/sprint16-sgc-lab-support` from the Sprint 15 review commit `d070265`, whose tree matches the squash merge `1ad5bd3`. The live target is the SGC lab and support route. Catalogue discovery also found a `laboratory_medical` preset for modular maps. The SGC route uses its own authored room resource. [Sprint 15 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/88) · [Sprint 16 scope](../plans/asset-vertical-slices.md#sgc-base).

| Family | Existing envelope and role | Acceptance view |
|---|---|---|
| Research benches and equipment | `GateRoom/Level28Complex/LaboratorySector`. Both benches are 1.2 × 1.0 × 4.0 m, with their surfaces at world Y = 1.30 m. The ROM drive is on the west bench at `(20, 1.35, 52)`. Reserve a 0.92 × 0.54 × 0.84 m visual space above the east bench at Z = 53 for the first instrument. | Show the ROM approach from the aisle, pickup, and upload at the Control Room. The east bench instrument has no collision or interaction. |
| Medical furniture | Level 26 has authored support, staging, storage and service areas. It has no named infirmary or medical interaction. `STAGINGCover` is a 1.6 × 1.0 × 1.0 m solid cover slot. A compact backed medical supply cabinet can use that footprint. | Walk from the lift to staging and through the adjacent route. Confirm crouch cover and NPC passage with an opaque cabinet silhouette. |
| Supplies | `SupplyRack1` is a 1.4 × 1.8 × 1.5 m solid rack along the storage wall. The planned `STORAGECover` overlaps `SupplyRack0`, so it remains available as authored cover. | Show closed medical transport cases along the wall. Walk through the existing four-metre connection to the service room and keep the stair approach clear. |

## Community intake

- **Industrial Microscope**, Lukas Walzer, distributed by Poly Haven under CC0. Five public 1K glTF components matched provider hashes and sizes. Godot measured the instrument body at 0.215 × 0.460 × 0.447 m at its floor pivot. The separate loose cable is outside the instrument mesh. [Creator listing](https://polyhaven.com/a/industrial_microscope) · [Provider licence](https://polyhaven.com/license).
- **Hospital Bed** is listed at 2.22 × 1.11 × 1.13 m. That exceeds the existing staging and storage cover footprints. [Grab3D listing](https://grab3d.com/models/furniture/hospital-bed/).
- **Bedside Cabinet** is an 84-triangle CC0 prop with a listed 0.38 × 0.44 × 0.331 m envelope. Filling the staging collider would require a multi-cabinet cluster or non-uniform stretch. The final native cabinet fits the collider as a single enclosure. [kernelCAD listing](https://kernelcad.com/catalog/medical/bedside-cabinet/).
- **Utility Box 02** is a textured enclosure with high-voltage markings and weathering. The storage slot uses closed, teal-trimmed transport cases for its medical role. [Poly Haven listing](https://polyhaven.com/a/utility_box_02).

## Level 28 lab

Both benches use a shared matte finish. The east bench mounts the microscope facing the aisle. The fit check keeps it inside the measured space, and the missing-asset path leaves the bench and its collision in place. The prepared model omits the loose cable and has 14,568 triangles, three 1K PNG maps and one material. Khronos validation reported zero errors and warnings. [Intake, licence and preparation](../assets/intake/industrial_microscope/).

The diagnostic views show the first instrument and the separate ROM approach under the authored room lights at 1440 × 900. [East bench](sprint16-captures/east-bench.png) · [West aisle and ROM](sprint16-captures/rom-aisle.png).

The hard-mode fixture now collects the ROM via the operative's interaction from the west aisle, then exercises upload, dialing and extraction. Its teardown retires the operative's area overlaps before freeing the room so the release fixture can finish cleanly.

## Level 26 medical support

The staging cabinet and six closed transport cases use native geometry and the existing `SGCAssetSlot.visual_scene` path. They fit the original cover silhouettes with collision-free visuals. The storage stack faces the aisle. Camera rays fade the visible staging mesh when it occludes a crouched operative, and restore its finish when the camera turns clear. Both props serve as scenery on the support route. The lift, corridors, doors and existing combat cover retain their authored behavior.

The same storage camera records the cases with the room’s normal and alarm lights. [Staging cabinet](sprint16-captures/staging-cabinet.png) · [Storage cases](sprint16-captures/storage-cases.png) · [Storage under alarm](sprint16-captures/storage-alarm.png).

## Verification

The hard-mode ROM path, lift routes, physical player and NPC routes, crouch occlusion, and both four-player listen and dedicated travel/retry suites passed locally. The dedicated mission-join fixture confirmed that both medical props were present on late join and after retry. The final cover and camera checks passed again after the visual seams were adjusted.

The standard Linux release pack passed the ROM and medical fit fixtures and shipped 18 credited assets and both licences. A second pack excluded the microscope and passed the same objective and medical checks. The standard fit check rejected the missing microscope during the lab kickoff. Owner art review is open.

| Linux x86-64 PCK | Bytes | SHA-256 |
|---|---:|---|
| Standard | 69,688,304 | `86b69c754dbdde62d6dcb6ce4adaef16d33309a0aab225a8c7bc43be60b8f648` |
| Microscope excluded | 64,659,488 | `61dd22b62aae8b7eca5387698a70bb355b43a4310a6ff379b9810e2fb350b218` |
