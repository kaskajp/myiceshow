# My Ice Show

A creative iOS figure skating app for children aged 3–12. Choose music, arrange skating moves, and watch a customized skater perform an original show.

## Project status

An experimental native iOS animation lab is implemented. The production app, final rendering approach, and launch collection remain undecided.

Read [the product brief](BRIEF.md) for the experience, audience, music approach, and proposed first release.

The [skating move research draft](docs/skating-move-catalog.md) starts the catalog with 59 movement families, proposed difficulty tiers and prerequisites, animation estimates, federation sources, and explicit research gaps. It is not yet comprehensive or coach-validated; demonstration review is still pending.

## Run the animation lab

Verified toolchain: Xcode 27.0, XcodeGen 2.46.0, and an iPhone 16 Pro simulator running iOS 18.6. The prototype provisionally targets iOS 18 or later and uses SwiftUI, RealityKit, and AVFoundation without third-party packages.

```sh
xcodegen generate
open MyIceShow.xcodeproj
```

Choose the `MyIceShow` scheme and an iOS simulator, then run. The Xcode project is generated from `project.yml` and is not checked in. Running on a physical device additionally requires your signing team in Xcode.

The lab includes five procedural study moves, editable move cards, duration controls, playback and scrubbing, costume colors, a synthesized timing pulse, and named local shows. It does not yet include production animations, songs, or audio import. See [prototype behavior and verification](docs/animation-prototype.md).

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

1. Expand variation-level coverage and review correct-execution demonstrations with a skating expert.
2. Use the animation lab to assess a production rig and clips, compare rendering approaches where needed, and measure physical-device performance.
3. Use the findings to choose the launch collection, asset pipeline, and technology stack before implementing the studio.

The five study moves are a technical validation set, not the final collection or a launch-size cap.
