# Sprint 20 — Serpent Jaffa fitting preview

The standard offworld guard can wear the downloaded Serpent helmet on the Sprint 19 rig in a local Goa’uld Infiltration playtest. The head attachment is aligned to the rig’s initial ready pose, then follows the head through movement, alert and stun. The body uses darkened skinned clothing and native chest, shoulder and shin plates. The normal game still uses the existing guard. [Original native fitting preview](sprint20-serpent-preview.webp).

## Downloaded assets

| Candidate | Intake and decision |
|---|---|
| AJS’s Serpent Guard’s Helmet | **Fitted locally.** The owner archive matches the listed `HeadGear_LP.fbx` and five 2K maps. The source contains 771 faces, corresponding to 1,491 triangles, across distinct eye, head, neck and back meshes. The listing offers CC BY 4.0. Its description and the blank FBX Author field leave authorship unconfirmed under the repository’s redistribution rule. [Creator listing](https://sketchfab.com/3d-models/serpent-guards-helmet-5c5d2555b447405ab2fa8434ffcfd74e) |
| merlincodes’ Jaffa | **Reviewed and set aside.** The 2,056-triangle GLB uses a colour palette map, one 16-joint skin and separate rigid helmet, chest and skirt meshes. `Base` and `Base.001` are single-pose clips. The four timed clips are `Idle`, `handAttack`, `handMove` and `recoil`. The body lacks the surface detail and patrol, crouch and downed animation coverage this slice needs. [Creator listing](https://sketchfab.com/3d-models/jaffa-8a1b28c4a1dc4a4d81f7ef5531aa480d) |
| Balazs Szeleczki’s Royal Jaffa | Download disabled and tagged NoAI. [Creator listing](https://sketchfab.com/3d-models/stargate-royal-jaffa-fanart-17cfeeef444a43c1a0c57e5d8b933ed6) |
| TurboSquid Jaffa | Editorial-only terms. [Creator listing](https://www.turbosquid.com/3d-models/3d-jaffa-stargate/521423) |

The rigid packer retained all four helmet meshes and UVs. It resampled source base colour and OpenGL normal to 1536 pixels, packed the roughness and metallic channels with neutral AO, and stored the resulting maps as PNG. The source specular map was reviewed as an alternate input for a specular workflow. Godot uses the metallic workflow here. All fitted guards share the three mipmapped helmet textures, which use 33.0 MiB decoded. Khronos validation reported zero errors and warnings for the prepared helmet, plus one non-root skinned mesh warning and zero errors on the original body. [Source and prepared hashes](../assets/intake/sprint20-serpent-sources.json) · [Helmet pack recipe](../assets/intake/sprint20-serpent-helmet-recipe.json) · [Draft character work order](../assets/intake/sprint20-serpent-work-order.json).

## Gameplay fit

The guard retains its 0.45 m radius, 1.90 m high capsule and the local staff muzzle `(0, 0, -1.10)`. The fitted helmet sampled 0.384 × 0.430 × 0.531 m in the guard frame at ready, with its top at 1.76 m below the 2.45 m awareness tell. The guard’s movement, crouch and health state drive the visual clips. The ready staff’s support palm comes within 3 cm of its target. The existing Zat light still reads across the helmet and armour.

The local preview retains a native helmet when started with `--serpent-preview` alone. For the downloaded helmet, the repacked GLB stays under ignored `build/` with the recorded original archives in local intake. To open the preview, start Godot with both flags and select Goa’uld Infiltration.

```sh
godot --path client -- --serpent-preview \
  "--serpent-helmet=$PWD/build/asset-review/sprint20-serpent-intake/serpent_guard_helmet.glb"
```

Local captures show [the ready guard](../../build/asset-review/sprint20-serpent-intake/serpent-ready.png), [helmet detail](../../build/asset-review/sprint20-serpent-intake/serpent-helmet-detail.png), [the back fit](../../build/asset-review/sprint20-serpent-intake/serpent-back.png), [the alert pose](../../build/asset-review/sprint20-serpent-intake/serpent-alerted.png) and [the Zat stun](../../build/asset-review/sprint20-serpent-intake/serpent-stunned.png). The [downloaded body comparison](../../build/asset-review/sprint20-serpent-intake/jaffa-source-body.png) shows the original palette finish. Captures use Godot Forward+ on Mesa llvmpipe.

Five targeted Godot 4.4.1 suites passed on the normal path. With the external helmet loaded, the stealth fixture verified muzzle position, staff fire, stun, takedown, dragging and vaporization. A two-peer alert fixture checked the helmet on late join, shared mesh resources and retry. The exported Linux pack passed the same stealth fixture with the local GLB and loaded all 25 existing community credits and both licence texts.

## Remaining acceptance

The downloaded helmet is ready for local art review. Public integration depends on the project’s creator-authorship gate. The body finish and its full motion-clearance review are still open.
