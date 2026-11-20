# Asset programme planning review

**Implementation follow-up, 21 November 2026:** the planning record below retains its original baseline. [Sprint 7](2026-11-18-sprint7-mp5-intake.md) subsequently delivered the MP5SD, consumed work-order validation and distributed credits/full licences, with 117 local/hosted full checks, 60 Python tests and clean export proof. #79 merged into the planning branch on 18 November, then #78 brought the combined work to main `1f634d1` on 20 November. Owner art review is pending. **Sprint 8 staff weapon is next; Sprints 8–35 remain planned.** The original “all planned” and outstanding MP5/credit statements below describe planning time, not current status.

18 November 2026. Documentation baseline: merged main `7982e2b` / PR #77. The owner confirmed Horus Jaffa and a Goa’uld mothership. This change plans future implementation; it adds no game asset, controller, mission or runtime dependency.

## Deliverables

- [Sprints 7–35](../plans/asset-vertical-slices.md): 29 bounded vertical slices with exact prompts, prerequisites, scenes/interactions, coverage and acceptance. Weapons/kit → SGC → characters/civilians → offworld → mothership → integrated run.
- [Shared agent workflow](../assets/ai-asset-workflow.md): evidence-based reuse of M9/P90/M249/crate/gate imports, authorized community acquisition, owner download cards, old-work recovery and clear technical versus owner art states.
- [Texture contract](../assets/texture-import-contract.md): PBR channels/colour spaces, alpha, trim scale, lighting, sharing/LOD/export and provisional measured budgets.
- [Strict work-order schema](../assets/asset-work-order.schema.json) with draft [rigid](../assets/asset-work-order-rigid.example.json) and [material](../assets/asset-work-order-material.example.json) requests. It describes requests, not licence approval or an already implemented importer. Sprint 7 consumes validation; Sprint 19 supplies the missing rig path.
- [Sourcing register](../assets/asset-program-sourcing.md): dated primary-source leads and explicit non-downloadable/uncleared references. No new binaries acquired. Entry-point guides and roadmaps route agents to this programme; Sprint 6 is correctly marked merged.

## Validation performed

Draft 2020-12 schema checked with the locally available Python `jsonschema` package; both draft examples passed, two synthetic ready controls and an animation-only request passed, and 18 malformed requests were rejected. Cases cover unknown fields, wrong normal/ORM/data conventions, premature ready state, missing rig, unsupported sprint, alpha cutoff, duplicate invariants, incompatible geometry kind, malformed URL, path traversal, wrong coordinate frame missing generation tool and mesh geometry in an animation-only request. Synthetic controls contain invented example measurements for validation only; they are not asset evidence.

All 29 table rows, detailed sprint entries and exact trigger prompts agree and remain planned. Relative link targets in changed Markdown and new-document fragment links were checked. Both draft target resources exist. `git diff --check` passed. The shared workflow includes a reproducible schema/example validation snippet; these planning checks do not install `jsonschema` as a game dependency.

Local Godot, GPU, four-player and export tests were not rerun for this documentation-only change. No runtime behavior changed. Hosted checks are reported on the PR against its actual head; do not reuse Sprint 6 results as a claim about this change. Implementation sprints must produce their own gameplay, multiplayer, export and owner-art evidence.

## Boundaries and remaining work

The current rigid packer loses skeleton/skin/animation and RGB8 map conversion loses alpha. Those are explicit consuming-slice prerequisites, not finished tools. M9/P90/M249 are retained; MP5/staff/Zat and later grips remain open. Existing source attribution must also reach distributed builds. Human art acceptance, including the corridor kit, remains pending.

Mothership scope covers boarding/interior objectives and an exterior vista using SGC plus one offworld site. Outdoor terrain, authoritative ring transport, civilian gameplay, flight and space combat need separately scoped capabilities. No changes were made to the old unfinished checkout or owner archives, and no additional project directory/worktree was created.
