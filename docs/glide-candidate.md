# Intended LFO sustained-glide candidate

Status: **unreviewed project-authored motion, not approved skating or production art**. Prepared after published checkpoint `baf546a`. No app resource, runtime, move library, or saved-show format changes are included.

## Bounded authoring target

This is the first native skating-motion candidate, following the proposed left-forward-outside glide in the [five-move review brief](move-validation-brief.md). It is a reviewable hypothesis, not a claim that the variant has been signed off. No footage, extracted motion, external character, or traced pose is incorporated.

The retained Blender script builds the existing 15-joint study body and curved runners, then keys a three-second sustained one-foot pose along a left-turning circular arc. The left runner's outer lower contact stays on the plane; the right blade stays lifted behind. Native bone frames are preserved. A fixed-length two-bone solve authors the knees/elbows offline; this is not a runtime retargeter or pose replacement.

Authored parameters: 24 fps, frames 1–73, 1.2 m/s support-contact speed, four-metre radius, 3.6 metres of arc travel, and 0.9 radians of heading change. The bank uses the illustrative point-mass lean `atan(v² / (gR))`, approximately 2.10 degrees. That is an authoring choice, not a measured blade-edge angle, whole-body balance simulation, or coaching prescription. The toy runner has no validated hollow or toe-pick mechanics.

## Entry, exit, and ownership

- **Entry:** already in motion on the left support foot, right foot free. The clip contains no push-off, free-foot lift, or transfer from two feet.
- **Exit:** still moving on the left support foot with the right foot free, after the authored heading/path change. There is no stop, free-foot placement, or transfer to another move.
- **Root travel:** baked into the pelvis joint's native skeletal samples. The armature object and scene transforms stay static. Do not also apply the procedural rink's circular root placement or heading: that would double-apply travel.
- **Timing:** authored at one rate. Do not treat slower/faster playback as validated skating, or invent entry/exit states by interpolation.
- **Transitions:** no production pair is approved. In particular, the calibration preview's restart-per-slot/end-hold policy must not be reused for this moving clip: holding its last frame would stop travel abruptly, and restarting would teleport it. A connector must preserve actual support state, heading, placement, velocity, and feasible contact transfer.
- **Mirroring:** no right-foot or opposite-direction variation is approved by this candidate.

Review still needs to settle actual edge/body mechanics, free-leg position, support-knee action, balance, blade path, twist, entry/exit velocity, collisions, and a rights-documented correct-execution example. The plain tube/ellipsoid body, outfit seams, and skin weights remain study art. Mathematical contact tolerances below are not production skating tolerances.

## Reproduce

Use the trusted Blender 4.5 LTS toolchain from the [DCC study](../tools/SkaterDCCStudy/README.md). The observed build used 4.5.14 LTS, build `62c1db4208e8`. No new package or permanent Blender installation is required. Run from the repository root and use a fresh output directory:

```sh
export BLENDER=/path/to/Blender.app/Contents/MacOS/Blender
export GLIDE="$(mktemp -d /tmp/myiceshow-glide.XXXXXX)/output"
export PYTHONDONTWRITEBYTECODE=1

"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/build-glide.py -- --output "$GLIDE"
usdchecker --arkit "$GLIDE/GlideCandidate.usdc"
usdzip --arkitAsset "$GLIDE/GlideCandidate.usdc" "$GLIDE/GlideCandidate.usdz"
usdchecker --arkit "$GLIDE/GlideCandidate.usdz"
"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/validate-glide.py -- \
  --asset "$GLIDE/GlideCandidate.usdz" --source-report "$GLIDE/source-report.json"
```

Outputs are editable `GlideCandidate.blend`, skeletal `GlideCandidate.usdc`, the packaged USDZ, and a comparison report. They stay outside the repository/app; normal app builds are unchanged. The generator rejects an existing directory; export rejects an existing filename. The report is a paired native baseline for this exact generated asset, not a trusted signature or a generic asset contract. Intentional edits need a new inspected baseline.

## Observed technical checks

The native Blender pose reaches its authored joint targets with maximum head-position error `1.16801e-6` metres and unit bone scale. Both USD layers/package pass `usdchecker --arkit`. The retained validator skins the exported mesh at all 73 integer frames and 72 half frames:

