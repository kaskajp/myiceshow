# Animation reference register

Checked November 8, 2026, after publishing baseline `ce80024`.

**Status: references located; video execution, exact variation, and coaching approval are pending.** Fetching a video title is not watching it. None of these records grants permission to copy footage, trace poses, extract motion, or redistribute an animation derived from it.

## Provenance

The official [Skate Canada STAR 1–5 Guide](https://info.skatecanada.ca/index.php/en-ca/guides/393-canskate-guide-explore-3.html) links directly to the [STAR 1–5 Tutorials playlist](https://www.youtube.com/playlist?list=PLvE0VdQZtzvcvkk9l_qjmINbmIb76qcO6) on **Skating Development Video Library**. The guide and playlist were fetched successfully; public playlist metadata returned the titles, identifiers, and durations below. No video media was downloaded.

Metadata was checked with `yt-dlp --flat-playlist --playlist-end 35 --skip-download --dump-single-json` against that public playlist. This is research tooling, not an app dependency.

The guide separately links assessment-standard libraries. Those can contain performances at different assessment standards; they must not be treated as uniformly correct executions. The list below comes from the tutorial playlist, but still requires a coach to choose the precise example and segment.

## Located references

Catalog IDs refer to the [move catalog](skating-move-catalog.md). A reference can be useful preparation without demonstrating every named element or variation in a row.

| ID | Publisher's video title | Duration | Catalog connection | Reference |
| --- | --- | --- | --- | --- |
| D01 | Forward Edges | 1:35 | B06/T01: forward edge and one-foot-balance research | [Video](https://www.youtube.com/watch?v=vA_j9hz-yjY) |
| D02 | Backward Edges | 1:00 | B06/T01: backward counterparts | [Video](https://www.youtube.com/watch?v=Aq-GQxc87uo) |
| D03 | FWD & BWD 3 Turns | 1:07 | T03: three-turn family; foot/edge variants need review | [Video](https://www.youtube.com/watch?v=EkcsBqBceYM) |
| D04 | Spin Development | 1:48 | S02: development reference, not an approved upright-spin clip | [Video](https://www.youtube.com/watch?v=bLgRROD6L8M) |
| D05 | Back Spin | 1:25 | S03: backward spin research | [Video](https://www.youtube.com/watch?v=OOHw28OIXW0) |
| D06 | Jump Take off Progressions STAR 1 | 1:22 | J04/J05: takeoff-development research; not proof of a specific waltz-jump demonstration | [Video](https://www.youtube.com/watch?v=QEN_SQtSD0U) |
| D07 | Landings | 0:38 | J04–J10: landing preparation; exact jump/foot combinations remain unverified | [Video](https://www.youtube.com/watch?v=0bV1CeitcDE) |
| D08 | Spiral Circles | 1:09 | F01: spiral-family research | [Video](https://www.youtube.com/watch?v=nE6zPuux-EM) |
| D09 | FO Change of Edge | 0:38 | T01/T02: forward-outside change-of-edge research | [Video](https://www.youtube.com/watch?v=lvhZgqRubaU) |
| D10 | Brackets | 1:20 | T06: bracket-family research | [Video](https://www.youtube.com/watch?v=3PnK9NjH8E4) |
| D11 | Loop Flip and Lutz Progressions | 1:42 | J07–J09: progression research, not blanket approval of three completed jumps | [Video](https://www.youtube.com/watch?v=OmFj3N4Y-4s) |
| D12 | Creative Movement Class | 19:43 | F07: expressive connections, not a canonical single skating element | [Video](https://www.youtube.com/watch?v=m3fY--DfrYI) |

Durations come from public playlist metadata, not measured frame ranges. Start/end timestamps will be recorded only after the actual example is reviewed; none are invented here.

## Five-move validation-set gaps

| Study move | Located material | Still required before production animation |
| --- | --- | --- |
| Glide | D01/D02 | Specify one/two feet, direction, edge, support foot, and exact example |
| Three-turn | D03 | Choose a precise foot/edge variant and review entry/exit mechanics |
| Upright spin | D04 | A reviewed completed spin, pivot/support geometry, entry, and exit |
| Waltz jump | D06/D07 | A dedicated reviewed half-revolution waltz jump, not merely a takeoff drill |
| Lunge | No dedicated tutorial located in this pass | Primary definition and reviewed full execution, including trailing-blade contact |

The lunge and two-foot-hop definition gaps in the catalog remain open. This pass does not claim a complete move catalog or a launch collection. The five moves remain a technical validation set only.

## Other primary-source checks

- [British Ice Skating Skills](https://www.iceskating.org.uk/skills) links separate level-specific video playlists, including [Skills 1](https://www.youtube.com/playlist?list=PLASZTijgWVdt34Kp2zuzDiYOoXVg2LEQF). Those links were located; their individual clips have not been reviewed here.
- Learn to Skate USA's public sitemap identifies the current [Basic Skills](https://learntoskateusa.com/basic_skills) and [Free Skate](https://learntoskateusa.com/free_skate) overview pages. Both returned HTTP 200. The old `/freeskate` address returned HTTP 404. These overviews establish program scope, not individual animation mechanics.

## Review record required for each approved variation

Record the chosen video segment, precise technical variation, named skating reviewer, date, required pose/contact corrections, and intended animation duration. Keep reference permissions separate from technical approval. An animator then measures support contacts, blade path, root motion, and garment behavior against the reviewed example.

The current procedural animation improvements are authored mathematical studies. They do not retarget or reproduce these videos. See [the animation lab](animation-prototype.md) for what has actually been implemented and measured.
