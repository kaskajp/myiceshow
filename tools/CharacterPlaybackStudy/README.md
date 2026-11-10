# Isolated iOS character playback study

This is a diagnostic app, **not a target or feature of My Ice Show**. Its bundle identifier is `dev.myiceshow.characterstudy`. The source is retained so the [candidate assessment](../../docs/character-rig-assessment.md) can be reproduced; third-party assets and generated projects stay outside this repository. A separate, explicit `SKATER_DCC_STUDY` compilation condition selects the 15-joint [Blender export study](../SkaterDCCStudy/README.md), its title, and calibration labels. The default remains the 41-joint Rogue profile; this is not arbitrary-skeleton support or retargeting.

`SKATER_GLIDE_STUDY` selects the separate 15-joint, three-second [unreviewed glide candidate](../../docs/glide-candidate.md). It adds a fixed wider camera and an ice-plane reference, never extra root placement. Its authored-pose and model-node checks protect the moving skeletal root. This flag does not approve the move or change My Ice Show's resources/saved routines. Use one named profile, not automatic asset detection.

## Build

For the default profile, use the corrected external USDZ produced by the assessment's `joint-path-study.usda` conversion. A known 41-joint candidate is required. Follow the separate Blender study's build commands for its 15-joint package. Requirements match the main lab: Xcode 27, XcodeGen, and an iOS 18-or-later simulator.

From the repository root, set `candidate` to that external file, then run:

```sh
candidate=/path/to/joint-path-study.usdz
playback=$(mktemp -d /tmp/myiceshow-ios-playback.XXXXXX)
cp tools/CharacterPlaybackStudy/StudyApp.swift "$playback/"
cp tools/CharacterPlaybackStudy/project.yml "$playback/"
cp "$candidate" "$playback/StudyAsset.usdz"
xcodegen generate --spec "$playback/project.yml"
xcodebuild -project "$playback/CharacterPlaybackStudy.xcodeproj" \
  -scheme CharacterPlaybackStudy -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$playback/build" CODE_SIGNING_ALLOWED=NO build
```

Install the resulting `build/Build/Products/Debug-iphonesimulator/CharacterPlaybackStudy.app` on a simulator. When operating through T3, open the device with its device tools and use the returned `agent-device` command for installation, launch, and interactions.

### Glide candidate

Generate and validate `GlideCandidate.usdz` using the [glide instructions](../../docs/glide-candidate.md#reproduce). Set `candidate` to that package when preparing the temporary project above, then build with:

```sh
xcodebuild -project "$playback/CharacterPlaybackStudy.xcodeproj" \
  -scheme CharacterPlaybackStudy -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$playback/build" CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SKATER_GLIDE_STUDY' build
```

This profile requires the imported skeletal track's duration to be three seconds and its frame interval/count to span that duration. Giving it the two-second calibration asset fails explicitly before playback; there is no profile switching or replacement clip.

## Exercise both routes

- **Direct skeleton** is the default. It requires exactly one imported `SampledAnimation<JointTransforms>` leaf with joint names matching the loaded model in order, generates a resource with an explicit `.jointTransforms` binding, and plays it on that model. It does not retarget or replace the imported joint samples.
- **Scene timeline** plays the original imported `default subtree animation` resource on the loaded scene. It reproduces the route that advanced its clock without deforming the Rogue skin; the Blender-native study passes through this route. It is not an automatic fallback.
- **Check seeking** pauses the native controller and visits fractions `0, .25, .75, .25, .5, 1, 0, .5, 1`. Each capture waits eight scene-update callbacks before reading model joint transforms. PASS requires changing poses across phases, repeat-pose error below `0.00001`, and controller-time error below `0.00001` seconds. Quaternion sign is treated as equivalent, and non-finite differences fail the check.
- The pose-error metric is the maximum of local translation-vector distance, scale-vector distance, and quaternion-vector distance. It mixes units and is only a reproducibility diagnostic—not a physical-position or angular-accuracy measurement.
- **Play** starts a fresh controller; **Pause** pauses it; the seek buttons exercise exact start, midpoint, and endpoint sampling. The direct track uses forward/backward fill to retain endpoint poses. The study pauses/clamps a still-valid controller at the authored duration. A scene controller may invalidate at natural completion; completed progress then displays the authored endpoint rather than its invalid zero-duration clock. The `Playback completed` label does not assert that a forward-filled native controller becomes `isComplete` on its own or that an invalid controller remains alive.
- Playback records observed scene-update callbacks and maximum joint change. Callback counts are not a frame-time, energy, or physical-device performance benchmark. The only animation timeline is the native playback controller; scene-update counts are used for readback settling, not to accumulate animation time.

For the glide profile, **Check seeking** also compares all runtime joint transforms against the imported authored frame at each of those exact sample times. This includes the pelvis root's translation and rotation. `authored` must be below `0.00001`. `node` is the maximum absolute element difference between the model's imported world transform and its current world transform; it must remain below `0.00001`. Together these reject lost/changed skeletal root motion and an additional scene/entity placement. They do not measure rendered blade positions or per-vertex iOS skinning.

The glide profile reads the endpoint pose and node transform again eight scene callbacks after observed playback completion. It reports **PASS** or **NOT RETAINED** independently of the completed clock label. Retaining the last moving pose is diagnostic inspection, not an authored stop or a safe transition. Neither route silently switches to the other to obtain a passing result.

Replace the temporary resource with the texture-only baseline package and rebuild to exercise the `unexpectedSkeleton` import failure. Controls must stay disabled; no substitute character or animation appears. Restore the corrected resource for further checks.

The direct route drives only the skinned model. Equipment/cape nodes outside that skin do not inherit the separate scene-node animation through this route. This limitation is visible and is another reason not to ship this character or call the complete imported scene compatible.
