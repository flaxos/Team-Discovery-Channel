# Sprint 19 — Airman and the shared rig

The uniformed Airman now plays skeletal motion in the existing SGC scene. The 0.90 m × 1.80 m capsule, root muzzle marker at `(0.25, 1.15, -0.60)`, damage origin and synchronizer retain their authored setup. Sprint 18 merged through #91. This branch also scopes the embarkation material fixture to its 35 original slots so it passes on the expanded SGC map. [Sprint 18 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/91) · [Airman scene](../../client/scenes/entities/SGCAirman.tscn) · [Sprint 19 scope](../plans/asset-vertical-slices.md#characters-and-animation).

## Source intake

The free Quaternius Universal Animation Library Standard archive was acquired through the creator’s itch.io download. Both licence files in this archive identify it as CC0 1.0. Its no-root-motion Godot GLB is 7,618,436 bytes with SHA-256 `69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997`. It has 43 named clips, one skinned mesh and 65 bones. Khronos validation found zero errors and one nested-skinned-mesh warning. This probe loads the original Godot GLB through `RuntimeGLB` and retains its skin and animation tracks. [Creator listing](https://quaternius.itch.io/universal-animation-library) · [Hashes and clip measurements](../assets/intake/sprint19-airman/ual1-standard.json).

The fitted body is DanlyVostok’s Military tactical suit. Its redistributed file identifies the original CC BY 4.0 model and retains the rig, fabric, webbing and normal maps. RedVeil’s download route returned no archive. The available BAMEN body uses untextured materials, so its credited retargeted animation file supplies the motion intermediary. Both exact Standard archives identify CC0. The project credits the source model, creators and retargeted source files. [DanlyVostok listing](https://sketchfab.com/3d-models/military-tactical-suit-lowpolygameready-ef698ce36b1545a78ce592dd3db4c7ed) · [Source hashes and terms](../assets/intake/sprint19-airman/tactical-source.json).

## First rig proof

The intake probe first loaded the Standard reference mannequin as a temporary child of `SGCAirman/Visuals` in the SGC mission. Idle, walk, jog, crouch idle, crouch walk and death sampled non-identical bone poses. The probe checked the Airman root, procedural body transform and muzzle marker through each sample.

```sh
godot --headless --path client --script res://tests/support/airman_rig_intake.gd -- \
  /tmp/tdc-asset-intake/sprint19-quaternius/UAL1_Standard.glb \
  Idle_Loop Walk_Loop Jog_Fwd_Loop Crouch_Idle_Loop Crouch_Fwd_Loop Death01
```

## Live rig

The prepared GLB keeps skin weights, 18 clips and a declared humanoid BoneMap. Its normal and packed maps use lossless PNG encodings of the decoded source images. The preparation tool compensates the source’s oversized vertex units in the inverse binds and omits the floating headset and detached mesh. The model faces the Airman’s authored forward axis at 0.96 scale. The original procedural body remains the fallback. [Preparation](../../tools/prepare_sprint19_airman.py) · [BoneMap](../../client/resources/characters/sgc_airman_bone_map.tres) · [Rest pose](../assets/intake/sprint19-airman/rest-pose.json) · [Measured work order](../assets/intake/sprint19-airman/work-order.json).

On the gate-room scene, two Airmen share the visual mesh and textures and animate their own skeletons. The active skin draws 24,159 triangles across 13 skinned surfaces, with 16 mipmapped textures totalling 34.0 MiB decoded. Godot reported 89 bones, including imported helper joints, and 53 mapped humanoid and finger joints. Khronos validation passed with 13 nested-skinned-mesh warnings. The Godot scene and Linux pack exercised those meshes with live skinning.

Movement speed and replicated AI state select the ready, travel, aim, crouch and recovery poses. The existing shot effects drive the cosmetic recoil on each peer. The standing recoil has a skeletal clip. Crouched recoil keeps the crouch pose and moves the shared cosmetic MP5. The weapon follows the hand anchors, and floor offsets sampled from the skinned model help keep boots and the downed body above the deck.

[Ready stance](sprint19-captures/ready.png) · [Standing aim](sprint19-captures/aim.png) · [Crouched aim](sprint19-captures/crouch.png) · [Downed](sprint19-captures/downed.png) · [Recovery](sprint19-captures/revived.png).

## Stationary turns and mounted M2

The standing Airman steps toward the replicated facing in alternating arcs. The support boot keeps its world-space contact while the other boot lifts and lands. A bounded pelvis drop keeps the support leg within reach. Movement and mounting return the rig to its regular stance controls. [Turn sequence](sprint19-captures/airman-stationary-turn.webp).

Two markers on the existing M2 aiming head locate the imported rear handles. Each Airman hand follows its marker through receiver yaw and pitch. The mounted pose uses the crouch stance and hides the carried MP5. Both host and peers resolve the gun from the existing replicated occupant path. The original receiver fallback keeps the aim pose when the imported handles are absent. [Mounted pose](sprint19-captures/airman-m2-mounted.png) · [Mounted after 113° of yaw](sprint19-captures/airman-m2-turned.png).

## Temporary squad and staff model

O’Neill, Carter, Teal’c and SG-3 Heavy now wear the same temporary uniform as Airman Davis and Sgt Siler. They share the model, textures and animation clips, with a separate skeleton per character. Each class still has its callsign, loadout and abilities. Enemy Jaffa still use their existing visuals. Later character sprints own distinct operative appearances and civilian roles.

The player rig layers the existing movement, stance, health and fire events onto the shared clips. The six carried weapon visuals follow the rig’s hands. Tracers originate from the drawn barrels while combat uses the existing authoritative muzzle markers. On the M2, the visible player uses the receiver’s facing and both handle markers. If the character GLB is missing, the original player and NPC bodies appear automatically.

[Four operatives with Davis and Siler](sprint19-captures/squad-placeholder.webp) · [Player mounted after a 113° turn](sprint19-captures/squad-placeholder-m2.webp).

## Verification

- The live Airman fixture passed movement-driven pose selection, crouched and standing fire poses, downing, recovery, death, shared mesh and mipmaps, and the original capsule and muzzle marker checks.
- The turn fixture steps both ways through 92° at the same actor position. It checks both foot lifts and keeps the support ankle within 1.3 cm of its planted target. The mount fixture checks both palms within 3.5 cm of the handle centres at three headings, including two turns past 90° with pitch, and verifies the anchored tripod, muzzle marker and dismount.
- The dedicated late-join fixture verified Davis downed and Siler gripping a turned M2 on arrival. Retry produced standing Davis and released Siler’s old mount. Friendly and hostile SGC route checks, tactical anchors and the embarkation material fixture passed.
- The four-player listen and dedicated fixtures verified the shared squad skin during gate travel, replacement joins and retry. The local rig fixture checked independent skeletons, shared meshes, the six held weapon fits, proximity fade and a player’s M2 stance after a 113° turn.
- The listen and dedicated M2 fixtures verified that the operative stays behind the turned receiver and reaches both grips on the server, owning client and late-joining client.
- The Linux pack loaded the Airman and all four squad skins, exercised the mounted grips and opened the 22-entry credits UI. The pack that excludes the character GLB verified both procedural bodies and the Airman’s downing and recovery. A pack with the M2 GLB excluded verified the original receiver and the standing aim pose for both operators.

Owner art review remains open.
