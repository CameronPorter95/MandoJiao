# MandoJiao

An iPhone app for practising Mandarin vocabulary, built around the idea that
recognising a word and being able to say it are different skills, and both need
drilling.

Three exercises, one shared word list, each started from a deck's or folder's Start lesson menu.

## Matching

Five English words on the left, five Hanzi on the right. Tap one, tap its
partner, and the pair goes out. A match can start from either side, resolves the
instant the second tile is tapped, and the success tone climbs a note with every
pair so the board sounds like it is filling up. Ten rounds to a lesson.

It is a better tool than flashcards for words you barely know, because five at a
time means you can work by elimination and still get something right.

## Read aloud

One word at a time: the Hanzi is shown, you read it out loud, and the app tells you
whether you got it. Every word you get wrong goes on a mistakes list, and Home drills
that list this way. One card per word, so a short list makes a short lesson rather
than padding itself out with words you already know.

Recognition runs on-device. Answers can be typed instead of spoken at any point, in
pinyin, since the Hanzi is already on the card.

## Flash cards

One word at a time, shown in Chinese or English, chosen by the app, and answered
either by typing or by picking from four. A card showing Chinese takes the English,
any of the word's meanings; one showing English takes the Hanzi only. One try per
card, or Don't know, which counts as a mistake, then the word in full. A right answer
plays the matching board's tone, climbing through the lesson, and the end plays its
finishing tune.

## Grading

Tones are never graded. A recogniser's idea of which tone you used is its own
guess as much as yours, so failing you on it would be unarguable. Everything is
compared as toneless pinyin syllables instead.

Beyond that, how forgiving the app is comes down to a setting, tightest first:

| Level | Also accepts |
| --- | --- |
| Strict | Nothing more. Exact syllables, best guess only. |
| Standard | The recogniser's second guesses, and `zhi` for `zhe`, `shi` for `she` and the like. |
| **Relaxed** (default) | One `-ng` ending for another, so `cheng`, `chang` and `chong` all count. |
| Generous | `zh` for `z`, `ch` for `c`, `sh` for `s`, `-ng` for `-n`, and a syllable a letter or two out. |

Every level accepts the word inside a longer phrase, because the recogniser
routinely pads a single word into something sentence-shaped and the speaker
never said the extra part.

Each level's cost is deliberate and recorded in a test. Homophones pass at every
level; `是` and `社` merge from Standard up; `想` and `兄` merge from Relaxed up.

## Word list

Ships with 65 starter words across six decks, in a Starter folder, and HSK 1 from the
2025 revision of HSK 3.0, split into decks of 50 or fewer words, most common first. The
other levels, up to 7-9, are added or restored from the HSK levels list in My Vocabulary. Each
HSK word takes up to four meanings from the dictionary for its reading, headed for HSK 1
to 5 by an everyday meaning chosen by hand in `Tools/MakeHSK/headlines.tsv` where the
dictionary's first is not. A character with two everyday readings, like 长 cháng and zhǎng,
is two words, listed in `Tools/MakeHSK/readings.tsv`. Rebuild the list with `Tools/MakeHSK`
after `Tools/MakeDictionary`. Add, edit and
delete your own in My Vocabulary, and group them into decks to practise a subset.
Every deck lives in a folder, and folders hold decks and other folders to any depth,
arranged by dragging in the Vocabulary tab's tree as in Notes. On iPad the tree sits beside the folder or deck that is open. A lesson
draws from all your words, one deck, or every deck beneath a folder. My Vocabulary and
each folder are searchable: opening the search lists every word in scope, all of them or
those in every deck beneath the folder, sorted as chosen, and typing filters them. New words
are added from My Vocabulary's menu or the dictionary, and can go straight into a deck,
chosen by its folder's path, from the word editor.

## Dictionary

The whole of CC-CEDICT is bundled, and the Dictionary tab searches it by Hanzi, by pinyin
with or without tones, or by English. Pinyin without tones finds every tone; a tone written,
as "wéi" or "wei2", finds only that tone. The word list is searched the same way. A headword's page lists every reading with all its
senses, a reading in the HSK syllabus marked with its level, and each of its characters.
The dictionary is read-only and apart from your
vocabulary: editing a word, its meanings can be chosen from the dictionary's senses, which
copies them into the word. Each reading on a page, and each search result by swiping
right, can be added to the vocabulary, which opens a new word filled in with its Hanzi,
pinyin and first sense, and a deck to add it to, or, once saved, opens the word in the
vocabulary instead. Search
results already in the vocabulary are ticked.

## Building

Requires Xcode 26 and an iOS 26 simulator or device. The project is iPhone and
iPad only.

```sh
xcodebuild build -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Speech recognition cannot be judged on a simulator. The typed path can, and the
whole app runs there apart from the microphone.

Run `xcodebuild clean` before `test` after adding or changing a test file. The
incremental build in this project will silently skip recompiling them and report
a pass for tests that never ran. See `Documentation/working-on-this.md`.

## Documentation

- [`Documentation/exercises.md`](Documentation/exercises.md): how the exercises and the mistakes list work
- [`Documentation/grading.md`](Documentation/grading.md): why answer checking works the way it does
- [`Documentation/speech.md`](Documentation/speech.md): the microphone and recognition pipeline
- [`Documentation/working-on-this.md`](Documentation/working-on-this.md): build traps and how to verify changes

### Architecture

The app is built on an **MVI + Clean Architecture** pattern (domain / data / UI
layers, unidirectional data flow, SPM packages, and a KMP-ready domain layer).

- [`Documentation/architecture.md`](Documentation/architecture.md): the reference template and the reasoning behind it
- [`Documentation/modularisation.md`](Documentation/modularisation.md): packages, targets and dependency rules
- [`Documentation/modularisation-migration.md`](Documentation/modularisation-migration.md): current state and sequencing
- [`Documentation/feature-checklist.md`](Documentation/feature-checklist.md): the per-change conformance list
- [`Documentation/code-comments.md`](Documentation/code-comments.md): comment rules
