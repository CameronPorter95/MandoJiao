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
Library/        Words, decks, folders, the mistakes list, word strength, the library tab.
Progress/       Home and today's plan.
Dictionary/     CC-CEDICT, the HSK list and the lexicon, with the dictionary tab.
Practice/       Every exercise, one folder each: Matching, Speaking, Flashcards, and
                MixedLesson, which runs today's plan as one lesson.
Settings/       The settings screen, editing what the lessons own.
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
card's direction at random. A card showing Chinese is always picked from four English
options. Typed, its English was marked wrong too often when it was right: "leave work"
for 下班, a wording of 了's "completed action marker", 分's "minute", a sense the
dictionary has and the word did not keep. Nothing short of judging the meaning fixes
that, and picking tests understanding it as well. A card showing English is typed or
picked at random, since Hanzi is right or it is not.

Wrong options come from the lesson and from the rest of the vocabulary, handed over in
the request as `otherWords` but never put to the learner, and never share the word's
Hanzi or any meaning, since one that also fits would mark a right pick wrong. With too
few, a card that would show Chinese shows English and is typed. One word is enough for
a lesson.

`FlashcardGrader` grades typed answers. A card showing English takes the Hanzi only, and
also any word in the vocabulary sharing a meaning, since the English alone cannot tell
看 from 见. Text it cannot take, pinyin or English, is turned away without spending the
one try. Costs pinned by tests: a traditional form is wrong. The English rules (every
meaning and each part of one, case, punctuation, asides and a leading "to" ignored, one
letter off from five letters) are kept and tested for if a typed card showing Chinese
comes back with a way to overrule a verdict; they already reject "buy" for 卖.

One try per card, then the word in full. Don't know gives the card up: it counts as a
mistake and is recorded as wrong with no tries, so giving up reads apart from guessing
wrong. Typed and picked answers are recorded as separate exercises, since typing recalls
a word and picking only recognises it.

A right answer plays the matching board's success tone, on the same note each time
rather than climbing card by card as a board's does, and leaving the last card plays
the lesson complete tune. A wrong answer and Don't know play nothing. Unlike the speaking lesson,
flash cards never record audio, so the tones cost recognition nothing.

## Today's plan

`TodayPlanner`, in `ProgressDomain`, suggests one plan for Home from how the
vocabulary's strengths stand, with a theme and a line saying what it will do. Its
steps are plain: teach a word, a matching board, recognise a word, produce one, read one
aloud.

- **Review**, when eight or more words are fading (recall below 90%), or when nothing is
  new: up to twelve, weakest first. A Learning word is recognised from its Chinese; a
  Familiar or Known one has its Hanzi typed.
- **New words** otherwise: up to five unstarted words from the deck or folder Home carries
  on with, else from anywhere. Each is taught, then all are matched on one board, padded
  with other words that share no Hanzi or meaning, then each is recognised, then each is
  read aloud, then any fading words are reviewed. Speaking comes once a word has been met
  and recognised, as the owner asked.

`MixedLesson` runs a plan: it turns recognise and produce into flash cards, shows the
teach view itself, and builds each other step from the exercise that owns it, all in
`Practice`. Each step hands back its answers; the lesson records them once, with the
plan's deck, and plays the lesson complete tune at the end.

A read-aloud step is the speaking lesson's view model for one card, made with `.step`
completion: the same microphone rules, three tries and typed pinyin fallback, handing its
answer back once the card settles instead of recording it. One recogniser serves the
whole lesson, so the speech model is prepared once.

A run of read-aloud steps carries on as the speaking lesson does between cards: after a
right answer, unless typing was chosen, the next read starts listening by itself, and an
automatic listen that hears nothing is not a try. The owner found re-tapping the
microphone for every word on the first device run. Because the steps share the
recogniser and the next can appear before the last disappears, a step leaving cancels
the recogniser only if it was itself listening.

**The mixed lesson owns the audio session between steps,** not the step. A read-aloud step
takes the microphone's session when it appears, as the speaking lesson does, but never
hands it back. The lesson hands it back when the next step does not listen, when it
closes or goes away, and before the fanfare. A run of read-aloud steps therefore keeps
the session, and a matching or flash card tone after one plays at the usual level.
Whether switching between steps costs recognition anything is only measurable on a
device.

Example sentences in the teach view come next, from Tatoeba. Tracing and translation will
bring themes of their own.

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
