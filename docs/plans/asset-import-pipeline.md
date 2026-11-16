# Community asset intake and integration

Status checked **16 November 2026**, against `origin/main` at `f45e909` (TA-3); AP-1c rows updated the same day from `1a5146a`. This is an implementation guide and the boundary between research, staging and game integration. A catalogue entry is not an imported or accepted asset.

The research and ranked candidates are in the [asset handoff](../assets/README.md), [static shortlist](../assets/community-static-shortlist.md) and [characters/animation shortlist](../assets/community-characters-animation-shortlist.md). Keep exact creator pages and observed licence evidence with each candidate; generic marketplace search links do not establish permission or quality.

## What is implemented

| Part | Current code and limitation |
|---|---|
| External weapons (AP-1a) | `WeaponBase.GLB_MODELS` contains `p90` and `mp5` and, since AP-1d, `m9` (the realistic CC BY Beretta M9). These are generic, stylized Kenney models, not high-fidelity or exact reproductions of those firearms. Their names are game weapon IDs; [attribution](../../credits/ATTRIBUTIONS.md) identifies the actual source models. |
| Runtime GLB loading | `WeaponBase.load_glb_model` uses `GLTFDocument` and `GLTFState`. The two files use `importer="keep"` to avoid the editor thumbnail failure observed in headless CI. This bypasses the editor import pipeline, so do not assume editor-generated LODs, import scripts or retargeting settings apply. |
| Runtime GLB loading for props (AP-1c) | `RuntimeGLB.load_scene` reads the `res://` bytes and calls `GLTFDocument.append_from_buffer`, so it does not depend on `globalize_path`. Checked from a Linux release export. The same `importer="keep"` rule applies |
| Weapon model cache (AP-1d) | `WeaponBase.load_glb_model` parses and sanitizes each weapon GLB once per session and keeps it as a `PackedScene` on the tree root; every copy shares meshes and materials. The first M9 takes about 59 ms, later ones about 0.1 ms. `RuntimeGLB.add_mipmaps` gives runtime-loaded textures mipmaps for both weapons and props |
| Model packer (AP-1d) | `client/scripts/assets/pack_model_glb.gd` converts a staged FBX, glTF or GLB into one game GLB from a JSON recipe kept with the intake record: chosen nodes, maps bound per material, downscaling, DirectX normal flip and ORM packing. Geometry, UVs and units are untouched; orientation and sockets belong in the wrapper. Same recipe, same bytes |
| Prop wrapper (AP-1c) | `CrateStackVisual.dress_box` fills a `CSGBox3D` with whole crates at a uniform scale (0.9 to 1.1), validates the result against the box with the same 0.02 m allowance as `SGCMap.replace_asset_visual`, adds no collision, and only then stops drawing the box. Runtime material changes leave the GLB untouched. Used by the SGC armoury ammo crates ([record](../reviews/2026-11-16-ap1c-plastic-crate.md), D-018) |
| Material treatment | The current weapon loader duplicates imported materials and sets `metallic = 0.0`. D-015 arose because metallic Jaffa became dark without a sky or reflection probes. It does not mean all PBR assets are production-lit or that source textures should be permanently flattened. Keep originals and test wrapper overrides in mission lighting. |
| Player and NPCs | `Player.tscn`, `SGCAirman.tscn`, `JaffaGuard.tscn` and `JaffaShockGuard.tscn` still use procedural meshes. No shared humanoid skeleton, animation library or character retargeting adapter exists. |
| Gate and DHD | `scenes/props/Stargate.tscn` has seven controlled chevrons (`StargateRing.max_chevrons = 7`); its event horizon, extraction and kawoosh are gameplay nodes. `DHDConsole.tscn` has box meshes and an interaction area. No contract for nine articulated chevrons, inner-ring spinning or a generic `iris_open_ratio` exists. |
| Modular art | Theme replacements are cosmetic and must preserve D-010: collision, sockets, footprints and navigation. Use the [authoring CLI](../maps/ai-level-authoring.md) for layout inspection/changes; imported meshes do not redefine native `LevelLayout` resources. |

