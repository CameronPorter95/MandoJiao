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
Vocabulary/     Words, decks, folders, the mistakes list, home and library tabs.
Speaking/       The speaking lesson.
Matching/       The matching lesson.
Flashcards/     The flash card lesson.
Settings/       The settings screen, editing what the two lessons own.
MandoJiao/      The app: entry point and composition root.
```

Each package splits into Domain, Data, UI and DI targets. See
[`modularisation.md`](modularisation.md).

## Storage and the detachment boundary

`VocabWord` and `Deck` are the SwiftData entities. A word carries an ordered list of
`meanings`, `hanzi`, `pinyin`, and its outstanding `missCount`. The first meaning is the
headline, also stored as `english` so a word saved before meanings existed reads back
as its one meaning. A deck holds words and a `Folder`
holds decks and other folders, so a deck of decks cannot exist. Every deck is in a
folder: the starter decks are seeded into one with the `starter` built-in key. Deleting a folder
cascades to everything beneath it; words always stay. The one nesting rule the
types cannot express, that a folder never moves beneath itself, lives in
`FolderTree.swift` in the domain, and the store checks the same function before it
writes. Siblings are listed in array order; the store keeps it as each one's
`position`, rewritten from `movingFolder` and `movingDeck` after every move.

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
words on a board from sharing hanzi or any meaning, which is what makes a board
solvable. A tile shows only the headline, but 行 on "to walk" beside 可以 on "okay"
would still be a board where "okay" fits both.

A pair's `english` is the headline shortened with `Gloss.plain`, and `otherMeanings`
the rest. Tiles show the headline alone, and the rest appear once the answer is out:
on a solved English tile and in the lesson summary.

A speaking card shows the Hanzi to read aloud, not the English: an English headline
could ask for several Chinese words, and which one the card wanted was ambiguous. Its
answer is the pinyin and every meaning. A typed answer must be pinyin, since typing the
characters on the card would be copying them.

`SpeakingPlanBuilder` does none of that. One card per word, in the order given,
capped. Dropping the five-at-a-time floor is the entire reason the speaking lesson exists:
the matching board had to pad a three-word mistakes list with unrelated words.

Both sessions expose `missesByPairID` and `cleanSolvesByPairID` in the same
shape, which is what lets one `LessonResults` and one review screen serve both.

## Flash cards

`FlashcardPlanBuilder` makes one card per word, in a random order, and chooses each
card's direction and format at random: Chinese shown and English asked, or English
shown and Hanzi asked; typed, or picked from four. A card is picked only when the lesson
has three other words sharing neither its Hanzi nor any meaning, since a wrong option
that also fits would mark a right pick wrong; otherwise it is typed. One word is enough
for a lesson. Later the lesson plan will choose direction and format from word strength.

`FlashcardGrader` grades typed answers. English is matched against every meaning and
each part of one ("to tell, to inform" takes "inform"), ignoring case, punctuation,
asides in brackets and a leading "to", "a", "an" or "the", with one letter wrong,
missing or extra let through from five letters up. A card showing English takes the
Hanzi only, and also any word in the lesson sharing a meaning, since the English alone
cannot tell 看 from 见. Text a card cannot take (pinyin for Hanzi, Hanzi for English)
is turned away without spending the try. The costs, each pinned by a test: a traditional
form is wrong, and so is a synonym the word does not list.

One try per card, then the word in full. Don't know gives the card up: it counts as a
mistake and is recorded as wrong with no tries, so giving up reads apart from guessing
wrong. Typed and picked answers are recorded as separate exercises, since typing recalls
a word and picking only recognises it.

A right answer plays the matching board's success tone, on the same note each time
rather than climbing card by card as a board's does, and leaving the last card plays
the lesson complete tune. A wrong answer and Don't know play nothing. Unlike the speaking lesson,
flash cards never record audio, so the tones cost recognition nothing.

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
