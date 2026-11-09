# Demonstration inspection record

Date: November 8, 2026. Reviewer: coding-agent visual inspection, **not a skating coach**.

Status: **sampled video frames and written guidance inspected; no production clip approved**. This advances beyond title/metadata checks without claiming continuous playback, audio review, anatomical tracking, measured blade edges, or coaching sign-off.

## Sources and reproducibility

Special Olympics' [official figure-skating resource index](https://resources.specialolympics.org/sports-essentials/figure-skating) offers downloads for its badge videos and [2021 Figure Skating Coaching Guide](https://media.specialolympics.org/resources/sports-essentials/coaching-guides/Sports-Essentials-Figure-Skating-Coaching-Guide-2021-v2.pdf). This is a dated coaching progression for its own program, not a universal difficulty scale or current ISU competition rulebook.

| Register ID | Publisher download | Decoded duration | SHA-256 |
| --- | --- | --- | --- |
| D13 | [Badge 9 MPEG](https://media.specialolympics.org/resources/sports-essentials/figure-skating/Figure-Skating-Badge-9.mpeg) | 44.904 seconds | `a8e000485021eeb77e2492dc6e62d21e2ea5ea147bfecacd37f23174409f2c3e` |
| D14 | [Badge 12 MPEG](https://media.specialolympics.org/resources/sports-essentials/figure-skating/Figure-Skating-Badge-12.mpeg) | 70.272 seconds | `3a2b2fbb00557b5ca015facb4004873c7cc4015be46c7eb6d9b411d56c40d3db` |

The guide's SHA-256 is `4d64ad90b42d66dff8f751de367c9d4936ed371673fbc3a20fb6b2b77b524590`. It has 129 PDF pages. Relevant printed pages were rendered and visually checked: 34 (PDF page 41), 45–46 (PDF pages 52–53), and 54 (PDF page 61). Printed and PDF page numbers differ by seven here.

Videos decode as 1920×1080 MPEG-2 at 30000/1001 frames/second. One-frame-per-second overviews located sections; the intervals below were then sampled more densely and inspected as ordered contact sheets. Times are approximate offsets from the beginning of each downloaded file, not frame-accurate biomechanical landmarks. The files have a nonzero MPEG start timestamp; camera cuts, dissolves, and frame selection also limit timing precision.

To reproduce the selected samples after downloading the matching publisher files into a scratch directory:

```sh
ffprobe -v error -show_entries format=duration,start_time \
  -show_entries stream=codec_name,width,height,r_frame_rate -of json badge-9.mpeg
ffmpeg -i badge-9.mpeg -vf 'setpts=PTS-STARTPTS,fps=1,scale=240:135' overview-%03d.png
ffmpeg -ss 16 -i badge-9.mpeg -t 7 -vf 'fps=4' turn-%03d.png
ffmpeg -ss 30 -i badge-9.mpeg -t 6 -vf 'fps=4' lunge-%03d.png
ffmpeg -ss 23.5 -i badge-12.mpeg -t 3.5 -vf 'fps=12' jump-%03d.png
ffmpeg -ss 29 -i badge-12.mpeg -t 9 -vf 'fps=4' spin-%03d.png
```

Inspection copies and derived frames are temporary local research material only. No video, screenshot, audio, extracted motion, or third-party character is bundled or committed. Download availability is not a license to trace, retarget, distribute, or use the footage as app content; production animation rights remain a separate gate.

## Inspected sections

| Evidence | Interval / sample density | Direct observation | Not established |
| --- | --- | --- | --- |
| D13, forward outside three-turn section | Approximately 00:16–00:23, 4 fps | Close-up examples show a direction change while the free foot remains lifted through the turn and exit; the title identifies left/right outside three-turns | Exact edge pressure, turn instant, and mapping each take to the proposed left-foot variant |
| D13, lunge section | Approximately 00:30–00:36, 4 fps | After the preceding section dissolves, the skater lowers into a traveling bent-front-leg/extended-back-leg shape, sustains it, and rises before the next demonstration | Exact leading foot/edge and the trailing boot/blade contact patch; the camera is too distant for those judgments |
| D14, completed waltz-jump example | Approximately 00:23.5–00:27, 12 fps | Approach, an airborne turning pose, landing, and a sustained backward-looking one-foot exit are visible before the dissolve | Exact takeoff/landing frames, flight duration, precise blade edges, and an expert-confirmed left/right assignment |
| D14, one-foot-spin section | Approximately 00:29–00:38, 4 fps | Entry travel, upright rotation with the free leg raised, and travel out of the rotation are visible | Blade-rocker location, pressure, exact revolution count, spin quality, and the complete contact transfer |

These are observed examples, not expert-certified ideal performances. A labeled section and a plausible silhouette do not establish every technical detail.

## Written mechanics checked separately

The 2021 guide supplies information that the wide camera shots cannot prove:

- Printed page 46 describes a trailing **boot-side** contact for the forward lunge, not a flat trailing blade.
- Printed page 54 describes forward-outside takeoff, a half turn, and landing on the former free leg's backward-outside edge for the waltz jump.
- Printed page 34 describes a small two-foot jump and bent-knee landing. This supplies a primary description for the catalog's J01 family; its separate demonstration remains unreviewed.

These close the missing-written-source gaps, not the coaching, exact-variant, reference-rights, or production-animation gates. Do not infer the footage's contacts solely because the accompanying guide describes them.

## Consequences for the animation study

The [five-move brief](move-validation-brief.md) remains the proposed handoff, with these priorities:

1. Have a coach map the selected takes to explicit feet, edges, and rotation direction, and identify acceptable vs corrective examples.
2. For the lunge, evaluate a rig that can rotate the trailing boot separately from its leg target and support a boot-side contact. The current level-ankle fixture cannot demonstrate that requirement.
3. For the jump, author and inspect distinct takeoff and landing support states. Do not infer a valid foot transfer from the lab's vertical root arc or force a measured demonstration into the lab's 0.6-second flight interval.
4. Use the completed turn/spin sequences to assess entry and exit handling, not merely a stationary spin or a yaw change between shared neutral poses.

No procedural pose was silently promoted to an approved animation, and no external asset has been selected or purchased. The next independent gate is coach review of these specific segments; a rights-documented rig/clip evaluation can then use the corrected handoff.
