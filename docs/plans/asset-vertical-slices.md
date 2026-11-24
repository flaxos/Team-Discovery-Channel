# Community-first asset sprints: 7–35

Owner-requested programme, **18 November 2026**, based on merged main `7982e2b` / [PR #77](https://github.com/flaxos/Team-Discovery-Channel/pull/77). Sprints [1–6](next-six-sprints.md) are merged; their remaining human checks still apply. Unless its state is explicitly updated below, each sprint is **planned**, not implemented or artistically accepted. “Horse” means **Horus Jaffa**; “mother assets” means a **Goa’uld mothership**. No delivery dates or guaranteed source acquisitions are implied.

**Resume status, 24 November 2026.** Sprints 7–9 are merged through [#79](https://github.com/flaxos/Team-Discovery-Channel/pull/79), [#78](https://github.com/flaxos/Team-Discovery-Channel/pull/78), [#81](https://github.com/flaxos/Team-Discovery-Channel/pull/81) and [#82](https://github.com/flaxos/Team-Discovery-Channel/pull/82). The realistic MP5SD, shared staff and original Zat are available for owner art review. [Sprint 10's audit](../reviews/2026-11-23-sprint10-held-weapon-audit.md) records the six visuals, their costs, downed-sidearm views and clean export. The M249's carried silhouette remains open for owner review. **Sprint 11’s M2 integration is ready for review.** The fitted visual, owner-review captures and four-player validation are documented. **Sprint 12 field kit merged via #85 and is ready for owner art review.** Four-operative listen and dedicated regressions cover deployment, travel, late join and retry. [Sprint 12 review](../reviews/2026-11-23-sprint12-field-kit.md) · [Sprint 11 review](../reviews/2026-11-23-sprint11-m2-intake.md).

## Roadmap at a glance

| Sprints | Visible outcome |
|---|---|
| 8–12 | Staff → Zat → all six held-weapon mesh/material audit → M2 → C4/claymore/smoke/shield |
| 13–18 | SGC embarkation → control/gate/iris → armoury → lab/medical support → briefing/command → remaining authored base areas |
| 19–21 | Rigged Airman and shared animation path → Serpent Jaffa → Horus Jaffa |
| 22–25 | O’Neill → Carter → Teal’c → SG3 Heavy, completing class-specific weapon handling |
| 26 | Laboratory, medical and administration civilians, initially noncombat presentation |
| 27–31 | Offworld gate/DHD → generator → command/records → tall chambers/ramps → outpost/background vista |
| 32–34 | Mothership boarding/interior → bridge/engineering objective → exterior silhouette/vista |
| 35 | Four-player SGC → selected offworld site → SGC acceptance run |

Weapon meshes and field-kit visuals are addressed through Sprint 12; **complete animated grips/handling remain open through Sprint 25**. SGC dressing does not add new base levels, and mothership art does not add flight or space combat. Each slice remains subject to its detailed scope and separate owner art review below.

Prefer available high-fidelity community assets, including normal owner/account downloads. Generate only documented gaps under the [shared AI workflow](../assets/ai-asset-workflow.md), [texture contract](../assets/texture-import-contract.md) and [strict work-order schema](../assets/asset-work-order.schema.json). Start with the [dated sourcing register](../assets/asset-program-sourcing.md); a promising listing is not an approved or acquired model.

## Prompt one sprint at a time

Copy the exact trigger from the table. Every trigger means:

> Read AGENTS.md and the linked workflow. Audit existing implementation and prior Claude-era evidence before replacing it. Execute only this sprint’s playable vertical slice, including required tooling consumed by it. Preserve unfinished work and current gameplay contracts. Prefer community models; issue concrete owner download cards for actual acquisition blockers. Use the generation schema for gaps. Validate, capture, export and document the result; update this plan and ROADMAP.md with actual state and remaining owner acceptance. Follow the current user’s commit/merge instruction and AGENTS.md. Stop after the slice; do not start the next sprint automatically.

If a prerequisite is unfinished, report it and finish only the prerequisite work necessary for this slice; do not declare downstream acceptance from an idle preview or a fallback asset. A required acquisition can remain blocked while independent work proceeds. Never mark that slice complete just because its placeholder still works.

| Sprint | Playable result | State | Exact trigger |
|---|---|---|---|
| 7 | Faithful MP5SD in SGC/offworld; reproducible shared intake and distributed credits | Merged to main via #79/#78; technical checks passed, owner art pending ([review](../reviews/2026-11-18-sprint7-mp5-intake.md)) | `Start sprint 7 from docs/plans/asset-vertical-slices.md` |
| 8 | Staff weapon in player and Jaffa combat | Merged via #81. Original textured staff for Teal’c and both Jaffa variants. [Review and verification](../reviews/2026-11-23-sprint8-staff-intake.md). | `Start sprint 8 from docs/plans/asset-vertical-slices.md` |
| 9 | Zat in quiet incapacitation/combat | Merged via #82. [Original sidearm and evidence](../reviews/2026-11-23-sprint9-zat-visual.md) | `Start sprint 9 from docs/plans/asset-vertical-slices.md` |
| 10 | Six held weapons compared in SGC and offworld | Audit merged via [#83](https://github.com/flaxos/Team-Discovery-Channel/pull/83). Owner mesh and material review pending, including the M249 bipod silhouette. [Audit](../reviews/2026-11-23-sprint10-held-weapon-audit.md). | `Start sprint 10 from docs/plans/asset-vertical-slices.md` |
| 11 | Mounted/deployable M2 in a live defensive encounter | Merged via [#84](https://github.com/flaxos/Team-Discovery-Channel/pull/84). Owner art review open. [M2 visual and validation](../reviews/2026-11-23-sprint11-m2-intake.md). | `Start sprint 11 from docs/plans/asset-vertical-slices.md` |
| 12 | Existing deployable field kit visually finished | Merged via #85. Listen and dedicated checks complete. Owner art review open. [Field-kit evidence](../reviews/2026-11-23-sprint12-field-kit.md). | `Start sprint 12 from docs/plans/asset-vertical-slices.md` |
| 13 | SGC embarkation area with reusable PBR treatment | Merged via #86. Owner art review open. [Before/after and material evidence](../reviews/2026-11-24-sprint13-sgc-embarkation.md). | `Start sprint 13 from docs/plans/asset-vertical-slices.md` |
| 14 | SGC control, gate and iris during dialing/travel | Merged via [#87](https://github.com/flaxos/Team-Discovery-Channel/pull/87). Owner art review open. [Control, gate and iris evidence](../reviews/2026-11-24-sprint14-sgc-control-gate-iris.md). | `Start sprint 14 from docs/plans/asset-vertical-slices.md` |
| 15 | SGC armoury/ready room with usable gear stations | Merged via [#88](https://github.com/flaxos/Team-Discovery-Channel/pull/88). Owner art review open. [Armoury review](../reviews/2026-11-24-sprint15-sgc-armoury.md). | `Start sprint 15 from docs/plans/asset-vertical-slices.md` |
| 16 | SGC lab/support objective with medical dressing | Merged via [#89](https://github.com/flaxos/Team-Discovery-Channel/pull/89). Owner art review open. [Lab and support review](../reviews/2026-11-24-sprint16-sgc-lab-support.md). | `Start sprint 16 from docs/plans/asset-vertical-slices.md` |
| 17 | SGC briefing/command route across observation levels | Merged via [#90](https://github.com/flaxos/Team-Discovery-Channel/pull/90). Owner art review open. [Briefing and command review](../reviews/2026-11-24-sprint17-sgc-briefing-command.md). | `Start sprint 17 from docs/plans/asset-vertical-slices.md` |
| 18 | Remaining SGC support/security/service route | Route dressing merged via [#91](https://github.com/flaxos/Team-Discovery-Channel/pull/91). The follow-up integrates the deferred ceilings, fixtures, conduits and service stair finishes. Owner art review open. [Coverage and evidence](../reviews/2026-11-24-sprint18-sgc-coverage.md). | `Start sprint 18 from docs/plans/asset-vertical-slices.md` |
| 19 | Rigged Airman patrol/combat/recovery; shared rig adapter | The uniformed Airman is also the temporary model for the four playable operatives and existing SGC personnel. Owner art review open. [Airman and squad rig review](../reviews/2026-11-25-sprint19-airman-rig.md). | `Start sprint 19 from docs/plans/asset-vertical-slices.md` |
| 20 | Serpent Jaffa in a complete combat encounter | Planned | `Start sprint 20 from docs/plans/asset-vertical-slices.md` |
| 21 | Horus Jaffa in the same authoritative encounter | Planned | `Start sprint 21 from docs/plans/asset-vertical-slices.md` |
| 22 | O’Neill recon operative with P90/M9 grips | Planned | `Start sprint 22 from docs/plans/asset-vertical-slices.md` |
| 23 | Carter tech operative with MP5/Zat and gadget | Planned | `Start sprint 23 from docs/plans/asset-vertical-slices.md` |
| 24 | Teal’c operative with staff/Zat | Planned | `Start sprint 24 from docs/plans/asset-vertical-slices.md` |
| 25 | SG3 heavy operative and complete four-class weapon matrix | Planned | `Start sprint 25 from docs/plans/asset-vertical-slices.md` |
| 26 | SGC laboratory/medical/administrative civilians | Planned | `Start sprint 26 from docs/plans/asset-vertical-slices.md` |
| 27 | Offworld gate arrival, DHD and departure | Planned | `Start sprint 27 from docs/plans/asset-vertical-slices.md` |
| 28 | Goa’uld generator/engineering objective room | Planned | `Start sprint 28 from docs/plans/asset-vertical-slices.md` |
| 29 | Goa’uld command/records objective room | Planned | `Start sprint 29 from docs/plans/asset-vertical-slices.md` |
| 30 | Tall ring chambers and upper-deck traversal | Planned | `Start sprint 30 from docs/plans/asset-vertical-slices.md` |
| 31 | Offworld outpost/Alpha Site dressing and exterior vista | Planned | `Start sprint 31 from docs/plans/asset-vertical-slices.md` |
| 32 | Mothership boarding/interior route | Planned | `Start sprint 32 from docs/plans/asset-vertical-slices.md` |
| 33 | Mothership bridge/engineering objective and return | Planned | `Start sprint 33 from docs/plans/asset-vertical-slices.md` |
| 34 | Mothership exterior silhouette and hangar vista | Planned | `Start sprint 34 from docs/plans/asset-vertical-slices.md` |
| 35 | Four-player SGC → offworld → SGC art acceptance run | Planned | `Start sprint 35 from docs/plans/asset-vertical-slices.md` |

## Completion contract shared by every slice

Each slice includes a finite asset list, intake/licence/provenance, prepared runtime content, wrapper/adapters, the existing playable interaction, relevant behavioral checks, GPU evidence, a clean export and a review record. Follow the workflow’s separate sourcing / technical / owner-art states. Budgets in the texture contract are provisional until measured on recorded hardware. New blockers or scope changes go in the current entry and review, rather than quietly expanding the next sprint.

Sprint 7 starts a **coverage ledger** in its review, carried forward by each slice: asset ID, scene/slot, source, replacement/fallback, recipe, technical state, owner art state, remaining defect, sprint responsible. Enumerate live assets before declaring a category complete. SGC coverage is all discoverable authored art slots/regions across Sublevels **28, 27 and 26**, not an invented film-accurate complete mountain complex. Offworld coverage is the live module catalogue and selected missions; no unbounded collection of planets. If a bounded slice cannot finish its assigned set, name the residual rows and split it explicitly before closing the category.

For changed gameplay-visible content, exercise four operatives on **listen and dedicated servers**, with relevant late join, join during gate travel, after return and after retry. Run the strict full profile at slice completion; report local and hosted checks separately. Dedicated servers must not require graphics or asset-generation services. GPU captures and human review supplement automated checks; they are not interchangeable. Preserve authority, collision, muzzle/interaction anchors, mission rules and retry state. Use only current view modes, not a new camera feature.

### Weapons and field kit

**Sprint 7 — MP5SD and repeatable acquisition.** Depends on merged Sprint 6; read the M9/P90/M249 golden examples first. Deliver **one** faithful textured suppressed MP5SD on the existing Carter loadout, usable in the existing SGC UAT base and an offworld encounter. Compare sources rather than relabeling the current Kenney `uziLongSilencer`. Consume the strict work-order validation in this intake path, preserve lossless data maps where needed, record the baseline material override and make required credits/full licences reachable in the exported build from a maintained source. Validate muzzle/aim/suppression/reload, shared cache, fallback, export and four-player state. Block on a missing suitable model rather than calling the 2,210-face lead high fidelity without inspection. No rig replacement yet.

**Sprint 8 — Staff weapon.** Depends on 7’s intake/credit path. Deliver **one** staff model used by the player and current Jaffa, with measured staff length, two-hand contact targets, existing muzzle and effect alignment. Audit old AP-1b work before sourcing. Separate tip parts only if required by an existing visual state; a static source does not magically supply opening animation. Show firing/idle, close-up and distant silhouette, existing projectile/damage and late state. Keep NPC `StaffMount` and fire origin authoritative. Final animated grips remain assigned to 20/24.

**23 November update:** the owner-downloaded source contained an untextured STL and no creator evidence. The [ready work order](../assets/intake/staff/work-order.json) records the original geometry and material fallback. [Sprint 8 review](../reviews/2026-11-23-sprint8-staff-intake.md) records placement, runtime captures and outstanding art acceptance. Sprint 8 is merged in #81.

**Sprint 9 — Zat.** Depends on 7; consumes 8’s anchor lessons. Deliver **one** Zat with readable shape/PBR and presentation of existing fire/incapacitation states. Test quiet takedown/stun and subsequent existing hit consequences, late join/retry and travel inventory. Source/grant or generated-gap modelling is required; the Biggs portfolio model is not downloadable/licensed intake. Art cannot change stun duration or the existing vaporization rules. Do not promise open/closed mechanisms unless the actual gameplay state and separable parts support them. Final grips are assigned to 23/24.

**Sprint 9 implementation:** an original loop-frame Zat uses the project’s existing muzzle and effects. [Review and measures](../reviews/2026-11-23-sprint9-zat-visual.md). Merged via #82. Owner art and grip work remain open.

**Sprint 10 — Held-weapon completion pass.** Depends on 7–9. Audit **M9, P90, MP5, M249, staff and Zat** together at the game camera. Retain current realistic M9/P90/M249. Resolve or explicitly replace the M249’s fused extended bipod if it fails the accepted handling silhouette; do not pretend it retracts. Produce measured LOD/material/mipmap/cache costs, downed-sidearm views, real mission lighting, export and the six-weapon coverage ledger. Any replacement must improve fidelity and retain provenance. This closes mesh/material work only when accepted; hand/animation completion remains open through 25.

**Sprint 10 audit:** all six existing GLBs loaded at LOD0 with mipmaps and shared resources. The MP5SD uses 117.33 MiB decoded under its 128 MiB exception. The M249 keeps the fused extended bipod pending a decision on its carried silhouette. The downed camera selects the correct sidearm but gives a small end-on view. [Captures, measurements and coverage](../reviews/2026-11-23-sprint10-held-weapon-audit.md).

**Sprint 11 — M2 defensive position.** Depends on 10. Deliver **one M2 visual set** (gun, mount/tripod and associated existing base) on `DeployableTurret`. Play deployment, mount/aim/fire/dismount and the existing AI interaction where supported. Preserve `TurretHead/MuzzlePoint`, aim limits, interaction reach and authoritative firing. Reuse rather than duplicate weapon materials. Validate late join while mounted and after retry. No vehicle weapons, new turret AI or new deployment rules.

**Sprint 12 — Field kit.** Depends on 11. Enumerate the existing carried/deployed variants, then finish **C4, claymore, smoke grenade and shield** (maximum four prop families). Show every currently supported placement/use/detonation/recovery state; exclude nonexistent disarm or pickup mechanics. Keep blast/LOS, collision and interaction behavior unchanged. Test close readability, prompt location, effect alignment, multiplayer snapshots, travel and retry. The category ledger covers all six held weapons, M2 and these supported gadgets; artwork still awaiting character hands remains open. Do not add new equipment to satisfy a model pack.

### SGC base

Use [SGC’s native authoring contract](../maps/sgc.md) and discover actual slots before selecting models. Preserve the gate → raised operations → briefing sightline, shutters, stairs, lift and authored region bounds. Each slice adds at most **three new prop/material families**, reuses established families elsewhere in its named route, and closes its assigned ledger rows. Do not describe a decorative medical prop as a healing mechanic.

**Sprint 13 — Embarkation and PBR proof.** Depends on 12. Finish the playable embarkation route: wall/panel family, floor/runner family and support/rail family. Add only the reusable PBR binding actually consumed here; the existing single-texture SGC slot is insufficient for a full set. Compare preserved source metals against D-015 and propose bounded reflection/lighting treatment with before/after evidence. Test gateway aperture, cover silhouette, occlusion fade, footsteps/traversal and normal/alarm scenes. No global material rewrite without measured mission comparisons.

**Sprint 14 — Control, gate and iris.** Depends on 13. Finish control consoles/glazing frames and the existing gate/iris visual surfaces (three families). Retain accepted AP-1g glyph work, seven chevrons, horizon, kawoosh and all trigger/iris/dialing nodes. Any articulated replacement follows the actual script API and has fallback. Play dial, cancel, inbound/iris interaction and outbound/return, joining during travel. No nine-chevron system or invented iris ratio API; source-body fit must not shrink the opening.

**Sprint 15 — Armoury/ready room.** Depends on 13; follows 14 in the sequence. Finish rack/storage/station dressing (three families) on existing ammo/loadout interactions. Resolve repeated crate cost using measured LOD/instancing/material sharing rather than removing functionality. Test prompt reach, use, ammo sharing, crouch/cover and view occlusion, including two simultaneous visitors. No new weapon purchase system.

**Sprint 16 — Laboratory/support objective.** Depends on 15. Finish lab bench/equipment, medical furniture and supply dressing (three families) within real slots. Play the existing ROM/lab objective and nearby support route; record where infirmary-style dressing is merely cosmetic. Preserve objective access, door states and NPC paths. Source accurate equipment or use tightly dimensioned material/prop gaps. No new healing, surgery or research system.

**Sprint 17 — Briefing/command.** Depends on 16. Finish briefing furniture, command/office furnishings and display/signage family along the actual Level 27 route. Show observation sightlines, both shutters and the control/briefing corner stair in use. Verify lift and capsule clearance, glass sorting and replacement fade from both sides. Do not move offices or add production-set geometry outside the authored map.

**Sprint 18 — SGC coverage closure.** Depends on 17. Finish remaining security/storage/service/barracks dressing **where live slots exist**, with at most three new families and reuse elsewhere. Traverse Levels 28→27→26→28 under normal and alarm conditions, with friendly/hostile navigation. Close or explicitly split every remaining base-art ledger row before calling SGC assets complete. Level 25, exterior mountain/airbase and new underground levels are outside this programme.

### Characters and animation

Character slices need a redistributable model **and** an adequate animation set. A helmet, portrait or one idle clip is not a complete character. Use a common validated humanoid profile, not blind bone-name copying: [Godot’s retargeting guide](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html) explains rest-pose and hierarchy dependencies. Validate a rest-pose/BoneMap contract and per-archetype mappings. The canonical profile does not exist at baseline; Sprint 19 defines it from a proven rig. In-place movement follows existing replicated state; root motion never drives authority.

**Sprint 19 — Airman and the rig path.** Depends on 18 and weapon assets. Deliver **one full Airman archetype**, with uniform/gear, in real patrol, aim/fire and down/recovery scenes. Introduce a skin/animation-preserving pipeline and visual adapter consumed by that NPC; current rigid packing loses rigs. Cover existing idle, walk/run, crouch, turn, aim/fire, down/death and any applicable revive/drag transitions. Preserve controller, typed procedural nodes/fallback and muzzle; prevent double crouch/death scaling. Verify clips, feet, hand targets, alpha, occlusion, bounds and export on peers. One source clip alone cannot close this slice.

The same rig is the current placeholder for O’Neill, Carter, Teal’c and SG-3 Heavy, as well as existing SGC personnel. The remaining character sprints deliver each role’s distinct appearance, equipment fit and animation polish. Sprint 26 adds civilian roles at authored stations.

**Sprint 20 — Serpent Jaffa.** Depends on 19/8/9. Deliver **one Jaffa body/armour archetype plus Serpent helmet**, reusing the verified rig where suitable. Test patrol, awareness tell, aim/fire, stun, takedown and down/death in a live offworld encounter. Preserve armor/stun FX behavior, current AI stats, staff mount and replicated state. The 771-face helmet is a lead, not a finished high-fidelity rig. Any helmet mechanism needs actual parts/states; a static accepted helmet is preferable to an unsupported animation claim.

**Sprint 21 — Horus Jaffa.** Depends on 20. Deliver **one Horus/falcon helmet and required armour variant** on the compatible body, with clear silhouette versus Serpent in the same encounter and lighting. Check neck/shoulder clearance through all existing poses, awareness readability and LOD transitions. Reuse current guard/shock-guard behavior only as currently supported; art alone does not create a new Horus faction/stat block. The old NC helmet is excluded. Recheck sourcing, then generate/model the documented gap if necessary.

**Sprint 22 — O’Neill recon.** Depends on 19/10 and follows 21. Deliver **one recon player appearance** for existing `oneill_recon`, P90/M9 grips, uniform/gear, hand targets and current view modes. Exercise move/crouch/aim/fire/reload/switch, downed M9, revive/drag and travel. Preserve player camera, body/capsule, identity/nameplate and sync. A source head is optional; no unverified celebrity likeness or new class mechanics are required to finish the uniformed role.

**Sprint 23 — Carter tech.** Depends on 22/7/9. Deliver **one tech appearance** for existing `carter_tech`, MP5/Zat contact targets and the current gadget interaction poses. Check gear clipping, all shared movement/health states and interaction hand placement without moving authoritative controls. Use the same proven skeleton/animation library where it deforms correctly; otherwise record the actual adaptation. No new hacking minigame or gender-specific controller fork.

**Sprint 24 — Teal’c.** Depends on 23/8/20. Deliver **one playable Jaffa appearance** for existing `tealc_jaffa`, staff/Zat grips, uniform/armour fit and a distinct readable team identity. Test two-hand staff poses and projectile alignment, crouch, down/revive/drag and gate travel. A portrait cannot supply a full rig; adapt the verified body with cleared/generated gap art as necessary. No new melee combat feature or class perks.

**Sprint 25 — SG3 heavy and weapon closure.** Depends on 24/11/12. Deliver **one heavy appearance** for existing `sg3_heavy`, M249/M9 grips and current deployable interactions. Run all four existing classes together through the full movement/weapon/health matrix and mounted kit. Close hand/clip/muzzle issues and the weapon ledger from 10/12 with accepted captures. Daniel is not a fifth current playable class; a Daniel-style visual belongs to a separately chosen existing-role/civilian variant, not an implicit new role. “All weapons finished” requires these rows, not just six GLB files.

**Sprint 26 — Civilians.** Depends on 19/16/25. Deliver **three limited visual roles**: laboratory, medical and administration, with shared body/rig as appropriate and distinct clothing/props. Place at authored safe anchors; support idle/work presentation only. The game has no civilian actor/AI baseline: add the minimum noncombat presentation wrapper if needed, without weapons, combat targeting, Health or mission logic. Show consistent loading/placement after join/travel/retry. Patrol schedules, panic, escort/rescue, civilian damage and neutral-faction AI require a separate gameplay brief; do not disguise an armed Airman as a doctor.

### Offworld locations and mothership

Recover prior chamber work read-only before replacing it. Use native modules and the theme kit; discover live IDs before selection. The existing session supports **SGC plus one offworld site**. A planet and mothership are alternative sites, not an invented three-world chain. Each room slice adds at most three new prop/material families plus reuse, and covers a real objective/traversal route.

**Sprint 27 — Gate arrival and DHD.** Depends on 18/20/21/25; follows 26. Dress the offworld arrival/hangar zone and DHD/console approach (gate surround, DHD, storage/support families). Fit to current collision/interaction anchors and actual operating height. Play entry, regroup, dialing and departure with late join during transit and return. Source model buttons do not create new dialing inputs. Preserve existing gate visual and all split-world state.

**Sprint 28 — Generator room.** Depends on 27. Inspect unfinished generator chamber art (module 10 in the existing visual brief; re-discover actual ID). Finish engineering surfaces, generator casing and service-detail family around the existing objective. Preserve cover, interaction access and shutdown/door-release rules. Demonstrate the live objective, alternate approach and exit under alarm lighting. No new power simulation.

**Sprint 29 — Command/records.** Depends on 28. Inspect unfinished command chamber work (brief’s module 11). Finish command surfaces, console/records furniture and insignia/trim family. Play the actual records/download objective, including Timed Extraction or Alarm Escape where configured; display must reflect existing state, not invent new objectives. Retain door/nav/cover geometry and countdown snapshots.

**Sprint 30 — Tall chambers/ramp.** Depends on 29. Finish lower/upper ring chamber and ramp art using shared tall-wall, ring-dais and upper-deck detail families (brief’s 14/15 variants; verify catalogue). Test continuous authored ramp/deck movement, head clearance, sightlines, seams and collision/nav parity. **R16 ring transport is not mission-ready**; this sprint can dress the apparatus but cannot claim authoritative ring teleportation. A functional transporter requires a separately scoped gameplay fix and tests.

**Sprint 31 — Offworld outpost.** Depends on 30/26. Deliver one Alpha Site/outpost interior route using supported modules, three surface/shelter/field-equipment families, and reused civilian appearance where appropriate. Show a nontraversable terrain/vegetation/sky vista beyond an authored boundary. The current authoring system has no general outdoor-terrain capability: do not delete roofs, bypass enclosure checks or claim a walkable open planet. Full outdoor navigation/terrain is a separate capability prerequisite. Preserve the current entry/objective/return loop.

**Sprint 32 — Mothership boarding.** Depends on 30/27 and follows 31. Deliver one Ha’tak-style boarding/arrival-to-interior route from supported modules, using existing gate travel as the safe mission entry. Up to three hull/interior-door/cargo families; reuse Goa’uld trims. Document how playable interior scale relates to the exterior without forcing film dimensions into modules. Ring pads are decorative until R16 is fixed. The mothership is the chosen offworld site in this mission, not a third live world. No flight or docking simulation.

**Sprint 33 — Mothership objective.** Depends on 32/29. Finish one bridge/engineering objective-and-return route, at most three bridge-console/reactor-detail/hero-trim families. Use current MissionEvents/objective interactions; play completion or failure, alarm state, return gate and debrief. Windows/views must preserve boundaries and camera fade. No AI ship captain, power management, ship destruction or new mission director hidden in an art sprint.

**Sprint 34 — Mothership exterior.** Depends on 33. Deliver **one hero exterior silhouette** and the hangar/window vista dressing that exposes it from a playable interior. Community high-fidelity source first; no suitable redistributable ship has been verified. Define physical/view scale, near-detail limits, exterior LODs/impostor and material sharing before intake/generation. Review silhouette near and far in actual mission lighting with frame/memory evidence. The hull is scenery: no landing, flight, space combat, destructible shell or fully explorable ship implied.

**Sprint 35 — Programme acceptance slice.** Depends on all required preceding ledger rows. Run four players from equipped SGC through **one selected offworld site and back**, on listen and dedicated servers; run the other site as a separate session if part of the accepted asset coverage. Check late join while traveling, at destination, after return and after retry; all class/weapon and friendly/hostile/civilian views; normal/alarm lighting; export credits/licences, fallbacks and measured scene costs. Close remaining defects or identify exact unaccepted rows. Deliver a final asset-coverage/owner-art report, not a claim that passing tests automatically approves art. No new gameplay systems.

## What to request when a slice is blocked

Ask for the specific archive, purchase choice or art decision using the shared workflow’s card. Continue useful independent work. If the missing capability is gameplay (outdoors, ring transport, spaceflight, neutral AI), report the boundary and propose its own vertical slice rather than hiding it in import work. Do not create extra directories/checkouts to restart a blocked import.

Planning checks for this document verify links, numbering and schema examples. Actual model, gameplay, multiplayer, export and art evidence is produced by the executing sprints; none is asserted by this plan.
