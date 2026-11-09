# External character rig assessment

Assessed November 8, 2026. **Technical donor only; explicit skeletal playback/seek study exercised on iOS; no production character selected.** The My Ice Show app and its bundled fixture are unchanged.

## Candidate and provenance

The candidate is **Rogue**, from Kay Lousberg's [KayKit Adventurers Character Pack](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0). The publisher repository links the [artist's pack page](https://kaylousberg.itch.io/kaykit-adventurers) and identifies the creator in its license. Inspection uses revision `672074b73ba276876a19e8816ecdc5241817ab47`, not a moving branch.

| File | SHA-256 |
| --- | --- |
| `Characters/gltf/Rogue.glb` | `e825437cd4d2ee9c1960b517a74a69101e33eb409ae7fa8cedc7134a998fbb7d` |
| Repository `LICENSE.txt` | `ae322141814056dda0deea7540d74c41d87aee1da319977cd1bd84ee5a923629` |

Character paths are relative to `addons/kaykit_character_pack_adventures/`. The [license at that revision](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/672074b73ba276876a19e8816ecdc5241817ab47/LICENSE.txt) identifies CC0, permits personal/educational/commercial use, and makes attribution optional. It covers this downloaded pack, not unrelated coaching footage or future purchased assets. No purchase, account login, or artist contact was needed. No downloaded or converted asset is included in this repository or the My Ice Show app. A temporary, separate diagnostic app bundles the corrected asset solely for the simulator study below.

An earlier candidate, [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html), was not downloaded: its pack page showed CC0 while the [site license page](https://quaternius.com/license.html) showed QAL v1.0, dated August 28, 2026, with restrictions on standalone asset redistribution. An asset-specific license would need resolving before adopting that candidate, especially in this public source repository. This is a record of conflicting pages, not a conclusion about all Quaternius assets.

## Inspected source, not marketplace claims

The GLB identifies its exporter as `Khronos glTF Blender I/O v1.7.33`. That establishes the file's recorded export provenance; Blender was not installed or run during this assessment, and editable Blender source was not obtained.

- One skin with **41 joints**, including a root, hips, spine/chest, arms/hands, legs/feet/toes, and IK/control branches. The scene's separate `Rig` grouping node has no transform attributes.
- Six skinned mesh nodes: separate left/right arms, body, head, and left/right legs. Together they contain **3,511 exported vertices and 4,263 triangles**, excluding unskinned accessories. These are exported vertex counts, not welded authoring counts.
- All inspected skin weights are finite and nonnegative; all joint indices lie within the skin palette. The largest weight-sum error is approximately **0.0000000447**. Twenty joints receive nonzero mesh weights. This does not prove good deformation or correct inverse binds.
- A single material, `rogue_texture`, with an embedded PNG atlas. There is no independently named `Costume` material. The head is weighted to its head bone; facial-expression authoring was not demonstrated.
- Six additional unskinned mesh nodes include a cape, knives, crossbows, and a throwable accessory. This is an adventurer outfit, not a skating costume. A rendered idle frame shows boots without skating blades and hands posed for equipment.
- **76 animation entries** are present in the actual file; the publisher README advertises 75. No supplied animation is treated as an approved skating move. Names are not evidence of skating mechanics.
- Decoded `Idle` and `Walking_A` timelines span approximately 1.066667 seconds; `Jump_Full_Short` spans approximately 1.166667 seconds. For these three clips, decoded `root` translation stays zero. That is not a guarantee that the hips or visible body stay stationary, or that every clip is in-place.

The retained [GLB inspector](../tools/inspect-character-glb.py) decodes the embedded accessors rather than trusting their declared min/max bounds. It is deliberately limited to uncompressed, nonsparse, nonnormalized accessors in a single-buffer GLB; it is not a complete glTF validator. Its optional study output keeps one named animation but retains the original binary buffer, including now-unreferenced animation data. It does not optimize the asset, retarget joints, remove equipment, or rewrite the source file.

## Actual conversion and runtime findings

Tools: the installed Apple USD tools report Apple USD Tools `0.25.2`, USD-Fileformat-Plugins `1.0.8`, and USD `2511`; the probe uses Swift 6.4 and macOS RealityKit from Xcode 27.

1. Converting the full GLB with `usdcat` selects `1H_Melee_Attack_Chop` as its default animation. It does **not** establish that the entire clip library survives conversion. The study therefore selects only `Idle` before converting.
2. Direct `usdzip --arkitAsset Rogue.glb …` fails to determine the root layer's format in this toolchain. Converting with `usdcat` first produces a USD layer, but its texture still references an embedded member of the original GLB. Packaging that layer without externalizing the PNG produces an unsupported `.glb` dependency and fails `usdchecker --arkit`.
3. `usdextract` extracts the PNG, but the extracted USD layer also retained the embedded-GLB texture reference in this run. Explicitly repointing the material's texture asset to the extracted PNG yields a self-contained package that **passes `usdchecker --arkit`**.
4. That package still exposes **zero skin joints** through macOS RealityKit: its skinned mesh holder has neither `jointNames` nor mesh-content skeletons. The probe exits nonzero with `noSkin`. A successful USD checker result is not a sufficient runtime acceptance gate.
5. The converted skeleton and animation joint-path arrays include a common `n53/` ancestor prefix, but `n53` itself is not a joint in the palette. In a separate study layer, removing just that prefix from both arrays, without changing geometry, weights, bind/rest matrices, or animation samples, restores **one merged skinned ModelEntity with 41 joints and one 41-joint mesh skeleton**. The resulting USDZ also passes the checker. This isolated experiment identifies the joint-path representation as the runtime compatibility problem for this candidate and toolchain; it is not a general-purpose converter repair.
6. The corrected package exposes two root animation resources, named `global scene animation` and `default subtree animation`, both approximately 1.066667 seconds. Those are two resources from the **one selected Idle clip**, not two successfully imported source clips. Resource presence/duration is not proof of playback or deterministic seeking.
7. Calling the actual app's `ImportedSkater` initializer with that loaded candidate rejects it as `incompatibleSkeleton`. Running the same retained probe on `SkaterFixture.usdz` loads its 15 joints and reports `Fixture adapter: accepted`.

A frame was also rendered with `usdrecord --frames 0` from the corrected USDZ. Its texture and posed body are visible, but the default framing cuts off the head and includes equipment. This is USD renderer evidence, not an iOS screenshot, complete deformation review, or RealityKit animation playback test. Whole-entity bounds include accessories and must not be used as the skater's neutral height.

## Reproduce outside the app

Run from the repository root. The output directory must be fresh: the GLB inspector refuses to overwrite an existing study output or its source.

```sh
study=$(mktemp -d /tmp/myiceshow-rig.XXXXXX)
revision=672074b73ba276876a19e8816ecdc5241817ab47
base="https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/$revision"
curl -fL "$base/LICENSE.txt" -o "$study/LICENSE.txt"
curl -fL "$base/addons/kaykit_character_pack_adventures/Characters/gltf/Rogue.glb" \
  -o "$study/Rogue.glb"
shasum -a 256 "$study/LICENSE.txt" "$study/Rogue.glb"

python3 tools/inspect-character-glb.py "$study/Rogue.glb" \
  --animation Idle --output "$study/Rogue-Idle.glb" > "$study/report.json"
usdcat "$study/Rogue-Idle.glb" -o "$study/Rogue-Idle.usda"
usdextract "$study/Rogue-Idle.glb" -o "$study/textures"
```

The following **candidate-specific data transformation** creates two separate layers: the texture-only baseline and the joint-path experiment. Stop on a failed assertion rather than generalizing the workaround to another asset/exporter. The source file and its embedded binary buffer remain untouched.

```sh
python3 - "$study" <<'PY'
import hashlib
from pathlib import Path
import sys

study = Path(sys.argv[1])
assert hashlib.sha256((study / "Rogue.glb").read_bytes()).hexdigest() == \
    "e825437cd4d2ee9c1960b517a74a69101e33eb409ae7fa8cedc7134a998fbb7d"
text = (study / "Rogue-Idle.usda").read_text()
reference = f"@{study}/Rogue-Idle.glb[rogue_texture.png]@"
assert text.count(reference) == 1
baseline = text.replace(reference, "@textures/rogue_texture.png@")
(study / "texture-only.usda").write_text(baseline)
assert baseline.count("uniform token[] joints = ") == 2
assert baseline.count('"n53/') == 82
(study / "joint-path-study.usda").write_text(baseline.replace('"n53/', '"'))
PY

usdzip --arkitAsset "$study/texture-only.usda" "$study/texture-only.usdz"
usdzip --arkitAsset "$study/joint-path-study.usda" "$study/joint-path-study.usdz"
usdchecker --arkit "$study/texture-only.usdz"
usdchecker --arkit "$study/joint-path-study.usdz"

xcrun swiftc -parse-as-library tools/probe-character-import.swift \
  MyIceShow/Rendering/ImportedSkater.swift MyIceShow/Motion/SkaterSkeleton.swift \
  MyIceShow/Motion/SkaterRig.swift MyIceShow/Motion/SkatingMotion.swift \
  -o "$study/probe"
"$study/probe" "$study/texture-only.usdz"
"$study/probe" "$study/joint-path-study.usdz"
"$study/probe" MyIceShow/Assets/SkaterFixture.usdz
```

The texture-only probe is expected to exit 1 with `noSkin`; the joint-path study reports 41 joints and adapter rejection; the fixture reports 15 joints and adapter acceptance. The [retained import probe](../tools/probe-character-import.swift) reports actual model/skeleton data, animation resources, and the app adapter's decision. Its zero exit status means it found legacy-accessible skin joints with matching transform counts, **not** that the asset meets the app's rig contract or that animation played. Read the adapter verdict separately.

## iOS simulator playback and seeking

The retained [isolated playback study](../tools/CharacterPlaybackStudy/README.md) built with Swift 6 strict concurrency and was installed/launched on an **iPhone 16 Pro simulator running iOS 18.6**. It uses a separate bundle identifier, `dev.myiceshow.characterstudy`; no main-app source, target, saved-show schema, or bundled resource changed. The final build succeeded with the existing-style App Intents metadata-extraction warning.

The simulator reproduced a second runtime distinction beyond skeleton loading:

| Criterion | Observed result |
| --- | --- |
| Corrected external package loads | PASS: one skinned model with 41 joint names/transforms |
| Original imported scene-timeline route deforms skin | FAIL: playback clock advances, but measured skin-joint change is zero and the skin remains in its rest pose |
| Explicit imported skeletal-track route deforms skin | PASS: bind the sole imported `SampledAnimation<JointTransforms>` leaf directly to the loaded model's `.jointTransforms`; rendered arms lower from the rest pose, and playback shows nonzero joint change |
| Out-of-order seeking through the direct route | PASS: nine captures at `0, .25, .75, .25, .5, 1, 0, .5, 1` of the clip, including exact endpoints; maximum phase change `0.01105832`, repeated-pose error reported `0.00000000`, maximum time error approximately `0.00000006` seconds |
| Seeking check detects the scene-route failure | PASS: the same nine captures report `NOT PROVEN`, with phase change `0.00000000`, rather than accepting unchanged rest poses as deterministic animation |
| Playback through the direct route | PASS: reaches and holds the 1.066667-second endpoint under the study's explicit pause/clamp; the final recorded run observed 66 scene-update callbacks and maximum joint change `0.01381135` |
| Package without joint-path correction | PASS as a negative check: rebuild with the texture-only baseline; UI reports `Import failed: unexpectedSkeleton` and disables controls, without fallback |

The direct track is extracted from the imported animation definition; it is not a new procedural animation or a new GLB/USD conversion. Exact imported joint-name order is checked before binding. The study uses one native animation controller at a time, pauses/seeks that controller directly, and waits eight scene-update callbacks before pose readback. It does not accumulate another animation clock. A first experiment regenerating the entire imported group with fill enabled also failed to deform the skin; that is not the passing route.

Pose-error values combine local translation, scale, and sign-invariant quaternion-vector differences; they are not world-space blade-contact or angular-accuracy measurements. An external screen recording was inspected as ordered frames alongside numeric readback. The idle motion is small, and this is not a lunge, jump, transition, or full deformation review. Observed callback counts are not physical-device performance evidence.

**The complete imported scene is still not accepted.** Direct skeletal binding does not run the separate scene-node animation used by equipment/cape attachments. The default scene-route resolution failure has not been repaired or attributed to a specific framework bug. The two explicit route buttons preserve that distinction rather than hiding it behind fallback logic.

## Assessment and next gate

**Keep Rogue as a reproducible compatibility donor, not a production skater or an app-bundled placeholder.** Its license and actual rig are inspectable, and it exposed two concrete conversion hazards before any retargeting work entered the app.

The existing fixture adapter intentionally accepts one exact 15-joint rig and a separate costume material. Although RealityKit merges this candidate's six skinned meshes into one ModelEntity in the probe, its 41-joint hierarchy, local rest axes/proportions, atlas material, equipment, and foot geometry do not match the lab. Renaming bones or assigning the lab's translations would not be a valid retargeting solution. No adapter relaxation or silent fallback was added.

The narrow **iOS explicit-skeletal-track playback/seek gate** has observed evidence. The subsequent [Blender-native skater study](skater-dcc-study.md) exercises a plain body/outfit, curved blade geometry, explicit bind calibration, and a new DCC export; both of its iOS animation routes pass repeated seeking. That result does not repair this donor's full-scene failure or justify a generic retargeter around it. Physical-device profiling and skating-clip correctness remain open. The [five-move review brief](move-validation-brief.md) and coach approval are independent requirements; generic Idle/Walking/Jump clips do not satisfy them.
