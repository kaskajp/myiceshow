# In-app native clip preview

Status: **technical calibration preview, not skating animation or production character art**.

## Use

In Studio, tap **Native clip preview** below the character-study controls. **Single clip** plays the project-authored two-second `Calibration_NotSkating` bend. **Show timeline** samples it from the existing Studio show clock. Play/Pause, Restart, the slider, and Start/Midpoint/End operate on the selected clock. Transport controls may require scrolling on a small screen. Switching modes pauses both paths; entering Single clip resets the native clip to zero.

Opening the sheet pauses the current routine and remembers its playhead. Show timeline temporarily drives that same `ShowPlayer`, including the existing timing-pulse setting, rather than introducing a second show clock. Done restores the entry playhead and leaves the routine paused. Single clip has no audio; neither mode adds music. The preview does not edit the draft, costume selection, clip list, or saved-show data. Calibration cannot be added as a skating move or saved as a show.

### Diagnostic slot mapping

Each routine slot restarts the same calibration at its authored 1× rate and holds its endpoint for the rest of the slot. There is no looping, time stretching, or transition blending. A four-second slot therefore samples native seconds 0–2, then holds native second 2 until the next slot. Exact internal boundaries select the following slot at native zero; the final show endpoint stays in the final slot at its clamped native end. Seeks are absolute and independent of previous playback.

The current slot is labelled **calibration, not this move**. It is not a Glide/Three-turn/Spin/Jump/Lunge animation. Seek-slot buttons exercise boundaries in the current draft order and durations. For an empty routine, Show timeline reports no slots and disables transport instead of inventing a first move. The native-time readout includes the actual controller's paused state, not a second elapsed-time accumulator.

## Playback boundary

- `NativeSkaterClip` requires one skinned model with the study's joint-name schema, one imported scene-animation wrapper, and one finite skeletal track whose ordered joint names match that model. The leaf and wrapper durations must agree.
- Only the track binding and fill mode change: the imported joint samples and timing remain intact. The leaf is explicitly bound to the model's `.jointTransforms` and uses forward/backward fill. Static scene transforms, mesh, materials, and native joint frames remain imported.
- In Single clip mode, `NativeClipPlayer` owns the playing native controller and reads its progress. In Show timeline mode, that controller remains paused and receives absolute seek times as Studio's `ShowPlayer.elapsed` changes; RealityKit never advances an independent clip clock alongside the show. `NativeClipTimeline` maps the selected slot's local time to the clamped native time. `SkatingMotion.position` resolves slots for both native mapping and the existing procedural sampler, with shared boundary semantics but no shared pose transforms.
- Exact-end seeks retain the end pose. Both paths pause on scene inactivity; dismissal pauses/restores the shared show clock and stops/cancels the native preview. An import failure disables both modes and their controls without a substitute clip.
- `NativeClipPreview` is a separate sheet, not an appearance option in the procedural rink. `ImportedSkater` still rejects this asset's incompatible bind/rest frames. No retargeting, procedural pose replacement, fallback animation, or saved-format migration is involved.

This is deliberately specific to a single skinned, single-track calibration asset. It proves a show-time control seam, not arbitrary-character loading, wrapper-timing interpretation, production clip selection, equipment animation, root-motion extraction, transitions, or music synchronization. Repeating calibration per slot is a diagnostic policy, not the final choreography model.

## Asset provenance and regeneration

`MyIceShow/Assets/SkaterCalibration.usdz` is the checked package from the [Blender-native study](skater-dcc-study.md), renamed for the bundle. It contains project-authored geometry and calibration animation; no external character or motion is included. The original `SkaterFixture.usdz` is unchanged. Normal app builds need no Blender or USD tools.

The bundled package SHA-256 is `a2d60704bb1232aac4fddeafc668dd4926cf8931a943edfe186ebf2a27f1fac1`. Follow [generation and validation](../tools/SkaterDCCStudy/README.md) to create an editable `.blend`, export, and native comparison report in a fresh external directory. After inspecting and validating the result, copy its package to `MyIceShow/Assets/SkaterCalibration.usdz`, regenerate the Xcode project, rebuild, and rerun the checks below. Archive timestamps may change the hash even when the internal USD content agrees. The `.blend` and comparison report are generated outputs, not app resources.

## Repeatable loader checks

From the repository root, on macOS 15 or later with Xcode command-line tools:

