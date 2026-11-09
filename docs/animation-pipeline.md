# Animation pipeline — validation plan

Status: **fixture import, external-rig skeletal playback, and a Blender-native skater calibration export exercised; production character and reviewed skating clips not selected**.

## Implemented foundation

The animation lab uses a fixed-length pose model with thigh, shin, upper-arm, forearm, and torso lengths. A two-bone inverse-kinematics calculation finds knees and elbows from authored foot/hand targets. The Articulated appearance positions and rotates fixed-size primitive geometry rather than changing its length each frame. The Imported skin appearance drives a project-authored USDZ fixture from those same poses. See the [skinned fixture](skater-fixture.md) for its source, coordinate contract, import checks, and limitations; it is not the production character.

Pose targets are authored only for the existing five study moves. Targets outside the rig's reach are authoring errors, not silently clamped or converted into stretched limbs. The geometric checks exercise the full pose envelope before these targets are used in the app. Fixed lengths alone do not establish human anatomy, correct skating, balance, or freedom from self-intersections.

Travel progress uses cubic Hermite interpolation. Adjacent traveling moves share the smaller of their nominal travel speeds at their boundary, so the skater no longer stops at every card. Entry/exit speeds are zero at the routine endpoints and beside a stationary spin. This preserves forward progress without overshooting the authored travel distance. Direction changes and spin rotation retain their separate authored timing; this is not a full skating transition library.

Jump flight still occupies a fixed 0.6-second interval, independent of the card's editable duration. Root position, jump elevation, pose sampling, and audio-clock playback remain separate. The rink surface is at height zero, and the local blade geometry is aligned to that surface for grounded targets. A directional shadow is configured to aid visual contact inspection, not to prove that the blade path is physically correct.

## Stationary spin contact study

The upright-spin study now anchors the center of the supporting left blade to its world-space position at clip entry. The rig computes a horizontal body-placement correction from that contact and the current pose/heading, rather than keeping the body's origin stationary while the foot orbits it. The nominal choreography path remains unchanged; only the rendered spin placement receives the correction. Traveling moves and jump elevation are unaffected.

The contact is derived from the authored neutral ankle and blade geometry, not a remembered position from a previous frame. Seeking directly into a spin, sampling backwards, and replaying therefore use the same placement calculation. The sampler carries the clip-entry heading, including preceding turns; it evaluates the final frame through the same clip-sampling path instead of falling back to a separate terminal pose. The full-revolution spin returns to its nominal placement at its boundaries.

This is a fixed blade-center pivot, not a physically correct skating spin: blade rocker, toe/heel pressure, edge tilt, entry/exit transfer, balance, and free-foot collisions still need reviewed animation. Anchoring this one study move does not establish contact-aware blending for the other moves.

## Next asset assessment

Evaluate **one** legally usable rigged skater and the same five movement families before choosing a full launch collection. Do not purchase or publish an asset on the strength of a marketplace thumbnail.

The acceptance package needs:

- Character mesh, skeleton hierarchy, bind/rest pose, skin weights, and a plain outfit suitable for testing deformation.
- Written rights covering the intended app distribution and any animation source, retargeting, and modification; a viewable coaching video is not that license.
- Exact movement variants and coach-reviewed demonstration segments from the [reference register](animation-reference-register.md), with corrections attached to the corresponding clip.
- Root-motion convention, support-foot contacts, toe/blade orientation, takeoff/landing landmarks, entry/exit facing, and which sections may change duration.
- Export settings and an actual imported sample that plays on the target iOS runtime. A candidate USD/USDZ workflow is worth testing, not yet a committed production pipeline.

The [five-move review brief](move-validation-brief.md) specifies proposed review variants, the current lab's contact/edge limitations, and the evidence and acceptance checks needed for that package. Written terminology and [sampled completed demonstrations](demonstration-review.md) have been inspected; precise variant confirmation and coaching sign-off remain pending.

The [external character assessment](character-rig-assessment.md) records a pinned CC0 KayKit rig, decoded skin/clip data, native conversion failures, and a candidate-specific joint-path correction that exposes 41 joints. An isolated iOS simulator study demonstrates playback and repeated seeking when the imported skeletal leaf is explicitly bound to the model. Its original scene-timeline route does not deform the skin and remains a failing comparison. The app's fixture adapter rejects that different rig as intended. The donor has not entered My Ice Show and is not a production skater.

The subsequent [Blender-native skater study](skater-dcc-study.md) saves editable DCC source with curved blade geometry, exports a two-second calibration clip, and compares the exported bind/rest data and skin deformation to native Blender samples. Both the original scene route and direct skeletal route pass repeated seeking on the iOS simulator for this simple scene, without USD repair. This is a controlled technical export, not production art or approved skating. The app adapter now checks stored rest transforms, inverse bind matrices, and parent relationships as well as names/counts. It explicitly rejects this rig's different bone-local frames; passing native playback does not make it compatible with the fixture sampler. See the [retained importer checks](skater-fixture.md#repeatable-importer-checks).

