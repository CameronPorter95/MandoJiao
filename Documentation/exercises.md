# Exercises

How the two exercises, the mistakes list, sound and settings work today. These are
product rules and survive any restructuring. The target architecture is in
[`architecture.md`](architecture.md); where the code is relative to it is in
[`modularisation-migration.md`](modularisation-migration.md).

SwiftUI and SwiftData, iOS 26, no third-party dependencies.

The shape worth knowing: **exercise logic never touches SwiftData, SwiftUI or
AVFoundation.** Lessons are built from detached value types, which is what lets
the interesting parts be tested without a simulator, a store or a microphone.

## Current layout

```
Core/           Shared plumbing: errors, effects, the design system, DI, ToneEngine.
Vocabulary/     Words, decks, the mistakes list, home and library screens.
Speaking/       The speaking lesson.
Matching/       The matching lesson.
MandoJiao/      The app: entry point, composition root, settings screen.
```

Each package splits into Domain, Data, UI and DI targets. See
[`modularisation.md`](modularisation.md).

## Storage and the detachment boundary

`VocabWord` and `Deck` are the SwiftData entities. A word carries `english`,
`hanzi`, `pinyin`, and its outstanding `missCount`.

`WordPair` is the same word as a plain struct. **Every lesson is built from
`WordPair`, never from `VocabWord`.** A lesson is therefore stable if the library
is edited while it is open, and none of the exercise code can reach a managed
object. `VocabWord.uuid` exists so a pair keeps a stable identity across that
boundary, since `persistentModelID` is not a `UUID`.

Results come back the other way as `LessonResults`, two plain dictionaries keyed by
that uuid, through `RecordLessonResultsUseCase`.

## The two exercises

They are deliberately separate rather than one generalised engine, because they
differ in almost everything except where their results go.

| | Matching | Speaking lesson |
| --- | --- | --- |
| Plan | `MatchingPlan`, 10 rounds of 5 pairs | `SpeakingPlan`, one card per word, max 20 |
| Board | `MatchingBoard`, a value type | no board, one card at a time |
| Driver | `MatchingViewModel`, over a `MatchingLesson` value | `SpeakingViewModel`, over a `SpeakingLesson` value |
| Minimum words | 5 | 1 |
| Input | taps | speech, or typing |

`MatchingPlanBuilder` deals pairs from a shuffled bag, refilling when it empties, so a
small pool repeats only after every word has had a turn. It also keeps any two
tiles on a board from reading the same, which is what makes a board solvable.

`SpeakingPlanBuilder` does none of that. One card per word, in the order given,
capped. Dropping the five-at-a-time floor is the entire reason the speaking lesson exists:
the matching board had to pad a three-word mistakes list with unrelated words.

Both sessions expose `missesByPairID` and `cleanSolvesByPairID` in the same
shape, which is what lets one `LessonResults` and one review screen serve both.

## The mistakes list

A word's `missCount` goes up when it is part of a wrong answer and down when it
is later solved cleanly. Two rules matter:

- A wrong guess on the matching board is recorded against **both** words
  involved. They were confused for each other, so both are worth drilling.
- Solving a word later in the same lesson that missed it does **not** cancel the
  miss. Without that a single miss would erase itself the moment the word came
  round again, which happens constantly with a small pool, and the list would
  stay permanently empty.

`MatchingBoard` tracks which pairs went wrong per board so a clean solve and a
recovery can be told apart.

## Sound

`MatchSoundPlaying` is a protocol in `CoreDomain`, handed to each lesson's view
model by its factory, which is the only place that names `ToneEngine`. The lessons'
logic therefore compiles and is tested where `AVAudioSession` does not exist.

`ToneEngine` synthesises sine buffers rather than playing sound files, which is
what allows the pitch to climb. It runs a pool of six player nodes so rapid
matches overlap instead of queueing behind each other.

The speaking lesson makes no per-card sound calls at all, and a test pins that. See
[`speech.md`](speech.md) for why.

## Settings

Four `@AppStorage` values, with their keys and defaults in one place
(`Preferences`) so a screen reading a setting and a screen writing it cannot
drift. `AnswerStrictness` keeps its raw values as storage and its titles as
display, so labels can be reworded without stranding a saved preference.