The former SW-1 branch has additional committed AP-1b weapons and GA-2 work outside `main`, plus uncommitted mission/theme work. Inspect it before starting a replacement milestone; preserve its working files.

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

The runtime GLB workaround raised a separate export question: are raw files included in the export, and does runtime loading find them in a clean exported build? AP-1c answered it for 4.4.1 on Linux with a throwaway preset in a copy of `client/` outside the repository. The raw `.glb` files are packed, `RuntimeGLB` loads the crate from the pack, and `WeaponBase.load_glb_model` also loads the P90, because `globalize_path` returns a relative path there that `FileAccess` resolves through the pack. A headless editor-import pass alone does not prove packaging, and still **no export preset is committed**. Repeat the check when one is added or the engine changes.

`tools/gltf_to_glb.py` packs a staged `.gltf` with separate `.bin` and image files into one GLB. It changes only the container: buffer and image bytes are copied unchanged, and URIs outside the source folder, network URIs and data URIs are refused. Record that packing in the intake record as a modification.

## Provenance and redistribution

Record exact creator/source, licence text/version, required attribution, modifications, archive licence evidence and local file hashes. Bundle the applicable full licence text under `credits/licenses/` and list committed assets in `credits/ATTRIBUTIONS.md`. Research-only candidates belong in the shortlists, not in the manifest of shipped assets.

The owner’s existing authorization permits creator-modelled CC0/CC-BY community Stargate fan models with attribution. It does not turn an NC/ND or contradictory licence into CC-BY, establish an uploader’s rights, or grant underlying franchise rights. Keep generic assets and community fan models identified separately. Do not present a platform badge as sufficient when creator terms conflict.

Mixamo and other download services may permit game use while restricting raw asset redistribution; a public source repository must satisfy both. Use the [rig shortlist](../assets/community-characters-animation-shortlist.md) for current primary-source findings. Paid purchases, account-only downloads, unclear archive licences and unverified texture/rig details remain explicit handoff items, not completed imports.

## Next insertion milestones

| Milestone | Concrete boundary and completion evidence |
|---|---|
| AP-1b recovery | Review the four committed follow-up weapon models and their provenance before duplicating that work. They are stylized stand-ins, not the high-fidelity shortlist. |
| AP-1c static high-fidelity proof | **Done on `feat/ap1c-crate-cosmetic-proof`; owner art review pending.** The M9 was blocked on a Sketchfab account download, so the documented fallback was used: the CC0 Poly Haven crate dressing the SGC armoury ammo crates, with intake, validator, captures, late-join/retry checks and a clean exported build ([record](../reviews/2026-11-16-ap1c-plastic-crate.md)). A weapon proof (M9, then P90/M249) is still next once an account download is available. No character-system changes. |
| AP-1d first realistic weapon | **Done on `feat/ap1d-m9-weapon-visual`, stacked on AP-1c; owner art review pending.** The CC BY 4.0 Beretta M9 replaces the sidearm boxes with its bore on the unchanged `MuzzlePoint`, through the packer, the weapon cache, SGC/offworld captures and an exported build ([record](../reviews/2026-11-16-ap1d-beretta-m9.md)). P90 and M249 follow the same recipe route; see the [playbook](../assets/community-asset-playbook.md). |
| AP-2a rig proof | One redistributable rig plus a legally redistributable idle/walk set in a preview scene; tested rest pose, `BoneMap`, facing/units and hand socket. Then wire one NPC visual adapter; keep player and Jaffa controllers authoritative. |
| AP-3 faction/scene polish | After the static and rig proofs: articulated Stargate parts, Jaffa armor and theme PBR surfaces, each retaining the existing gameplay contract. |

Publish one milestone per draft PR, report local and hosted results separately, and leave merging and human art acceptance to the owner.