The main app exposes a separate [native clip preview](native-clip-preview.md) using a bundled snapshot of that project-authored calibration. It binds the imported skeletal leaf to its own model without replacing samples or retargeting. Single clip mode uses native playback; Show timeline mode keeps that controller paused and seeks it from the existing Studio clock. A shared slot resolver supplies absolute local times to both the native diagnostic mapping and procedural sampler. Calibration restarts at 1× per slot, then holds its endpoint; closing restores the entry playhead. The saved-show schema is unchanged. This establishes a timeline-control seam, not production clip selection, skating correctness, transitions, root-motion composition, or music synchronization.

The installed Xcode 27 SDK exposes RealityKit joint-name, joint-transform, and animation-resource APIs. The project-authored fixture has been generated, imported, and pose-driven on the iOS simulator. The external candidate's direct skeletal route has now been exercised in a separate simulator app. Neither proves that an arbitrary exported rig, clip, blend layer, or outfit imports correctly. No external character or authored skating clip has been integrated into My Ice Show, and no production DCC/exporter workflow has been verified.

## Coordinate and integration checks

The current code uses Y-up, local +Z-forward, and a ground plane at zero, with approximate human-sized scene units. Treat these as the lab's conventions and document conversion from the chosen asset rather than assuming its axes, unit scale, or handedness match.

With the actual candidate asset, check:

1. Neutral height, blade-plane alignment, skeleton axes, joint order, inverse bind transforms, and scale survive import without runtime guesses.
2. Supported feet remain on the intended blade path through glides, turns, and spins; a visually stationary root alone is insufficient.
3. The waltz jump has a reviewed forward takeoff and half-revolution flight, without changing flight timing when its approach is lengthened.
4. Every ordered pair in the validation set is assessed for pose, contact, heading, speed, and transition quality—not just individual clip playback.
5. Seeking and replay sample the same pose at the same audio time. Imported animation playback must not introduce a second independently accumulating clock.
6. Outfit geometry does not clip, stretch, or collapse at the deepest lunge, spin position, or landing.
7. Camera readability, frame times, memory, and energy are measured on an agreed physical iPhone and iPad. Simulator playback is not that evidence.

Only then estimate asset production per variation, expand the collection across travel, turns, field moves, spins, jumps, and expressive connections, and choose the launch size. The five-move validation set is not a release cap.

## Evidence from this pass

- The native iOS simulator build succeeded with the new rig and travel sampler.
- An ad-hoc Swift harness sampled **5,005** move/envelope poses: all leg and arm segment lengths and the torso length stayed within 0.00001 scene units of their configured lengths; knee and skate targets stayed above the ground constraints checked by the harness.
- **225** ordered move/duration combinations retained boundary position/heading continuity and matched finite-difference travel velocities within 0.01 scene units/second. Traveling-to-traveling pairs retained nonzero speed.
- All limb joints, pelvis, shoulders, and head stayed continuous across those 225 boundaries. Another 501 trajectory samples per combination showed no reversed travel or overshoot.
- Jump takeoff, apex, and landing timing stayed fixed at card durations of 2.5, 3, 5, and 8 seconds.
- The final build installed and launched on the iPhone 16 Pro / iOS 18.6 simulator. Its example played to the 18-second endpoint and returned to Play. Scrubbing to approximately 16 seconds displayed the articulated lunge with its directional shadow.

These are geometric and timing results, not coaching approval or production asset validation. Expert review of the [inspected demonstrations](demonstration-review.md), a production skinned character with documented rights, physically correct blade contacts, self-collision assessment, real imported clip blending, and physical-device profiling remain open. The later [skinned fixture study](skater-fixture.md) closes only the project-authored mesh import and sampled-joint integration gate.

### Spin contact follow-up

An ad-hoc Swift harness measured the original four-second spin's supporting-blade-center drift at approximately 0.21665 scene units. With the placement correction, **96,048 contact samples** across 48 routines kept the blade center within **0.00001 scene units** of its entry anchor; the largest measured drift was approximately 0.00000034. The routines cover spins lasting 3, 4, and 8 seconds, alone and after every study move at minimum, default, and maximum duration.

The same harness checked all **225 ordered move/duration boundaries in rendered world space**, including the placement correction. At a 0.001-second sampling interval, the largest incoming/outgoing root-velocity difference was approximately 0.00299 scene units/second; the largest world-joint displacement across the two-sided interval was approximately 0.00340 scene units. Checks also passed for 7,515 fixed-length poses, out-of-order seeking, exact spin endpoints, a 60-second repeated-spin routine, empty/clamped sampling, unchanged non-spin placement, and the fixed jump interval at four durations.

The iOS simulator build passed with the existing App Intents metadata warning. The final app was installed and launched on the iPhone 16 Pro / iOS 18.6 simulator; playback reached the routine endpoint, and the upright-spin pose was visually inspected while paused at approximately eight seconds. Deterministic seeking is covered by the harness; the on-screen check does not establish measured foot-contact accuracy. These remain ad-hoc geometric checks, not a configured automated test target or evidence of expert-approved skating.
