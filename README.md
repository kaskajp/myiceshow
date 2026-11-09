# My Ice Show

A creative iOS figure skating app for children aged 3–12. Choose music, arrange skating moves, and watch a customized skater perform an original show.

## Project status

An experimental native iOS animation lab is implemented. The production app, final rendering approach, and launch collection remain undecided.

Read [the product brief](BRIEF.md) for the experience, audience, music approach, and proposed first release.

The [skating move research draft](docs/skating-move-catalog.md) starts the catalog with 59 movement families, proposed difficulty tiers and prerequisites, animation estimates, federation sources, and explicit research gaps. It is not yet comprehensive or coach-validated. A [demonstration inspection record](docs/demonstration-review.md) now documents sampled turn, lunge, jump, and spin sequences, with exact-variant and expert review still pending.

The [animation reference register](docs/animation-reference-register.md) distinguishes 12 metadata-only tutorial candidates from two official downloads with sampled-frame inspections. The [animation pipeline notes](docs/animation-pipeline.md) distinguish the implemented pose rig, continuous travel, and anchored spin-support study from the production rig, approved animation clips, and device measurements still needed. A [project-authored skinned USDZ fixture](docs/skater-fixture.md) now imports and follows those poses; Studio's Imported skin / Articulated buttons compare both appearances without changing the routine.

An [external character rig assessment](docs/character-rig-assessment.md) records a CC0 candidate, reproducible inspection/import probes, and an isolated iOS playback/seek study. Explicit skeletal binding passes the study; the default imported scene route does not deform the skin. This is not the selected skater, and no external character assets are bundled with My Ice Show.

## Run the animation lab

Verified toolchain: Xcode 27.0, XcodeGen 2.46.0, and an iPhone 16 Pro simulator running iOS 18.6. The prototype provisionally targets iOS 18 or later and uses SwiftUI, RealityKit, and AVFoundation without third-party packages.

```sh
xcodegen generate
open MyIceShow.xcodeproj
```

Choose the `MyIceShow` scheme and an iOS simulator, then run. The Xcode project is generated from `project.yml` and is not checked in. Running on a physical device additionally requires your signing team in Xcode.

The lab includes five procedural study moves, editable move cards, duration controls, playback and scrubbing, costume colors, a synthesized timing pulse, and named local shows. It does not yet include production animations, songs, or audio import. See [prototype behavior and verification](docs/animation-prototype.md).

Studio's **Native clip preview** opens a separate [DCC calibration study](docs/native-clip-preview.md). Play the two-second bend alone, or use **Show timeline** to sample its paused native controller from Studio's existing show clock. It preserves imported joint frames and restores your playhead on closing. Repeating calibration per slot is not skating animation and does not alter saved routines or the current draft.

The app opens on **Home**, with bottom navigation on iPhone:

- **Home:** create a show, continue in Studio, or reopen a recent saved show.
- **Studio:** arrange moves, customize color, play, and save your current routine.
- **Shows:** browse the full saved library and reopen a show for editing or playback.

Switching tabs preserves the current studio draft in memory and pauses playback when leaving Studio. Creating a new show or opening a different saved show still asks before discarding edits.

Name a routine in Studio and tap **Save show**. The **Shows** tab reopens it after an app restart; **Save changes** updates that same show. **New show** starts an empty routine. Saving is explicit, not automatic: unsaved changes are lost if the app terminates. Saved shows live in the app's local storage without accounts or cloud sync, and are lost if the app and its data are removed.

Build from the command line:

```sh
xcodebuild -project MyIceShow.xcodeproj -scheme MyIceShow \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

## Next steps

The [Blender-native skater export study](docs/skater-dcc-study.md) adds editable DCC source, blade geometry, bind calibration, and a two-second diagnostic clip to the technical evidence. Both iOS seek routes pass in the isolated simulator app; its checked package is bundled for the native preview, including absolute-show-time sampling. The app's [procedural bind/rest compatibility gate](docs/skater-fixture.md#repeatable-importer-checks) still rejects its different joint frames. Next are reviewed skating assets and explicit transition/contact handling—not more adaptation of the adventurer donor.

1. Review the proposed variants in the [five-move animation review brief](docs/move-validation-brief.md) against correct-execution demonstrations with a skating expert, then expand variation-level coverage.
2. Use the animation lab to assess a production rig and clips, compare rendering approaches where needed, and measure physical-device performance.
3. Use the findings to choose the launch collection, asset pipeline, and technology stack before implementing the studio.

The five study moves are a technical validation set, not the final collection or a launch-size cap.
