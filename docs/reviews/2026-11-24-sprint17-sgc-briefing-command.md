# Sprint 17 — SGC briefing and command

Level 27 briefing and command use `client/scenes/world/Level27Complex.tscn` and the authored SGC region, lift and stair layout. Sprint 17 builds on the merged Sprint 16 work. [Sprint 16 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/89) · [Sprint 17 scope](../plans/asset-vertical-slices.md#sgc-base).

| Family | Live target and measured fit | Acceptance views |
|---|---|---|
| Briefing furniture | `BriefingRoom/ConferenceTable` is a 2.4 × 0.8 × 5.5 m cover box at `(0, 5.9, 15)`. The six chairs have 0.60 m cubes at X = ±1.6 m. | View the table from the aisle and the spiral landing. Preserve chair and table clearance, cover and the view toward the gate. |
| Command furniture | `GeneralsOffice/HammondsDesk` is 2.8 × 0.8 × 1.6 m at `(14, 5.9, 15)`. The chair, red phone and existing defense terminal have separate nodes. | Inspect the desk and office approach, including the existing terminal's prompt and route. |
| Displays and signage | The briefing overlook and its shutter have distinct visual and interaction nodes. Operations has a second independent shutter below. | View both sides of the briefing glazing, open and close each shutter, and walk the control-to-briefing corner stair and lift route. |

## Integrated visuals

The table and desk share a native material using Poly Haven's Wood Table 001. The material uses 1K colour, OpenGL normal and packed surface maps with a 1.5 m triplanar repeat. The source JPEG is preserved. The two data maps are converted to 8-bit PNG and all three textures use mipmaps. The desk uses a matte roughness override to soften the red phone reflection seen in the first material comparison. [Creator listing](https://polyhaven.com/a/wood_table_001) · [Source and prepared hashes](../assets/intake/sprint17-briefing-wood.json).

The FORUM 320 community table measures 3.20 × 1.20 × 0.76 m against a 5.50 × 2.40 m cover footprint. Poly Haven's Modern Arm Chair 01 measures about 0.82 × 0.99 × 1.02 m against the 0.60 m briefing chair cubes. Fitted native meshes give the six low-back chairs, executive chair, conference table and command desk the dimensions the room already uses. Their original CSG hulls provide cover and collision. [Innerscene table](https://www.innerscene.com/tools/library/3d-parts/forum-320-conference-table-573b29df) · [Poly Haven chair](https://polyhaven.com/a/modern_arm_chair_01).

The new observation readout follows the existing briefing shutter command. The separate operations shutter retains its own control. The view through the briefing pane and its collision were checked from both rooms.

## Forward+ captures

- Initial material comparison under the same lighting. [Briefing before](sprint17-captures/stock-briefing.png) · [Briefing wood](sprint17-captures/wood-briefing.png) · [Desk before](sprint17-captures/stock-command.png) · [Desk wood](sprint17-captures/wood-command.png).
- Final furniture, including all six briefing seats and the command desk with its phone and nearby terminal. [Briefing](sprint17-captures/briefing.png) · [Command](sprint17-captures/command.png).
- Open and sealed views through the briefing glazing. [Briefing open](sprint17-captures/briefing-open.png) · [Briefing sealed](sprint17-captures/briefing-sealed.png) · [Atrium open](sprint17-captures/atrium-open.png) · [Atrium sealed](sprint17-captures/atrium-sealed.png).
- The observation readout, separately closed control shutter and an operative positioned on the corner spiral for the capture. The route fixture verifies traversal under live movement. [Readout](sprint17-captures/readout-sealed.png) · [Control shutter](sprint17-captures/control-sealed.png) · [Corner spiral](sprint17-captures/corner-spiral.png).

## Verification

- Project import, SGC architecture, multiplayer state replication, camera occlusion, map contract, lift routes and asset credits passed. The architecture fixture checks all nine fitted visuals and their cover colliders, the three mipmapped texture maps, both sides of the glazing, table fade and restoration from both sides, the two shutter controls and a live lift ride.
- The full SGC walk and stair matrix passed in both directions with player, Airman and Jaffa capsules, including the control-to-briefing corner.
- Four-operative listen and dedicated sessions passed delayed loading, gate travel, a replacement join during travel and retry roster checks.
- The Linux Standard release PCK passed the packaged architecture and credit checks. The pack is 74,283,280 bytes with SHA-256 `67f96fd51b91e4ceec614499c9443db4890917e71cb4afe6d43fbd66fb5ea660`.

Owner art review remains open.
