# MandoJiao

An iPhone app for practising Mandarin vocabulary, built around the idea that
recognising a word and being able to say it are different skills, and both need
drilling.

Two exercises, one shared word list.

## Matching

Five English words on the left, five Hanzi on the right. Tap one, tap its
partner, and the pair goes out. A match can start from either side, resolves the
instant the second tile is tapped, and the success tone climbs a note with every
pair so the board sounds like it is filling up. Ten rounds to a lesson.

It is a better tool than flashcards for words you barely know, because five at a
time means you can work by elimination and still get something right.

## Mistakes drill

Every word you get wrong goes on a mistakes list. The drill takes those words one
at a time: the English is shown, you say the Mandarin out loud, and the app tells
you whether you got it. One card per word, so a short list makes a short lesson
rather than padding itself out with words you already know.

Recognition runs on-device. Answers can be typed instead of spoken at any point,
in pinyin or Hanzi.

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

Ships with 65 starter words across six decks. Add, edit and delete your own from
the library, and group them into decks to practise a subset. A lesson draws from
either the whole library or one deck.

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
a pass for tests that never ran. See `docs/working-on-this.md`.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit together
- [`docs/grading.md`](docs/grading.md) — why answer checking works the way it does
- [`docs/speech.md`](docs/speech.md) — the microphone and recognition pipeline
- [`docs/working-on-this.md`](docs/working-on-this.md) — build traps and how to verify changes