| Metric | Observed result |
| --- | --- |
| Supporting outside-edge/floor error | Maximum `5.45675e-7` m |
| Free right-blade clearance | Minimum `0.1999996` m |
| Support contact versus authored arc | Maximum `7.76773e-5` m, including between-frame interpolation |
| Horizontal blade-heading vector error | Maximum `8.34365e-6` |
| Export versus native skinned vertices | Maximum `8.92081e-7` m across the retained native comparison phases |
| Ice penetration | Maximum numerical residual `1.50990e-7` m |

The geometric gates use `1e-5` metres for floor/mesh agreement, `1e-4` metres for path interpolation, and `1e-4` for the unit heading-vector difference. The approximately 0.078 mm path deviation reflects sampled interpolation, not exact continuous circular travel. Native comparison includes integer and half-frame phases; the validator fails if a supplied baseline frame is absent from its comparison grid. Mesh points are not vertex-animated; the validator rejects animated placement on the root, skeleton, mesh, and their transform ancestors up to a reset-transform boundary. Scene/root travel must remain in the skeletal track.

The existing macOS RealityKit native-loader diagnostic accepts this package and preserves its authored frames, joint order, and three-second duration. The procedural fixture importer still rejects its incompatible native bind frames. A native Blender pose render was inspected to confirm the visible lifted free foot and planted support runner; it is not coaching review. The subsequent isolated iOS checks are recorded below; no per-vertex iOS/Blender equivalence or physical-device performance has been measured.

Scratch negative checks lift the root by 0.01 metres and freeze its motion; the retained validator rejects both. Reusing the generator's output directory is rejected with source/export hashes unchanged. Those mutation/render harnesses are **not retained as a test suite**; the generator and validator are retained.

Observed internal USD SHA-256: `7f02fdd3a701663271b470dc9d1bf3f7819d8fc481a7b98b7e6ce7baead9405a`. Observed package SHA-256: `8132fe92c861f085db58deed121b243094e3672035c1eacce30a65429cf44581`. Archive bytes may change with packaging metadata. No production approval follows from either hash.

## Isolated iOS root-motion study