```sh
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  tools/check-native-skater-clip.swift \
  MyIceShow/Rendering/NativeSkaterClip.swift \
  MyIceShow/Rendering/ImportedSkater.swift \
  MyIceShow/Motion/SkaterSkeleton.swift MyIceShow/Motion/SkaterRig.swift \
  MyIceShow/Motion/SkatingMotion.swift -o /tmp/check-native-skater-clip
/tmp/check-native-skater-clip \
  MyIceShow/Assets/SkaterCalibration.usdz MyIceShow/Assets/SkaterFixture.usdz
usdchecker --arkit MyIceShow/Assets/SkaterCalibration.usdz
```

The diagnostic exits nonzero if authored frames, ordering, or duration change; if the procedural importer accepts the native rig; if the no-clip fixture is accepted as a native clip; or if mismatched ordered joint names/non-finite joint samples are accepted. It does not prove rendered deformation, controller lifecycle, or skating correctness.

The retained pure timeline checks need no USD asset:

```sh
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  tools/check-native-clip-timeline.swift MyIceShow/Playback/NativeClipTimeline.swift \
  MyIceShow/Motion/SkatingMotion.swift -o /tmp/check-native-clip-timeline
/tmp/check-native-clip-timeline
```

They check native 1× sampling/end holds, internal and terminal boundaries, the instant immediately before a boundary, repeated/out-of-order seeks, reordered/retimed slots, and empty/non-finite inputs. A separate scratch digest compared the procedural sampler with commit `a2a74ab` across 6,102 finite times: selected clip and all six floating sample components matched bit-for-bit (`83f6d4252802e662`). That scratch harness is not retained; it does not establish all possible inputs or anatomical correctness.

## Observed simulator verification

### Original single-clip checks — November 8, 2026

On iPhone 16 Pro / iOS 18.6, using the main app and a separate failure build before Show timeline was added:

| Criterion | Evidence |
| --- | --- |
| Native import and visible seeking | Initial neutral pose at 0.000 seconds; settled shoulder/elbow/spine bend at 1.000 seconds; exact endpoint reads 2.000 seconds. A slider drag in the final build pauses/seeks to 0.982 seconds. Inspect settled skin deformation, not only the clock immediately after a seek. |
| Play, pause, completion, replay | Playback reaches `Calibration completed` at 2.000 / 2.000 seconds. Play after completion restarts; a timed play/pause press holds 0.549 seconds across separate snapshots. |
| Dismissal/reopening and draft isolation | Reopening starts at 0.000 seconds. Returning to Studio retains the unsaved Seafoam costume and paused routine at 0:10 / 0:18. The saved `shows.json` SHA-256 remains unchanged across the checks. |
| Explicit import failure | A temporary build with the no-clip fixture substituted for the calibration resource reports the missing scene-animation error, disables all playback/seek controls, and shows no substitute character. Done remains available. The failure build has a separate bundle identifier. |
| Machine gates | Swift 6 strict-concurrency native checks pass; `usdchecker --arkit` succeeds; the iOS simulator build succeeds with only the App Intents metadata-extraction warning. Packaged calibration bytes match the source asset. |

### Absolute show-time checks — November 9, 2026

On the same simulator, using the main app plus separate `dev.myiceshow.showtimeempty` and `dev.myiceshow.showtimefailure` builds from matching source:

| Criterion | Evidence |
| --- | --- |
| Exact slot seeks and end mapping | Entering at show 18.000 seconds selects slot 5 with native time 2.000. Start seeks to show/native 0.000. Seeking slot 2 gives show 4.000 / native 0.000 with the SDK controller reporting paused. |
| Playback across a boundary and pause stability | Playing from slot 2 and pausing yields slot 3, show 8.018 / native 1.018 seconds. Both values remain identical in a later snapshot and screenshot, with the SDK controller reporting paused. |
| Entry-state restoration | After study seeks/playback, Done returns to the main app at 0:18 / 0:18, paused, with the unsaved Seafoam costume retained. The saved `shows.json` SHA-256 is unchanged. |
| Empty routine | A fresh temporary app starts a new empty show. Show timeline reports no routine slots and disables the slider and transport instead of selecting a fake move. Single clip remains a separate mode. |
| Import failure | Replacing only the temporary calibration resource with the no-clip fixture produces the explicit missing-animation error; both mode buttons and transport are disabled, with Done still available. |
| Machine gates | The retained timeline, native-loader, and fixture checks pass under Swift 6 strict concurrency. The simulator build succeeds with the App Intents metadata-extraction warning. The scratch procedural comparison is bit-identical across its 6,102 samples. |

These observations do not establish physical-device performance, per-vertex iOS/Blender equivalence, correct skating, or coach approval. The earlier isolated app still provides the two-route seek diagnostic; this preview intentionally exposes only the direct skeletal route.
