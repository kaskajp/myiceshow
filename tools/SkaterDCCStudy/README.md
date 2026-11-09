# Blender-native skater export study

This creates an editable `.blend`, a skinned USD stage, and a source-calibration report outside the repository. It is a **technical calibration study**, not final character art or a skating clip. The [assessment](../../docs/skater-dcc-study.md) records observed results and limitations.

Requirements: **Blender 4.5 LTS** with its bundled `bpy`/`pxr` Python modules, plus Apple's `usdzip` and `usdchecker`. No package is added to My Ice Show. The observed build used Blender **4.5.14 LTS**, build `62c1db4208e8`, on Apple Silicon. The official [release directory](https://download.blender.org/release/Blender4.5/) includes the installer and checksums; the macOS ARM64 DMG's SHA-256 was `65134d9b07b20e2fa8d3c9e44f6f44ffb5c9774dd521b95f50387310241ca170`. This session used the signed application on a temporary, read-only mounted DMG; it did not install Blender in Applications.

## Generate, export, and check

Run from the repository root. Set `BLENDER` to the executable inside a trusted Blender 4.5 application. Choose an output directory that **does not yet exist**; generation refuses to overwrite it.

```sh
export BLENDER=/path/to/Blender.app/Contents/MacOS/Blender
export STUDY="$(mktemp -d /tmp/myiceshow-dcc.XXXXXX)/output"
export PYTHONDONTWRITEBYTECODE=1

"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/build.py -- --output "$STUDY"

usdchecker --arkit "$STUDY/SkaterStudy.usdc"
usdzip --arkitAsset "$STUDY/SkaterStudy.usdc" "$STUDY/SkaterStudy.usdz"
usdchecker --arkit "$STUDY/SkaterStudy.usdz"

"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/validate.py -- \
  --asset "$STUDY/SkaterStudy.usdz" \
  --source-report "$STUDY/source-report.json"
```

`build.py` constructs native Blender mesh data, vertex groups, an Armature modifier, bones, and a keyed action. It reuses the existing fixture's project-authored body construction functions—not an imported USD mesh—and replaces the blade ellipsoids with extruded curved runners and mounts. All body/equipment geometry is in one skinned object. The source saves at the neutral first frame before exporting a two-second, 24-fps calibration clip.

`validate.py` uses Blender's bundled OpenUSD modules to compare the exported asset against the native samples. It checks world-space bind landmarks, the complete bind matrices against Blender bone axes, rest/bind agreement, hierarchy, vertex influences, unanimated mesh points, topology preservation, material-associated blade geometry, floor/toe/heel landmarks, and skinned vertices at frames 1, 13, 25, 37, and 49. These checks are deliberately specific to this study. They are not a generic asset validator, coaching approval, or an all-frame collision/contact analysis.

The source report contains bind matrices and native evaluated vertex samples, not just expected counts. Keep it with the corresponding `.blend` and export. It is a comparison baseline, not a signature or a trustworthy baseline for an unrelated/modified asset.

## Re-export the saved DCC source

This opens the saved source and invokes the same retained export function without rebuilding its geometry. Use a fresh export filename. Validation against the original report is appropriate only while the source remains unchanged; intentional edits require a newly inspected calibration baseline.

```sh
"$BLENDER" --background "$STUDY/SkaterStudy.blend" --python-exit-code 1 \
  --python-expr 'import os, runpy; from pathlib import Path; authoring = runpy.run_path("tools/SkaterDCCStudy/build.py"); authoring["export_scene"](Path(os.environ["STUDY"]) / "Reopened.usdc")'

"$BLENDER" --background --factory-startup --python-exit-code 1 \
  --python tools/SkaterDCCStudy/validate.py -- \
  --asset "$STUDY/Reopened.usdc" --source-report "$STUDY/source-report.json"
```

## Exercise the iOS export

Use the [isolated playback app](../CharacterPlaybackStudy/README.md), with this generated package and the explicit `SKATER_DCC_STUDY` compilation condition. The default profile remains the 41-joint Rogue assessment; this profile expects 15 joints. Neither profile changes the main app's target or resources.

```sh
playback=$(mktemp -d /tmp/myiceshow-dcc-playback.XXXXXX)
cp tools/CharacterPlaybackStudy/{StudyApp.swift,project.yml} "$playback/"
cp "$STUDY/SkaterStudy.usdz" "$playback/StudyAsset.usdz"
xcodegen generate --spec "$playback/project.yml"
xcodebuild -project "$playback/CharacterPlaybackStudy.xcodeproj" \
  -scheme CharacterPlaybackStudy -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$playback/build" CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SKATER_DCC_STUDY' build
```

Install the diagnostic app and exercise **both** routes explicitly: Check seeking, exact endpoints, Play/Pause, and replay. No route silently falls back to the other. Use the device tools and their returned `agent-device` when running under T3. The saved-show app's data is separate. Generated `.blend` files, reports, projects, and recordings remain external to the repository. A checked USDZ snapshot is now bundled as `MyIceShow/Assets/SkaterCalibration.usdz` for the separate [in-app native preview](../../docs/native-clip-preview.md); regeneration does not replace that snapshot automatically.
