# My Ice Show — Product brief

Working name: **My Ice Show**  
Platform: **iOS**  
Audience: **Children aged 3–12**  
Status: **Research draft and experimental iOS animation lab; production implementation is pending**

## Concept

A creative figure skating app where children choose music, choreograph routines, and watch their own skater perform. It combines imaginative play with musical expression, giving children a performance they can create, save, and refine.

No skating knowledge is required. The experience should appeal to children who enjoy skating, dance, music, fashion, or making things.

## Core experience

1. Choose a skater and outfit.
2. Pick a built-in song or music added by a parent.
3. Arrange illustrated move cards into a routine.
4. Watch the skater perform with music and rink lighting.
5. Edit the show or save it to replay.

## Creative depth

- **Ages 3–5:** Tap picture cards to add moves. Automatic timing and transitions, spoken prompts, and immediate previews support independent play.
- **Ages 6–9:** Reorder moves, choose their durations, and place favorite moves at musical highlights.
- **Ages 10–12:** Expand the timeline to refine timing, repeat sequences, and build sections with different energy and pacing.

These are levels of control within one studio. Children can reveal additional tools when ready; age bands describe design needs rather than mandatory restrictions.

## Figure skating move research

Find and compile a comprehensive list of all documented figure skating moves and their common variations, ranked by technical difficulty. Use recognized coaching progressions, national skating federations, and ISU terminology, with sources recorded for each entry.

Cover:

- Basic skating skills, stops, and crossovers.
- Edges, turns, steps, and step sequences.
- Spirals and other field moves.
- Spins, positions, entries, and combinations.
- Jumps, rotational variations, and combinations.
- Choreographic and connecting movements.
- Partner elements, identified separately where two skaters are required.

Record each move's name, category, description, prerequisites, difficulty tier, common variations, and a reference demonstrating correct execution.

Organize the catalog from beginner through intermediate, advanced, and elite. Difficulty depends on execution and variation: rotations, entries, positions, and combinations can change a move's ranking. Explain rankings where sources differ and identify gaps in coverage. Assess animation complexity separately from skating difficulty.

Use the research to select a substantial, varied launch collection that supports both simple routines and sophisticated choreography. Determine its size after reviewing coverage and animation requirements. There is no six-to-eight-move cap.

## Music

### Built-in collection

Create a curated collection of instrumental tracks with Suno under appropriate commercial-use terms. Prepare timing markers for built-in tracks to help choreography fit the music.

Generate tracks while subscribed to Pro or Premier and obtain permitted downloads through Suno's approved download feature. Keep generation dates, subscription and download records, and the applicable terms. Avoid collaborative Remixes restricted to noncommercial use. Recheck the applicable terms before distributing the soundtrack; commercial permission does not guarantee copyright protection or uniqueness.

Reference: [Suno Terms of Service](https://suno.com/terms-of-service), reviewed during concept development on November 8, 2026.

### Parent-managed imports

Allow a parent to import supported local audio through the iOS Files picker, give it a child-friendly name, and select an excerpt. Initial target formats are MP3, M4A, and WAV, subject to supported codecs. Store the imported copy on the device for offline playback.

Protected subscription downloads are outside ordinary file import. Importing a file does not grant rights to redistribute its music. Imported tracks initially support freely placed choreography; automatic beat detection remains a possible later enhancement.

Reference: [Apple SwiftUI file importer](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)).

## Visual direction

A colorful, polished skating studio with expressive characters, attractive outfits, and clear movement animations. Use large controls, recognizable move illustrations, and an uncluttered rink. The style should appeal across ages 3–12 and produce performances older children can take pride in.

## Proposed first release

- One rink.
- A customizable skater and a small outfit collection.
- A substantial, varied move collection selected from the researched difficulty-ranked catalog.
- Smooth automatic transitions between moves.
- Five built-in instrumental tracks.
- Routines approximately 30–60 seconds long.
- Simple move-card editing with expandable timing controls.
- Parent-managed audio import.
- Offline creation, local saving, and replay.

## Release boundary

The first version focuses on creating and replaying routines inside the app. Video export and public sharing remain later decisions because they introduce additional music-rights and child-privacy requirements.

## Design priority

A young child should be able to create a satisfying first show with a few taps. An older child should have meaningful ways to revisit that show, refine its choreography, and make it feel like their own.
