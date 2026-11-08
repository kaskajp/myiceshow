# Animation lab

Implemented November 8, 2026. This is a technical experiment, not a release-ready children's app or a final technology decision.

## Run and use

Follow the [README setup](../README.md#run-the-animation-lab). The app opens on Home. Continue in Studio to try the supplied 18-second routine, create an empty show, or reopen a saved show:

- Play, pause, restart, or scrub through the show.
- Select a move card to seek to its beginning and open its editor.
- Adjust duration in half-second increments, move a card earlier/later, or remove it.
- Add glide, three-turn, upright spin, waltz jump, and lunge studies from the library.
- Change the skater's torso color. This is not an outfit system.
- Mute or unmute the synthetic 120 BPM timing pulse. This is not a soundtrack.
- Give the routine a name and tap **Save show**, then reopen it through the **Shows** tab after restarting the app.
- Edit a saved show and use **Save changes** to update it without creating a duplicate.
- Use **New show** for an empty routine. Replacing edited work offers Save and continue, Discard changes, or Cancel; switching tabs alone keeps edits in memory without a prompt.

The routine is limited to 60 seconds. Saving is explicit: saved shows survive app restarts, but unsaved changes do not. The untouched example routine can be replaced without a discard warning; edits to it are protected by the warning. Playback pauses when the app leaves the foreground; interruptions do not automatically resume it. The prototype intentionally uses a light appearance.

## Implementation

| File | Responsibility |
| --- | --- |
| `project.yml` | Reproducible XcodeGen application definition; provisional iOS 18 deployment target |
| `MyIceShow/Navigation/AppTabView.swift` | Home/Studio/Shows navigation and ownership of one shared show library |
| `MyIceShow/Navigation/StudioRequest.swift` | Identifiable requests to create or open a show in Studio |
| `MyIceShow/Home/HomeView.swift` | Welcome screen, Studio entry points, and recent saved-show shortcuts |
| `MyIceShow/Motion/SkatingMotion.swift` | Move vocabulary, durations, absolute-time sampling, root path, and pose envelope |
| `MyIceShow/Playback/ShowPlayer.swift` | AVAudioPlayer clock, play/pause/seek, display refresh, and interruption handling |
| `MyIceShow/Playback/TimingPulse.swift` | Generates an in-memory PCM WAV timing fixture; no downloaded music |
| `MyIceShow/Rendering/RinkView.swift` | Non-AR RealityKit scene, fixed camera, rink, and primitive skater |
| `MyIceShow/Studio/StudioView.swift` | Routine ownership, editing, controls, and presentation |
| `MyIceShow/Studio/StudioTheme.swift` | Prototype colors and costume-color choices |
| `MyIceShow/Shows/ShowDocument.swift` | Serializable show content, stable identities, archive version, and validation |
| `MyIceShow/Shows/ShowLibrary.swift` | Validated local reads, atomic saves, and library ordering |
| `MyIceShow/Shows/ShowLibraryView.swift` | Saved-show selection, empty state, and read-error/retry presentation |

The tab shell owns one shared show library and navigation selection. Home and Shows receive display data and callbacks; neither loads its own library. Studio retains its editing state across tab switches and passes a sampled pose and costume color into the renderer. The renderer does not load shows or fetch services. There are no third-party runtime packages, external assets, network requests, account systems, or camera-permission requests in this prototype.

While playing, elapsed time comes from `AVAudioPlayer.currentTime`, including when muted. A display link requests presentation updates; it does not accumulate elapsed frame durations. Scrubbing samples the same motion function at the requested time. Editing stops and resets playback before the routine changes.

Each move begins and ends in a shared neutral pose. Root displacement and unwrapped heading accumulate across clips, including repeated moves and reordered pairs. A waltz-jump study first aligns its heading to forward travel during the approach, then performs the half-turn during flight. That preparation turn is procedural, not an expert-reviewed entry. Travel follows one circular path and deliberately eases to rest at clip boundaries. Spin travel is stationary; its procedural rotation is not a model of actual blade pivots.

The waltz-jump study uses a fixed **0.6-second** airborne interval with a **0.6-unit** peak elevation. Changing card duration changes approach and exit time, not that interval. These numbers are fixture parameters, not biomechanical measurements or coaching recommendations.

## Navigation

Native SwiftUI tabs provide **Home**, **Studio**, and **Shows**. The iPhone tab bar stays at the bottom while content scrolls; iPad placement follows the system's tab adaptation. There are no placeholder tabs for unfinished features.

Home offers Create a new show, Continue in Studio, and up to three recently modified saved shows. Shows is a full tab rather than a dismissible sheet, and its New show action opens Studio. The existing My shows shortcut inside Studio selects the Shows tab.

Ordinary tab switches do not save, reset, or replace the studio draft. Leaving Studio pauses playback and dismisses its name keyboard. A create/open action selects Studio and sends an identifiable navigation request through the existing unsaved-edit guard. Requests are consumed once, so returning to Studio does not repeatedly create or reopen a show. Selecting the already-open saved show keeps its pending edits.

## Local show storage

The app stores one version-1 JSON archive at `Library/Application Support/MyIceShow/shows.json` inside its sandbox. Each saved show contains a stable UUID, modification date, name, ordered move cards with stable UUIDs and durations, and costume color. The library shows the most recently modified shows first, with names breaking equal-date ties.

Saving trims surrounding name whitespace and requires 1–80 characters, at least one move, supported durations, unique card identifiers, and a total duration of at most 60 seconds. Updates retain the show's identity. File writes use Foundation's atomic-write option; in-memory saved state changes only after the write succeeds.

An absent archive means a new library. An unreadable, invalid, or unsupported-version archive is **not** treated as empty: the app displays the error and blocks saves so it cannot silently overwrite the file. **Try again** retries reading after an external access or file problem is resolved. The prototype does not automatically repair, migrate, or discard damaged data.

The studio owns editing and persistence actions; the saved-show view receives presentation data and callbacks only. A saved show's loaded content is the baseline for unsaved-change detection, including name, order, duration, removal, and color edits. Selecting the already-open show leaves its pending edits intact. Failed saves leave the current editor and pending navigation in place.

There is no autosave, last-opened-show restoration, cloud sync, export, or saved-show deletion UI. App removal can remove local shows; this is not a backup system. **Discard changes** affects only the editor, not previously saved data.

## Verification

Verified environment: Xcode 27.0, Swift 6.4 compiler in Swift 6 language mode, XcodeGen 2.46.0, iPhone 16 Pro simulator, iOS 18.6.

### Build

```sh
xcodegen generate
xcodebuild -project MyIceShow.xcodeproj -scheme MyIceShow \
  -configuration Debug -sdk iphonesimulator \
  -destination 'id=68414E46-9F5E-4552-879D-70CF5A9CB766' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

The final working-tree build succeeded, and that build was installed and relaunched in the simulator. Xcode emitted an App Intents metadata warning because this target does not link AppIntents. Simulator identifiers are machine-specific; use a local destination when reproducing.

### Motion checks

An ad-hoc Swift harness was piped to `swift -` after the motion and timing-audio source files; no permanent test target or test runner is configured yet. Checks passed for:

- All 25 ordered pairs of study moves: root position and heading agree across the boundary within 0.0001, and the pose envelope returns to neutral.
- Forward-facing jump takeoff and fixed flight timing at card durations of 2.5, 3, 5, and 8 seconds after each of the five moves: 20 cases.
- Finite poses on the circular path at 0.01-second intervals through the 18-second example.
- Deterministic repeat sampling, empty routines, negative time, and time beyond the endpoint.
- The generated WAV envelope and expected 62-second audio-data length.

These checks do not establish correct joint mechanics, blade contact, audio-to-display latency, or anatomical accuracy.

### Storage checks

An ad-hoc harness concatenated `SkatingMotion.swift`, `ShowDocument.swift`, and `ShowLibrary.swift` with assertions and ran through `swift -swift-version 6 -`. It exercised temporary on-disk libraries and passed these checks:

- Fresh-library initialization and a disk round trip preserving show/card identities, order, duration, and color.
- Updating an existing show without duplication, preserving a second show, and modification-date sorting.
- Rejection of blank/overlong names, empty routines, invalid/nonfinite durations, duplicate card IDs, routines over 60 seconds, and updates to unknown show IDs; the existing archive remained unchanged.
- Corrupt files and unsupported versions blocked saving without overwriting their bytes; duplicate show identifiers were rejected on load.
- A directory-creation/write failure did not publish an unsaved show into the in-memory library.

This checks the store's decisions, not Foundation's atomic-write implementation. No permanent test target has been added.

### Simulator observations

Bottom-navigation flows exercised on the iPhone 16 Pro / iOS 18.6 simulator:

- Launch selected Home and exposed Home, Studio, and Shows in the native bottom tab bar.
- Renamed a Studio draft to **Tab rehearsal**, switched to Shows and back, and observed the unsaved name and choreography still intact without a discard prompt.
- Opening a different saved show from Shows selected Studio and displayed the unsaved-change prompt; Cancel retained the draft.
- Saving **Tab rehearsal** immediately added it to Home's recent shows and the Shows list without reloading the app.
- Home's Create a new show action selected Studio and opened an empty routine with playback disabled.
- After installing the final build, Home's **Tab rehearsal** shortcut selected Studio and restored that saved routine with its saved status and 18-second duration.
- Selecting **Aurora encore** in Shows opened its saved name, Seafoam color, order, and duration in Studio.
- Started playback, switched to Home, and returned to Studio: it showed Play at approximately seven seconds rather than continuing or restarting playback.

The navigation build passed with the same App Intents metadata warning described above. iPad tab placement and physical-device behavior were not exercised in this navigation check.

- The app installed, launched, and rendered the rink and primitive skater.
- Playback advanced to the upright-spin section and stopped at the 18-second endpoint, returning to the Play control.
- Adding a waltz jump produced a six-move routine; the duration increment changed its card to 3.5 seconds.
- Moving that final card earlier enabled its Move later control.
- Removing the added card returned the routine to five moves and 18 seconds.
- Dragging the timeline scrubber reached the upright-spin section at approximately eight seconds; Play resumed from that position.
- Selecting Seafoam updated the selected costume control and the skater's torso color.
- Initial visual inspection found a rink-surface height offset; the renderer was corrected so the ice surface is at world height zero.

Local-saving flow exercised on the same simulator:

- Changed the example's costume to Seafoam, extended Glide to 4.5 seconds, moved Three-turn ahead of Glide, and saved it as **Aurora rehearsal**.
- Relaunched the app, opened that show through **My shows**, and observed its restored name, Seafoam selection, move order, 4.5-second Glide, and 18.5-second total.
- Renamed it **Aurora encore**, requested New show, and canceled the unsaved-change prompt; the renamed editor remained intact.
- Repeated New show and chose Save and continue; the editor became empty and the library contained one renamed show, not a duplicate.
- Changed the reopened show's color to Sunset, chose New show → Discard changes, and returned to an empty editor. After installing the final build and relaunching again, **Aurora encore** reopened with the saved Seafoam color, original order, and 18.5-second duration; the discarded color did not replace saved data.

The storage changes also passed a regression check of all 25 ordered motion transitions. These are ad-hoc verification results rather than a configured automated test suite.

Local documentation links and whitespace checks also passed, with existing Markdown hard breaks preserved. Simulator execution is not a physical-device benchmark, expert animation review, usability study, or proof of inaudible synchronization error.

## Remaining decisions and limitations

- **Actual skating:** poses are procedural stand-ins. Limbs scale between endpoints rather than maintaining an anatomical skeleton; support-foot geometry, blade pivots, edges, and landings need a real rig and skating-expert review.
- **Transitions:** position and heading continuity are checked, but stopping between moves is not production-quality flow. No arbitrary path planner or transition-animation library exists.
- **Direction:** the lab accumulates turns and jump rotation in one direction. It does not validate mirrored skating or all legal entry/exit combinations.
- **Timing:** fixed airborne timing is demonstrated in the sampler. Real music markers, expressive timing, frame/audio latency, and speed-dependent travel remain unvalidated.
- **Assets:** the skater consists of primitive geometry. There are no imported clips, garment meshes, character customization, or licensed demonstration assets.
- **Performance:** no physical device, minimum-device budget, frame-time capture, battery measurement, or profiling comparison has been completed.
- **Product scope:** named local shows are implemented, but autosave, backup/export, audio import, the five-song soundtrack, video export, parental gates, and production accessibility/child-usability assessment remain outside this prototype.

Next evaluate an expert-reviewed rig and representative animation clips against this same move set. Measure foot sliding, transitions, timing, garment deformation, and on-device rendering before committing to a production pipeline or launch collection.
