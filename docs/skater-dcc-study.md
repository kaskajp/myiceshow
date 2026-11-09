# Skater-specific DCC export study

Status: **Blender-native source and calibrated export verified; both iOS scene and direct-skeleton playback/seeking exercised; not a production character or skating clip**. Evidence date: November 8, 2026.

## Scope and provenance

The retained [authoring/export workflow](../tools/SkaterDCCStudy/README.md) constructs a plain project-authored skater in **Blender 4.5.14 LTS** and saves an editable `.blend` before exporting USD. This is an actual headless DCC session—not merely exporter metadata on somebody else's file, or a handwritten USDA fixture repackaged as a DCC export. The saved `.blend` was reopened in a second Blender process and exported through the same retained function; that export passed the same calibration checks.

The body construction reuses the project's [fixture generator](../tools/generate-skater-fixture.py). It is still simple study geometry, not new artist-authored production topology. Native Blender bones, vertex groups, an Armature modifier, named materials, and a keyed calibration action are created explicitly. The blade ellipsoids are replaced with extruded curved runners and mounting geometry; they are part of the same skinned mesh, rigidly weighted to their corresponding ankle, not detached equipment.

No third-party character or animation is used in this study. Blender was run from a checksum-verified, code-signature-verified official macOS ARM64 application on a temporary read-only mount. The original isolated export study changed no permanent DCC installation, app dependency, main-app source, saved-show format, or app-bundled asset. Subsequently, one checked package snapshot was bundled for the separate [in-app native clip preview](native-clip-preview.md). Editable source, comparison reports, and recordings remain external generated outputs.

## Coordinate and source contract

- Native authoring coordinates are Blender Z-up, with the skater's forward direction along local **−Y**. The authoring mapping from lab `(x, height, forward)` is `(x, −forward, height)`.
- Export uses Blender's orientation conversion with forward selection **NEGATIVE_Z**, up **Y**, and metre units. The composed USD world-space result is lab **Y-up, +Z-forward**, with left/right signs preserved. Choosing forward selection **Z** instead produced mirrored left/right and reversed forward landmarks; the retained calibration check rejected that export.
- Fifteen deform bones have the same joint-path names and physical neutral landmarks as the fixture. Blender exports them in hierarchy order, which differs from the fixture's list order. Bone-local axes and rest rotations are native Blender axes, **not the fixture's identity-axis bind convention**. The source report retains the complete bone matrices.
- Neutral pelvis/ankle heights are 1.06 / 0.08 metres. Each runner spans forward −0.14 to +0.18 metres, is 0.004 metres wide, and includes an exact floor-zero sample. Its lower profile is a sampled parabola using a nominal 2-metre curvature parameter. These are study choices, not measured or coach-approved skate specifications.
- One mesh has **1,850 vertices, 3,144 triangles**, and Costume/Leggings/Skin/Boots/Blades/Hair material groups. There are no atlas textures or external asset references to repair during packaging.
- `Calibration_NotSkating` runs from frames **1–49 at 24 fps**: neutral → shoulder/elbow/spine bend → neutral, lasting **2 seconds**. Hips, legs, and ankles remain stationary. There is no skating footwork, jump flight, authored root motion, or transition blending.

The runners lack validated toe picks, hollow/edge geometry, pressure mechanics, and coach-reviewed rocker/contact behavior. A sampled floor-zero point does not establish realistic skating equipment or supporting-foot balance.

## Observed export checks

The retained validator evaluates the exported skin using OpenUSD and compares it to Blender-evaluated vertices at frames **1, 13, 25, 37, 49**. It checks the actual samples and matrices, not just declared bounds or metadata.

| Criterion | Observed result |
| --- | --- |
| Native Blender calibration deforms and returns | PASS: maximum vertex movement 0.52650010 m; return error 0 |
| USD and packaged USDZ pass `usdchecker --arkit` | PASS; no candidate-specific USD surgery required |
| Bind landmarks preserve neutral dimensions/orientation | PASS: maximum world-space position error approximately 0.000000083 m |
| Complete exported bind matrices preserve native Blender axes | PASS: matrix difference 0; rest/bind reconstruction difference approximately 0.000000044 |
| Per-vertex weights and palette indices | PASS: finite, nonnegative, normalized; maximum weight-sum error approximately 0.000000030 |
| USD skin deformation matches native source samples | PASS: maximum sampled vertex difference approximately 0.000000350 m, below the 0.00001 m threshold |
| Blades retain floor/toe/heel landmarks | PASS: both blades meet floor zero; sampled blade drift during this upper-body calibration is 0 |
| Reopened `.blend` exports independently | PASS: same calibration results; generated `.usdc` also matched a fresh generation byte-for-byte in this run |
| Existing output is protected | PASS: generation refuses an existing output directory; `.blend` and `.usdc` hashes remain unchanged |

