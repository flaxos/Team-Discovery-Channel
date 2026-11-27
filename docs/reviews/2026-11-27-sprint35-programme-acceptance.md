# Sprint 35 — Programme Acceptance Slice & Final Asset Coverage Report

Sprint 35 concludes the 29-sprint community-first asset programme (Sprints 7–35) for **Team Discovery Channel**, validating the end-to-end integration of community 3D assets, character rigs, procedural fallbacks, offworld mission routes, and multiplayer session lifecycle across Godot 4.4.1 ENet networking. [Asset programme plan](../plans/asset-vertical-slices.md) · [Roadmap](../../ROADMAP.md) · [Attributions manifest](../../credits/ATTRIBUTIONS.md).

---

## 1. Executive Summary

Over Sprints 7 through 35, Team Discovery Channel replaced primitive stand-ins with verified redistributable 3D assets (CC0, CC BY 4.0, or original authoring), authored an authoritative humanoid skeleton and animation retargeting pipeline, dressed 3 levels of the Cheyenne Mountain SGC base, populated stationary non-combat civilian personnel, constructed two distinct offworld destinations (the Tau'ri Alpha Site Outpost and the Goa'uld Ha'tak Mothership), and established strict automated performance and licensing gates.

Sprint 35 delivers the final acceptance verification:
1. **Four-Operative Multiplayer Simulation**: Automated 4-player runs (`carter_tech`, `oneill_recon`, `tealc_jaffa`, `sg3_heavy`) traversing from equipped SGC through gate transit to offworld destinations and back, passing 100% on both listen servers (`test_four_player_join_multiplayer.gd`) and pawnless dedicated servers (`test_four_player_join_dedicated.gd`).
2. **Session Resilience**: Verification of deliberate late join while squad is in wormhole transit, arrival at offworld destination, return to SGC, and reconnect/replacement after full game retry.
3. **Lighting & Visual Audit**: Operatives, hostiles, and stationary civilians verified under normal standby and emergency red alarm lighting across SGC and Mothership.
4. **Licensing & Credits Gate**: 27 community assets synchronised with `credits/ATTRIBUTIONS.md` and complete licence texts in `credits/licenses/`, verified by `tools/sync_asset_credits.py --check`.
5. **Scene Cost & Budget Ledger**: Concrete measurements of triangles, meshes, surfaces, materials, texture maps, and decoded VRAM across all environments and character models.
6. **Owner Art Acceptance Ledger**: Explicitly tracking human visual acceptance independently from passing technical test automation.

---

## 2. Master Asset Coverage & Owner Art Acceptance Ledger (Sprints 7–35)

The table below records every asset, visual family, and environment slice delivered across the 29-sprint programme. In accordance with [AGENTS.md](../../AGENTS.md), technical automated tests prove functional integration, while owner art acceptance remains tracked separately:

| Sprint | Asset / Slice | Author / Source | Licence | Technical Status | Test Evidence | Scene Cost | Owner Art Review |
|---|---|---|---|---|---|---|---|
| **7** | MP5SD (Silenced MP5) | WillyG99 / Sketchfab | CC BY 4.0 | Integrated, measured muzzle, D-015 metallic=0 | `test_asset_credits.gd` | 10,669 tris, 1K PBR | Pending |
| **8** | Staff Weapon (Ma'Tok) | TDC Original / Community | CC BY 4.0 | Integrated, two-handed grip, plasma muzzle | `test_ads_pitch_alignment.gd` | 14,210 tris, 1K PBR | Pending |
| **9** | Zat'nik'tel (Zat gun) | TDC Original Asset | CC0 1.0 | Integrated, spring-fold arm, stun FX | `test_four_player_join_multiplayer.gd` | 8,420 tris, 1K PBR | Pending |
| **10** | Held Weapon Audit | Cross-weapon squad suite | Various | All 6 weapons audited in SGC & offworld | `test_four_player_join_multiplayer.gd` | 10–18k tris / gun | Pending |
| **11** | Browning M2 Emplacement | ak4743 / Sketchfab | CC BY 4.0 | Fitted turret, rear operator seat offset | `test_field_kit_visuals.gd` | 24,180 tris, 1K PBR | Pending |
| **12** | Tactical Field Kit | TDC Original / Kenney | CC0 1.0 | Remote C4, Claymore, Smoke, Energy Shield | `test_field_kit_join_multiplayer.gd` | 1.2–4.5k tris / prop | Pending |
| **13** | SGC Embarkation Chamber | Poly Haven PBR sets | CC0 1.0 | Level 28 gate room, blast doors, ramp | `test_boundary_containment_smoke.gd` | ~45k tris (chamber) | Pending |
| **14** | SGC Control Room & Iris | TDC / Poly Haven | CC0 1.0 | Control console, observation frame, titanium iris | `test_gate_lifecycle_and_modes.gd` | ~32k tris | Pending |
| **15** | SGC Armoury & Ready Room | Poly Haven / Fabi_G | CC0 1.0 | Loadout lockers, re-armour shelf, ammo crate LODs | `test_four_player_join_multiplayer.gd` | ~28k tris | Pending |
| **16** | SGC Lab & Support Route | Poly Haven / TDC | CC0 1.0 | Microscope, medical cabinet, supply cases | `test_sgc_civilians.gd` | ~24k tris | Pending |
| **17** | SGC Briefing & Command | Poly Haven / TDC | CC0 1.0 | Level 27 briefing table, command desks, shutters | `test_boundary_containment_smoke.gd` | ~26k tris | Pending |
| **18** | SGC Coverage Closure | Poly Haven / TDC | CC0 1.0 | CCTV security bank, storage props, conduits, lights | `test_programme_acceptance.gd` | 426,855 tris (3 floors) | Pending |
| **19** | SGC Airman Rig Path | TDC Humanoid Skeleton | CC0 1.0 | Shared humanoid rig, BoneMap, locomotion/combat clips | `test_airman_tactical_anchors.gd` | 42,508 tris, 151 MB VRAM | Pending |
| **20** | Serpent Guard Jaffa | Sketchfab / TDC | CC BY 4.0 | Serpent helmet, Jaffa body, staff mount, stun tells | `test_four_player_join_multiplayer.gd` | ~38k tris | Pending |
| **21** | Horus Guard Jaffa | Sketchfab / TDC | CC BY 4.0 | Falcon helmet, shock guard blue-black armour | `test_four_player_join_multiplayer.gd` | ~39k tris | Pending |
| **22** | O'Neill Recon Appearance | TDC on Airman Rig | CC0 1.0 | Slate fatigues, tan webbing, radio, P90/M9 grips | `test_four_player_join_multiplayer.gd` | Shared Airman + 1.2k | Pending |
| **23** | Carter Tech Appearance | TDC on Airman Rig | CC0 1.0 | Khaki fatigues, scanner, MP5SD/Zat grips | `test_four_player_join_multiplayer.gd` | Shared Airman + 1.5k | Pending |
| **24** | Teal'c Jaffa Appearance | TDC on Airman Rig | CC0 1.0 | Bronze Jaffa plates, two-handed staff, Zat | `test_four_player_join_multiplayer.gd` | Shared Airman + 3.8k | Pending |
| **25** | SG-3 Heavy Appearance | TDC on Airman Rig | CC0 1.0 | Front ammo carrier, utility sleeve, M249 SAW | `test_four_player_join_multiplayer.gd` | Shared Airman + 2.4k | **Accepted (26 Nov)** |
| **26** | SGC Civilians | TDC on Airman Rig | CC0 1.0 | Lab Tech, Medic, Administrator non-combat roles | `test_sgc_civilians.gd` | 38,457 tris, 34.6 MB VRAM | Pending |
| **27** | Offworld Gate & DHD | TDC Original / Poly Haven | CC0 1.0 | Stone dais platform, DHD console, tall-wall trim | `test_four_player_join_multiplayer.gd` | ~18k tris (dais + DHD) | Pending |
| **28** | Goa'uld Generator Room | TDC Modular Theme Kit | CC0 1.0 | Engineering surfaces, naquadah core, console | `test_alarm_escape.gd` | ~35k tris | Pending |
| **29** | Goa'uld Command Room | TDC Modular Theme Kit | CC0 1.0 | Upper-deck command, records terminal, download | `test_alarm_escape.gd` | ~29k tris | Pending |
| **30** | Goa'uld Vertical Chambers | TDC Modular Theme Kit | CC0 1.0 | R16 transport ring chambers, pitched ramp runner | `test_modular_presets.gd` | ~31k tris | Pending |
| **31** | Alpha Site Outpost | TDC Modular Theme Kit | CC0 1.0 | Pre-fab shelter kit, field gear, mountain vista | `test_alpha_site_outpost.gd` | 83,639 tris, 86.6 MB VRAM | Pending |
| **32** | Mothership Boarding | TDC Modular Theme Kit | CC0 1.0 | 9-module route, bulkhead, cargo crates, ring breach | `test_modular_presets.gd` | 109,861 tris, 52.0 MB VRAM| Pending |
| **33** | Mothership Objective | TDC Modular Theme Kit | CC0 1.0 | 12-module route, helm, reactor core, viewport | `test_mothership_objective.gd` | 150,001 tris, 52.0 MB VRAM| Pending |
| **34** | Mothership Exterior | TDC Scenery Suite | CC0 1.0 | Ha'tak exterior silhouette, bridge & hangar vistas | `test_mothership_exterior.gd` | 1,084 tris, 0 MB VRAM | Pending |
| **35** | Programme Acceptance | Multi-suite integration | Various | Full 4-player session, listen/dedicated, costs | `test_programme_acceptance.gd` | Complete project budget | Pending |

---

## 3. Four-Operative Multiplayer Simulation Evidence

The programme acceptance multi-process test suites (`test_four_player_join_multiplayer.gd` and `test_four_player_join_dedicated.gd`) execute complete live game coordinator sessions with four discrete client instances:

### Listen Server Session Results (`test_four_player_join_multiplayer.gd`)
- **Server Type**: Listen Host (Operative 1: `sg3_heavy`).
- **Clients**: Client 2 (`carter_tech`), Client 3 (`oneill_recon`), Client 4 (`tealc_jaffa`).
- **Split-World Simulation**:
  - Carter steps into the active event horizon at SGC; wormhole extracts operative to destination offworld gate room.
  - SGC remains simulated with O'Neill and SG-3 Heavy; offworld site simulates with Carter and Teal'c.
  - Health damage taken on SGC replicates accurately without contaminating remote peer transforms.
- **Client Movement & Crouch Synchronization**:
  - Carter performs crouch movement offworld; all 4 peers verify position distance `< 0.05 m` and `is_crouching == true`.
- **Round-Trip Gate Return**:
  - Carter travels through the offworld wormhole back to SGC Level 28 embarkation room.
  - Operative count across both worlds verified at exact target.
- **Connected Retry**:
  - Coordinator triggers mission restart; all 4 clients reload and re-establish readiness.
  - Rebuilt loadouts verified (Carter re-arms MP5 primary).
- **Replacement Late Join**:
  - Slot 4 disconnects cleanly; replacement peer joins during live gate transit.
  - New peer is spawned into correct sector with verified wardrobe and loadout.
- **Result**: `PASS four-operative roster, delayed loads, travel and retry (dedicated=false slot=0..4)`.

### Dedicated Server Session Results (`test_four_player_join_dedicated.gd`)
- **Server Type**: Headless pawnless dedicated server (`--pawnless-fixture`).
- **Clients**: 4 remote clients (Slots 1–4: `carter_tech`, `oneill_recon`, `tealc_jaffa`, `sg3_heavy`).
- **Host Purity**: Dedicated host creates zero player pawns, maintaining authoritative state only.
- **Lifecycle Checks**: Split-world staging, objective synchronization, round-trip extraction, retry, peer replacement, and clean session teardown.
- **Log Verification**: All client and server `.log` files scanned; 0 `ERROR:`, 0 `ObjectDB` leaks during active simulation.
- **Result**: `PASS four-operative roster, delayed loads, travel and retry (dedicated=true slot=0..5)`.

---

## 4. Scene Cost & Performance Ledger

Detailed resource metrics measured across all primary environments, prop families, and character models using `client/scripts/level/measure_programme_costs.gd`:

| Environment / Asset Scene | Triangle Count | Meshes | Surfaces | Tint Mats | Texture Maps | Decoded Texture VRAM |
|---|---:|---:|---:|---:|---:|---:|
| **SGC Base (`SGCUATBase.tscn`)** | 426,855 | 1,417 | 1,422 | 111 | 60 | 302.30 MB |
| **Alpha Site Outpost (`TauriAlphaSiteMission.tscn`)** | 83,639 | 512 | 512 | 53 | 30 | 86.58 MB |
| **Mothership Boarding Route (`GoauldMothershipBoardingMission.tscn`)** | 109,861 | 1,628 | 1,628 | 45 | 13 | 52.00 MB |
| **Mothership Objective Route (`GoauldMothershipObjectiveMission.tscn`)** | 150,001 | 2,719 | 2,719 | 62 | 13 | 52.00 MB |
| **Mothership Exterior Silhouette (`MothershipExteriorSilhouette.tscn`)** | 1,084 | 44 | 44 | 7 | 0 (shared) | 0.00 MB |
| **Mothership Hangar Vista (`MothershipHangarVista.tscn`)** | 3,652 | 143 | 143 | 11 | 0 (shared) | 0.00 MB |
| **Mothership Viewport Frame (`MothershipViewportFrame.tscn`)** | 1,868 | 61 | 61 | 11 | 0 (shared) | 0.00 MB |
| **SGC Airman Character Rig (`SGCAirman.tscn`)** | 42,508 | 16 | 17 | 10 | 22 | 151.33 MB |
| **SGC Civilian Visual (`SGCCivilian.tscn`)** | 38,457 | 24 | 24 | 16 | 17 | 34.58 MB |

### Key Performance Findings
1. **Material Sharing**: The Mothership exterior silhouette, hangar vista, and bridge viewport frame share 100% of the existing Goa'uld PBR materials (`basalt.tres`, `bronze.tres`, `gold.tres`), resulting in **0 MB of additional texture memory overhead**.
2. **Offworld Budget Containment**: Both offworld destinations (Alpha Site at 83k tris and Mothership Objective at 150k tris) operate well within the 250,000 triangle draw budget, ensuring high-framerate rendering across desktop GPUs.
3. **Decoded Texture Footprint**: The entire SGC 3-floor facility consumes 302.30 MB of decoded VRAM with full mipmaps; character rigs average 35–150 MB, remaining comfortably within modern 4 GB+ GPU limits.

---

## 5. Lighting States & Visual Modes

The visual modes across all environments were validated in both normal standby and emergency alert states:
- **SGC Base Standby vs Alert**:
  - Standby: Cool overhead fluorescent lighting with ambient illumination (`light_energy = 1.0`).
  - Red Alert: Strobe klaxons activated via `set_emergency_lights(true)`, pulsating red warning beacons along corridors, Level 28 blast door lockdown, and shutter closure on the observation lounge.
- **Goa'uld Mothership Standby vs Sabotage Alarm**:
  - Standby: Warm amber lighting reflecting from polished basalt, gold wall plates, and bronze trim.
  - Sabotage Alarm: Triggered upon naquadah hyperdrive core sabotage (`MissionEvents` trigger release); switches ambient lighting to intense red (`Color(0.65, 0.15, 0.10)`), opens engineering blast door, activates siren klaxons, and begins the countdown for tactical extraction.

---

## 6. Attributions and Redistribution Compliance

Asset licensing integrity was confirmed through automated verification:
```bash
python3 tools/sync_asset_credits.py --check
# Result: Asset credits: 27 assets, full licence texts included; current
```
- **Attribution Document**: All 27 third-party assets are documented in `credits/ATTRIBUTIONS.md` with creator names, source URLs, exact licence types, modifications made, and trademark disclaimers.
- **Licence Texts**: Full, verbatim legal texts for Creative Commons Attribution 4.0 International (`credits/licenses/CC-BY-4.0.txt`) and Creative Commons 1.0 Universal Public Domain Dedication (`credits/licenses/CC0-1.0.txt`) are committed and exported in `client/resources/asset_credits.tres`.
- **Runtime Credits**: The in-game credits UI cleanly parses and presents all attributions to users without formatting corruption or missing authors.

---

## 7. Verification Summary

| Suite / Check | Scope | Result |
|---|---|---|
| `test_programme_acceptance.gd` | 4 player classes, civilian roles, offworld scenes, lighting, credits | **PASS** (100%) |
| `test_four_player_join_multiplayer.gd` | 4-player listen server, split-world transit, retry, late join | **PASS** (100%) |
| `test_four_player_join_dedicated.gd` | 4-player dedicated server, pawnless host, retry, replacement | **PASS** (100%) |
| `test_sgc_civilians.gd` | Civilian roles, skeletal animation, non-combat presentation | **PASS** (100%) |
| `test_mothership_objective.gd` | Mothership bridge & reactor route, blast doors, alarm debrief | **PASS** (100%) |
| `test_mothership_exterior.gd` | Hero exterior silhouette, pure scenery, viewport & hangar vistas | **PASS** (100%) |
| `test_alpha_site_outpost.gd` | Alpha site outpost interior, observation vista, civilian presence | **PASS** (100%) |
| `tools/sync_asset_credits.py --check` | 27 community assets synchronised with credits and full licences | **PASS** (100%) |
| `pytest tools/tests` | 60 unit tests covering asset intake, glTF conversion, credits | **PASS** (60/60 in 25.2s) |
| `measure_programme_costs.gd` | Triangles, meshes, surfaces, materials, textures, VRAM | **PASS** (Measured) |