The retained [playback diagnostic](../tools/CharacterPlaybackStudy/README.md#glide-candidate) now has an explicit `SKATER_GLIDE_STUDY` profile. The package stays in a temporary build of `dev.myiceshow.characterstudy`, not in My Ice Show. The default external-donor and two-second calibration profiles still build independently.

The imported scene route and direct skeletal route remain separate choices. At each of nine out-of-order sample times, the profile waits eight scene-update callbacks, reads the actual joint transforms, and compares them with the imported authored frame. It also requires the model's world transform to remain equal to the imported static node transform, so pelvis-root travel cannot silently be lost, changed, or applied a second time outside the skeleton. These local-transform and matrix-element error measures are not metre/angular tolerances for real skating contact.

Observed on iPhone 16 / iOS 18.6:

| Criterion | Observed result |
| --- | --- |
| Direct skeletal seeks | PASS: nine captures; reported repeat/time/authored/node errors all `0.00000000`; phase difference `3.44845986` |
| Original scene-route seeks | PASS: same nine captures and reported errors; no fallback or procedural replacement |
| Visible native travel | Both recordings inspected as ordered frame samples; the body moves through the arc and changes heading against the static plane/camera, rather than only advancing a clock |
| Completion/end pose | Both routes reach 3.000000 / 3.000000 seconds; an additional readback eight scene callbacks later reports endpoint pose/node error `0.00000000` |
| Pause and replay | Original scene playback pauses at 0.631500 seconds and holds the same readout across separate snapshots; Play restarts after a completed clip |
| Extra placement negative | A scratch build adds 0.05 metres to the imported entity's X placement. Authored/repeat/time checks still report zero, but the new node check reports `0.05000000` and **NOT PROVEN**, demonstrating that the extra placement is rejected |
| Wrong asset/profile | A separate build supplies the two-second calibration to the glide profile. Import fails with `unexpectedAnimationBinding`, all route/transport controls stay disabled, and no clip/profile fallback occurs |
| Packaging/builds | Packaged bytes match the generated candidate's SHA-256. Glide, calibration, and default profiles build under Swift 6 strict concurrency; only the App Intents metadata-extraction warning is reported |

The `3.44845986` phase value is the diagnostic's mixed local-transform difference, not arc distance. Readback after completion verifies a retained inspection pose, not a physically authored deceleration or stop. Scene-update callback counts are not FPS evidence. The negative placement/profile build scaffolding and recordings remain scratch artifacts, not a retained test target; the positive checks and profile are retained in the diagnostic source. Physical iPhone/iPad playback, per-vertex contact readback, coaching review, production topology/weights, and connecting clips remain open. The original external donor's scene-binding failure is unchanged by this result.

## Repeated-glide seam audit

The retained [repeat audit](../tools/SkaterDCCStudy/audit-glide-repeat.py) evaluates two copies of this same sustained glide as a six-second geometric sequence. It first runs the existing candidate validator against the paired native baseline. It then derives one constant Y-axis rotation and translation for the second copy from the exported support-blade headings and contact positions. This is placement of already-baked skeletal travel, not a second animated trajectory, an origin restart, a blend, or an endpoint hold. It does not export a new clip or change the iOS study or main app.

```sh
"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/audit-glide-repeat.py -- \
  --asset "$GLIDE/GlideCandidate.usdz" --source-report "$GLIDE/source-report.json"
```

The audit compares every skinned vertex at the seam and samples both copies at integer and half frames. It checks the continuing circular contact path, outside-edge bank, support height, free-blade clearance, blade heading, and floor penetration. Exit success means only that these sampled positional/contact gates pass. The JSON reports velocity measurements separately; it does **not** certify a smooth transition.

Observed on November 10, 2026, using the exact package and paired report above:

| Criterion | Observed result |
| --- | --- |
| Sampled position/contact repeat | PASS: 290 copy-frame samples, including both sides of the three-second seam |
| Whole-mesh seam gap | Maximum `1.57129e-6` m; no pose blend applied |
| Support-heading seam gap | Unit-vector difference `6.17348e-15` |
| Support-height error | Maximum `5.45675e-7` m |
| Free-blade clearance | Minimum `0.1999995` m |
| Continuing-arc error | Maximum `8.21946e-5` m |
| Heading versus arc tangent | Maximum unit-vector difference `8.63941e-6` |
| Floor penetration | Maximum numerical residual `2.65124e-7` m |
| Smooth velocity at the seam | **NOT MET:** adjacent linear pelvis-key segments differ by `0.0148664` m/s after placement |
| Broken-repeat checks | All six rejected: unplaced restart, extra 0.05 m offset, double placement, body-pose mismatch with unchanged blades, endpoint hold, and mid-clip support lift |

The one-sided skinned-contact velocity estimates at steps of `1/384` and `1/1536` seconds differ across the seam by approximately `0.01495` and `0.01469` m/s. Their small disagreement includes finite-step and float-deformation effects. The separate pelvis-key calculation uses the actual final and initial key intervals, transformed into the same app-space frame: the USD's linear root-translation segments have different slopes. Position continuity is therefore not derivative continuity. These measurements do not establish acceleration continuity or an acceptable production velocity tolerance.

This result is specific to continuing the **same** already-established support state. It establishes no push-off, stop, lift, support transfer, different-move connector, or opposite-side variation. The previous iOS checks cover one clip only; this six-second placement has not been exercised in RealityKit. A smooth-motion candidate needs its authored/exported trajectory and contact behavior assessed together, rather than hiding the kink with a slower blend, denser samples claimed as proof, or an endpoint hold. Coaching review and real entry/exit states remain separate requirements.

An additional input-gate check animates the exported `/SkaterStudy` ancestor by 0.05 metres in X. The validator rejects that extra world-space travel before skinning. A reset-transform boundary correctly excludes ineffective ancestor animation, while the same animation without the reset is rejected. This closes a blind spot where checking only the leaf transforms and reusing a frame-one world matrix could miss animated ancestors.

The standalone validator still reports its original 145-sample results, both USD formats pass `usdchecker --arkit`, and asset/report hashes remain unchanged. The six repeat mutations and additional ancestor/reset harnesses are scratch verification, **not retained tests**; the repeat audit and its source-validator preflight are retained. No skating approval or app integration follows from the audit.