Scratch negative checks also corrupted a weight sum, moved a bind landmark by 0.01 metres, and flattened the animation to its first pose. Each was rejected by the relevant retained validator check; the mirrored-axis export was rejected too. The mutation harness was temporary and is **not retained as a test suite**. The authoring, export function, comparison baseline generation, and positive/failing validator itself are retained.

These are five sampled export/deformation phases, not all-frame self-collision, garment, or physical contact validation. Byte identity in one run is not a cross-version reproducibility guarantee; USDZ container timestamps may differ.

## Observed native runtime checks

The retained [isolated playback app](../tools/CharacterPlaybackStudy/README.md) was built with the explicit `SKATER_DCC_STUDY` profile and run on an **iPhone 16 Pro simulator, iOS 18.6**. The native probe loads one model with 15 joints, six named materials, and two scene-level animation resources wrapping the two-second clip. The final diagnostic build succeeded with the App Intents metadata-extraction warning.

| Criterion | Observed result |
| --- | --- |
| Direct skeletal route seeks/repeats | PASS: nine out-of-order captures including exact endpoints; phase change 0.55965805; repeat/time error reported 0.00000000 |
| Original imported scene route seeks/repeats | PASS: the same nine captures and reported errors; this differs from the Rogue donor's failing scene route |
| Visible deformation | PASS: neutral and midpoint screenshots show shoulder/elbow/spine changes in the skinned body; not just a moving controller clock |
| Play, pause, and replay | PASS: direct-route pause holds 0.850222 seconds across separate snapshots; replay and both routes reach completion with nonzero observed joint change |
| Completion progress | PASS: final source displays and retains 2.000000 / 2.000000 seconds, including after the scene controller invalidates at natural completion; this is completed progress, not a live invalid controller clock |
| Wrong study profile | PASS: give the 15-joint package to the default 41-joint profile; import reports `unexpectedSkeleton`, disables controls, and does not switch profiles or fall back |

Both routes remain explicit; no fallback or procedural replacement is involved. The direct route extracts the sole imported skeletal track and requires its joint-name order to match the model. Seeking uses the native controller with readback after eight scene-update callbacks. The metric is the existing mixed local-transform difference, not world-space blade accuracy or angular error. Runtime pose readback is not a per-vertex iOS-vs-Blender comparison.

The scene route's recorded playback was inspected as ordered frame samples, showing the bend and return. Observed scene-update callback counts are not FPS or physical-device performance measurements. Playback clamps/pauses a still-valid controller at the authored endpoint; a naturally completed invalid scene controller is not made valid by the completed-time display. No independent accumulating animation clock is added.

No conclusion about arbitrary Blender exports follows from this one scene. It has no detached animated equipment, facial/blend shapes, or multiple clips. The Rogue donor's scene binding failure remains unresolved and has not been silently relabelled as fixed.

## Integration boundary and next gate

The main app's fixture adapter **rejects this asset with `incompatibleBindPose`**, despite matching joint names/count and a Costume material. It compares stored mesh-skeleton rest frames, parent relationships, and inverse bind matrices against the fixture contract. The [retained importer diagnostic](skater-fixture.md#repeatable-importer-checks) continues to accept the original fixture and verifies negative calibration cases and joint-order mapping. The separate native preview now bundles the DCC package as `SkaterCalibration.usdz`; it does not replace `SkaterFixture.usdz` or feed it procedural joint transforms. Native imported animation preserves its own bind frames; substituting the fixture sampler's transforms would not.

The rejection was also exercised in a separate temporary build of the main app on the iPhone 16 Pro / iOS 18.6 simulator. Studio reports the bind/rest failure with no silent substitute; Articulated remains an explicit user choice. This failure build uses a separate bundle identifier and does not replace the main app's fixture or saved shows.

The bounded native-preview path preserves the DCC frames rather than changing authoring to match the fixture. Its Show timeline mode now samples the same calibration from absolute routine time, keeping the native controller paused. It does not integrate production skating clips into saved routines. Next, assess the five proposed skating variants with reviewed clips and define transition/contact handling. The compatibility gate is not a retargeter; do not relax it around matching bone names. Production topology/outfit quality, toe/edge/contact mechanics, transition quality, coaching approval, and physical iPhone/iPad profiling remain open.
