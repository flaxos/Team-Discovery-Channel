# Community asset intake and integration

Status checked **18 November 2026**, against main `7982e2b` (Sprint 6 / PR #77). Next execution is the [community-first vertical-slice programme, Sprints 7–35](asset-vertical-slices.md), using the [shared AI workflow](../assets/ai-asset-workflow.md), [texture contract](../assets/texture-import-contract.md) and [generation work-order schema](../assets/asset-work-order.schema.json). This is an implementation guide and the boundary between research, staging and game integration. A catalogue entry is not an imported or accepted asset.

The research and ranked candidates are in the [asset handoff](../assets/README.md), [static shortlist](../assets/community-static-shortlist.md) and [characters/animation shortlist](../assets/community-characters-animation-shortlist.md). Keep exact creator pages and observed licence evidence with each candidate; generic marketplace search links do not establish permission or quality.

## What is implemented

| Part | Current code and limitation |
|---|---|
| External weapons (AP-1a) | `WeaponBase.GLB_MODELS` contains realistic community `p90`, `m9` and `m249`, plus the Sprint 7 WillyG99 `mp5sd.glb`. The former Kenney MP5 stand-in remains retained and credited. Staff and Zat remain procedural. [Attribution](../../credits/ATTRIBUTIONS.md) identifies actual source models; the next programme retains the realistic imports and finishes the remaining mesh/material/grip matrix. |
| Runtime GLB loading | `WeaponBase.load_glb_model` uses `GLTFDocument` and `GLTFState`. The checked-in runtime GLBs use `importer="keep"` to avoid the editor thumbnail failure observed in headless CI. This bypasses the editor import pipeline, so do not assume editor-generated LODs, import scripts or retargeting settings apply. |
| Runtime GLB loading for props (AP-1c) | `RuntimeGLB.load_scene` reads the `res://` bytes and calls `GLTFDocument.append_from_buffer`, so it does not depend on `globalize_path`. Checked from a Linux release export. The same `importer="keep"` rule applies |
| Weapon model cache (AP-1d) | `WeaponBase.load_glb_model` parses and sanitizes each weapon GLB once per session and keeps it as a `PackedScene` on the tree root; every copy shares meshes and materials. The first M9 takes about 59 ms, later ones about 0.1 ms. `RuntimeGLB.add_mipmaps` gives runtime-loaded textures mipmaps for both weapons and props |
| Model packer (AP-1d) | `client/scripts/assets/pack_model_glb.gd` converts a staged FBX, glTF, GLB or already imported COLLADA scene into one game GLB from a JSON recipe kept with the intake record: chosen nodes, maps bound per material, downscaling, DirectX normal flip and ORM packing. Orientation and sockets belong in the wrapper. This is a rigid mesh reconstruction path, not a skin/animation-preserving converter; map decoding converts to RGB8 and can discard alpha. Use the texture contract before extending it. Packing is reproducible for the recorded tool/input versions |
| SAW visual (AP-1f) | `m249` loads the CC BY 4.0 model by AK / skaf13, converted from nested COLLADA in an isolated staging project. Measured bore aligned to the unchanged muzzle; part-ID vertex colours ignored at runtime; original procedural fallback. Extended bipod is fused into the mesh ([record](../reviews/2026-11-16-ap1f-m249.md)) |
| Prop wrapper (AP-1c) | `CrateStackVisual.dress_box` fills a `CSGBox3D` with whole crates at a uniform scale (0.9 to 1.1), validates the result against the box with the same 0.02 m allowance as `SGCMap.replace_asset_visual`, adds no collision, and only then stops drawing the box. Runtime material changes leave the GLB untouched. Used by the SGC armoury ammo crates ([record](../reviews/2026-11-16-ap1c-plastic-crate.md), D-018) |
| Material treatment | The current weapon loader duplicates imported materials and sets `metallic = 0.0`. D-015 arose because metallic Jaffa became dark without a sky or reflection probes. It does not mean all PBR assets are production-lit or that source textures should be permanently flattened. Keep originals and test wrapper overrides in mission lighting. |
| Player and NPCs | `Player.tscn`, `SGCAirman.tscn`, `JaffaGuard.tscn` and `JaffaShockGuard.tscn` still use procedural meshes. No shared humanoid skeleton, animation library or character retargeting adapter exists. |
| Rigid gate visual (AP-1g) | `StargateVisual` fits the imported glyph ring and seven source chevron inserts to the current opening/anchors; reads the existing replicated chevron count for lighting; retains original visuals on load/fit failure. Source body/nine-chevron arrangement omitted. Owner authorized inclusion on 17 November 2026 with the missing uploader-authorship evidence documented ([record](../reviews/2026-11-16-ap1g-stargate.md)) |
| Gate and DHD | `scenes/props/Stargate.tscn` has seven controlled chevrons (`StargateRing.max_chevrons = 7`); its event horizon, extraction and kawoosh are gameplay nodes. `DHDConsole.tscn` has box meshes and an interaction area. No contract for nine articulated chevrons, inner-ring spinning or a generic `iris_open_ratio` exists. |
| Modular art | Theme replacements are cosmetic and must preserve D-010: collision, sockets, footprints and navigation. Use the [authoring CLI](../maps/ai-level-authoring.md) for layout inspection/changes; imported meshes do not redefine native `LevelLayout` resources. |

Sprint 6 recovered the corridor subset of the former SW-1 work into main. Other AP-1b stand-ins and later chamber work remain in the old mixed commit/checkouts, with uncommitted mission/theme work. Inspect before replacing and preserve their working files; see the shared workflow for the recovery boundary.

## Intake before inserting a model

1. **Research:** record title, creator, exact source page, licence version and evidence, download conditions and intended scene. Inspect creator restrictions as well as the platform badge. Mark missing evidence explicitly.
2. **Stage:** obtain an authorized archive outside `client/`, for example `/tmp/tdc-asset-intake/<candidate>/`. Preserve its README and licence. Record archive and model SHA-256 hashes; verify that the archive agrees with the public page. Do not install downloaded scripts or add-ons to inspect a mesh.
3. **Inspect:** run the offline tool below, then a full glTF validator and Godot import. Measure transformed bounds and orientation in the engine. Counts, materials and rig names alone do not establish fidelity or fitness.
4. **Prepare one cosmetic wrapper:** retain the existing actor/prop root, authority, collision, interaction areas, combat origins and navigation. Normalize the visual child’s scale and facing, then place explicit visual sockets. Preserve source material data and record modifications.
5. **Verify:** capture the asset in actual SGC and offworld lighting, test the relevant interactions and multiplayer snapshot/late join, and smoke-test an exported build. Only after that add production binaries, complete credits/licence files and the review evidence in the same milestone PR.

Use the [intake record template](../assets/intake-record.template.json). It is an editable handoff form, not an automatically enforced licence schema. Its initial `research_only` status deliberately leaves measurements and acceptance evidence blank.

### Offline inspection

```sh
python3 tools/asset_intake.py /tmp/tdc-asset-intake/candidate/model.glb --output build/asset-intake/candidate.json
python3 tools/asset_intake.py client/assets/weapons/p90_smg.glb
python3 tools/gltf_to_glb.py /tmp/tdc-asset-intake/candidate/model.gltf /tmp/tdc-asset-intake/candidate/model.glb
python3 -m unittest discover -s tools/tests -v
```

The standard-library tool does not import or rewrite the source. It reports SHA-256, size, declared unique-mesh triangle counts, attributes, mesh-local declared bounds, node/joint/animation names, material factors, declared image embedding and required extensions. It rejects malformed GLB framing, bad basic references/counts/bounds, and external URI dependencies; data URIs are self-contained. Its JSON chunk limit is 32 MiB. A report path cannot alias the source, including via a hard link.

`ok: true` means this limited inventory completed. It is **not** full glTF validation, licence clearance, a triangle/frame budget, scene-space dimensions, texture resolution verification, skeleton compatibility or engine/export acceptance. Instanced meshes, transforms, skin deformation and animation may change actual bounds and rendering cost. It never follows an external URI or certifies a metadata claim against decoded vertex/image bytes. Use the [Khronos glTF Validator](https://github.com/KhronosGroup/glTF-Validator) for full format validation. The GLB framing/declaration basis is the [glTF 2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html).

## Engine and gameplay attachment contracts

Godot 4.4 recommends glTF 2.0 and supports FBX through ufbx. Its editor import path can generate LODs and configure scenes; its runtime GLTFDocument path generates a scene without those editor steps. Choose and test a path per asset. Self-contained GLB is the preferred repository deliverable, not a claim that any FBX/Blend download is already converted. See [Godot formats](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) and [import configuration](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html).

| Target | Preserve and prove |
|---|---|
| Weapon | `WeaponModel/ImportedGLB` is visual. Keep the weapon ID, stats and authoritative fire logic. Measure the receiver and barrel against `MuzzlePoint`; the current game’s weapon convention fires toward local `-Z`. Check muzzle flash/tracer, ADS, camera clipping, crouch and carried state through gate travel. |
| Gate | Keep `StargateRing`, the seven existing controlled chevrons, event horizon shader, extraction trigger, authorization and kawoosh area. Map imported subparts explicitly; a generic multi-mesh model will not animate itself. Check inbound/outbound, iris interaction, return travel and late-join gate state. |
| DHD/console | Replace visible meshes while retaining `DHDDialer`, interaction radius, prompt/console connections and server validation. Confirm the prompt and the visual operating surface coincide. |
| Character | Preserve the `CharacterBody3D`, collision, `HealthComponent`, `WeaponHolder`, camera, nameplate and synchronizer. Add a visual rig adapter under `Visuals`; map animation state from existing replicated movement/combat flags. Do not drive authoritative movement from unvalidated root motion. |
| Theme/prop | Place only cosmetic meshes/materials in existing slots or visual wrappers. Match measured slab/attachment dimensions. Run theme collision/navigation parity and enclosure checks; avoid imported collision/navigation generators or import-name suffixes that silently create gameplay nodes. |

Godot’s oriented-asset convention uses **+Z as model front**, while this game’s weapon and procedural actor visuals use **-Z**. Measure and rotate the wrapper rather than mirroring physics or changing AI facing. Apply/record scale and rest pose; do not treat mesh-local accessor bounds as world dimensions. [Godot model conventions](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html).

For characters, `SkeletonProfileHumanoid`, a tested `BoneMap` and explicit hand/back sockets are future work. One animation library does not automatically suit every mesh: verify rest pose, bone mapping, proportions, weapon grip, feet, root motion and down/revive/body-drag transitions on each rig. Choose a small locomotion proof before a full player swap.

The runtime GLB workaround raised a separate export question: are raw files included in the export, and does runtime loading find them in a clean exported build? AP-1c historically answered it for 4.4.1 on Linux with a throwaway preset in a project copy. **Do not repeat the copy workflow:** AGENTS.md now requires this checkout, ignored `build/` outputs and exact restoration of temporary preset changes. The raw `.glb` files are packed, `RuntimeGLB` loads the crate from the pack, and `WeaponBase.load_glb_model` also loads the P90, because `globalize_path` returns a relative path there that `FileAccess` resolves through the pack. A headless editor-import pass alone does not prove packaging, and still **no export preset is committed**. Repeat the check when one is added or the engine changes.

`tools/gltf_to_glb.py` packs a staged `.gltf` with separate `.bin` and image files into one GLB. It changes only the container: buffer and image bytes are copied unchanged, and URIs outside the source folder, network URIs and data URIs are refused. Record that packing in the intake record as a modification.

## Provenance and redistribution

Record exact creator/source, licence text/version, required attribution, modifications, archive licence evidence and local file hashes. Bundle the applicable full licence text under `credits/licenses/` and list committed assets in `credits/ATTRIBUTIONS.md`. Research-only candidates belong in the shortlists, not in the manifest of shipped assets.

The owner’s existing authorization permits creator-modelled CC0/CC-BY community Stargate fan models with attribution. It does not turn an NC/ND or contradictory licence into CC-BY, establish an uploader’s rights, or grant underlying franchise rights. Keep generic assets and community fan models identified separately. Do not present a platform badge as sufficient when creator terms conflict.

Mixamo and other download services may permit game use while restricting raw asset redistribution; a public source repository must satisfy both. Use the [rig shortlist](../assets/community-characters-animation-shortlist.md) for current primary-source findings. Paid purchases, account-only downloads, unclear archive licences and unverified texture/rig details remain explicit handoff items, not completed imports.

## Milestone status and next execution

| Milestone | Current boundary |
|---|---|
| AP-1b recovery | Prior stylized stand-ins require provenance/quality review; do not overwrite current realistic M9/P90/M249. |
| AP-1c–f rigid proofs | Crate, M9, P90 and M249 integrated and merged; owner art review remains separate. Worked reviews and recipes are indexed in the shared workflow. M249 fused bipod and repeated crate scene cost remain explicit defects. |
| AP-1g gate | Glyph ring/seven inserts integrated; source body omitted; recorded owner exception and missing authorship evidence remain visible. |
| Rig/animation | No production humanoid adapter or complete tactical set yet. Sprint 19 proves the route in a live Airman encounter; a preview is only an intermediate check. |
| Sprint 7 infrastructure | `asset_work_order.py` and `asset_intake.py --work-order` validate ready requests and declared budgets. Generated `asset_credits.tres` supplies lobby credits/full licence text in the export from the maintained manifest. The owner-downloaded WillyG99 MP5SD is integrated with measured crown alignment, two shared 2K material sets and lossless PNG; [review](../reviews/2026-11-18-sprint7-mp5-intake.md). |
| Next programme | [Sprints 7–35](asset-vertical-slices.md): weapons/kit → SGC → characters → offworld → bounded mothership → integrated acceptance. The programme is planned, not shipped. |

Keep source, implementation, evidence and credits together. Report local and hosted results separately and track human art acceptance. Follow AGENTS.md for workspace and delivery; an explicit commit-and-merge request authorizes completing that merge after checks without another confirmation.
