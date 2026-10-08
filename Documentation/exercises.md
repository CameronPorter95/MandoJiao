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

**The teach view shows a sentence using the word,** from Tatoeba, with its pinyin and
English and the word in the accent colour. The lesson looks one up for every taught word
as it appears, so none is waited for on its card; a word with none, or a failed lookup,
shows the word alone, and a failure is logged rather than alerted.

**The sentence uses the word in a sense its card gives.** A reading's characters can mean
several things, and 打's easiest sentences are all 打电话, "call", when its card says "to
hit". A sentence counts only where its English translation says one of the word's meanings
in the learner's library, the headline before the rest (`EnglishMeaning`: rough stems, the
common irregular forms, possessives, and spellings that name the same thing: the starter's
飞机 "aeroplane" found nothing among sentences saying "plane" and "airplane" until
aeroplane, airplane and plane met, with colour/color and the other British spellings a
learner may type). It cannot see paraphrase ("give me a ring" is not
"to call") and treats a meaning made only of grammar or prepositions, as 了's or 在's
"at, in", as having nothing to check; both are pinned as costs. The tool keeps, besides
each reading's ten easiest, the easiest sentence for every meaning those leave out (735 of
them), which gave 打 "Why did you hit me?". With a sentence in the headline's sense: HSK 1
86% of words (77% before), HSK 2 84% (73%), HSK 3 80% (75%).

**A card's pinyin need not match the dictionary's tone for tone.** The starter writes 对不起
duìbùqǐ, with 不's own tone, where the dictionary and Tatoeba have the spoken duìbuqǐ, so it
found no sentence. Where the card's pinyin is no reading the dictionary has, the lookup takes
the dictionary's one reading with the same letters; never a reading of its own (东西 dōngxī,
了 liào), and never one of two (好 hǎo and hào).

**Where none says a meaning, the device writes one,** decided by the owner: Apple's on-device
model (`ModelExampleGenerator`, behind `ExampleGenerating`) is asked for one short sentence
using the word in its headline sense, then, in a fresh session, for its English. Only the
Hanzi and that English are the model's; the pinyin is the card's for the word and the lexicon's for the rest,
since a small model's pinyin cannot be trusted on polyphones, though the lexicon's preferred
reading can be wrong for another polyphone in the sentence. `GenerateExampleUseCase` drops a
sentence that leaves the word out, has another script or digits, runs past 16 characters, or
has no translation. Nothing is generated without the model: an older device, Apple
Intelligence off, the model not ready, or no Chinese. **Then the card shows no example,**
decided by the owner: never a sentence in another sense in its place. A generated sentence
is marked "AI-generated" under its translation, decided by the owner after the second review.

A refusal (the safety filter declined 小学生 two times in three), an answer that runs on, or
a sentence the checks drop is tried again, three tries in all. The prompt says the sentence
must contain the word as written: asked only to use 看病, the model wrote 看医生 every time.
Answers are capped at 120 tokens; uncapped, one ran on until it filled the model's context.

**Testing it.** The model runs on a Mac with Apple Intelligence as on a phone, and the
generator's code builds for macOS, so `Tools/ExampleReview` (`swift run review-examples`)
runs the app's own generator over every starter and HSK 1-3 word that would ask it, several
times each, and writes the results for a native speaker's review page. On 2026-10-08, 137
words would ask. Keeping to the starter's words, 87% of runs gave a usable sentence, after
220 of 626 tries were dropped; with no word list, 93%, after 84 of 537.

Both review rounds held each word to its headline alone, as written, where the app holds a
card to every meaning, each made short by `Gloss.plain`: 可能's "might (happen)" is asked
for as "might", and a Tatoeba sentence saying "possible" serves it. The harness now does
the same, and on 2026-10-09, 90 words would ask, not 137. `--card 赉/lài/to bestow` tries
any card. In a debug build, `ExampleLog` prints each written sentence and whether the checks
keep it, under the `examples` category; a dropped one otherwise shows only as a card with no
example. It was added when 可能 got none on the simulator in three lessons running, then
got one in both lessons after a reinstall; the cause was not found.

The owner's partner, a native speaker, judged one sentence a word from each. Kept to the
starter's words: 37% natural, 34% awkward, 27% wrong, many of them nonsense built around
买书 and 学校 ("go to the junior high school to buy books"). Written freely: 61% natural,
17% awkward, 20% wrong. So the prompt no longer gives a word list. Her notes showed "wrong"
covering several faults: most often the English translation, where the Mandarin was fine
(后年 as "next year", 包子 as a bun); then ungrammatical or incomplete Mandarin (张桌子 for
一张桌子); sentences that made no sense; and two utterances run into one (谢谢你，不客气).

**Generated sentences are held,** decided by the owner on 2026-10-08:
`OnDeviceExamples.isHeld` makes the app's generator write nothing, so every card behaves as
on a phone without the model, until a second review. That round judges the Mandarin and
the translation apart, with reasons, and compares the model's own translation with one asked
for separately, shown unlabelled and in alternating order. Its verdicts decide whether the
hold lifts, with which translation, marked as AI-generated or not.

Before it went to her, the owner saw both translations write "I and my mom", the Chinese
order glossed. No wording of either prompt changed that, and both made 后年, the year after
next, "next year" even when told what it means; an example put in the prompt was copied
into other sentences ("My mom and I are having fun together" for the family playing). So
the fixes are in code: `EnglishWordOrder` puts the speaker last in the shapes the model
writes, and a written sentence's translation must say the card's meaning, as a Tatoeba
sentence's must. A sentence needs four Han characters (我和你 passed at three) and the
prompt asks for a complete one. The cost: of 411 runs, 51% kept where 91% were, and 83 of
137 words have a sentence where 134 did, partly because the matcher is literal: 水里有鱼,
"there is a fish in the water", fails 里's "inside".

**The second review** (2026-10-09), of those 83 sentences: Mandarin 81% natural, 7% awkward,
12% wrong; no sentence was marked down for grammar or punctuation. The model's own
translation was right for 71%, the separate one for 78%, though only the model's had to pass
the meaning check; where they differed, the separate one was right 11 times in 16. Taking
the separate one, 70% of sentences were natural with a right translation. So:

- **The English is asked for on its own,** told what the word means. The sentence's
  generated type keeps an English field the app ignores: without it, every request for 和
  and 女生 on the Mac tripped the guardrail.
- **Word order is left to `EnglishWordOrder`,** which now takes names ("I and Xiaoming" got
  through). Given the rule as the pattern "X and I", the translator wrote "X and I went to
  the park with my mom".
- **Generated sentences are marked,** since nearly a third had a flaw somewhere.
- **The hold is lifted,** decided by the owner on 2026-10-09: `OnDeviceExamples.isHeld` is
  false, so a device with the model shows a written sentence, marked.

About ten failures were the card's meaning, not the model's: 女生 "schoolgirl" for a girl,
本子 "book" for a notebook, 箱子 "suitcase" for a box, 公交车 "public transport vehicle" for
a bus, 初中 and 高中 "junior" and "senior high school", 大小 "large and small" for size. The
meaning check makes a translation say these, so the right one, "I know a girl", was dropped
for 女生, though "girl" is among its card's meanings: a written sentence was held to the
headline alone. Now, as a Tatoeba sentence, it may say any meaning on the card, while the
model is still asked for the headline. The flagged meanings were then fixed in
`Tools/MakeHSK/headlines.tsv`: 女生 "girl", 男生 "boy", 箱子 "box", 本子 "notebook" (with
"exercise book" only; it had "book" and an erotic comic), 公交车 "bus", 大小 "size", 请客
"to treat", and, the owner's choice, 初中 "middle school" and 高中 "high school", kept apart
as her "secondary" and "high" school are not in New Zealand English. Of the nine, only 本子
and 初中 still ask the model, and 87 words would ask, not 90. A card already installed keeps
the meanings it was installed with.

**Then the sentence is chosen for the learner,** as the owner asked: the one with the fewest
words outside those they have started (answered at least once, or marked learnt;
`TodayPlan.known`), and among equals the easiest. Measured on Tatoeba's export:

| Learner | Sentence of only known words | At most one unknown |
| --- | --- | --- |
| knows the starter and HSK 1, learning HSK 2 | 74% of words | 94% |
| knows 30 starter words, learning the other 35 | none | 17% |

Ten candidates rather than every one keeps the file at 5.9 MB; all of them would raise the
first row to 77%. A learner in their first days is the gap: Tatoeba has almost no sentence
made of a few dozen words, so the fewest unknown words is the best it can do. The model
writes for them only where no sentence says the meaning; writing for every early learner
too would be the next step if Tatoeba's fit proves too poor in use.

`Tools/MakeExamples` builds `Examples.tsv` from Tatoeba's downloads. The rules, each
measured before it was chosen:

- **Simplified only, from every sentence.** Tatoeba transcribes each sentence written in
  traditional into simplified, so all of its translated Mandarin sentences can be used:
  25,000 kept, where the sentences written in simplified alone gave a third as many and
  left 了 and 学生 without one.
- **The reading is the transcription's.** Tatoeba's pinyin splits a sentence into words.
  A word only takes a sentence where it is whole words of that split, and where its pinyin
  says the reading. Without this, 长 cháng showed 他长大了, where it is zhǎng; 42 of HSK 1's
  words have more than one reading.
- **Tones.** 不 and 一 match any tone, since theirs change. A neutral tone matches any only
  inside a longer word, as 学生's -sheng is written both ways; a one-syllable word's tone is
  all that tells 了's liǎo from liào. A reading said tone for tone keeps a sentence from one
  only matched loosely, so 东西 dōngxī, east and west, does not take thing's sentences.
- **Easiest first:** the hardest other word at or below the word's own HSK level, then a
  length near eight characters, then pinyin a person has reviewed. Each sentence carries
  its words, as their lengths, so the app can count the ones a learner knows.

290 of HSK 1's 298 readings have an example, 199 of HSK 2's 202, and 471 of HSK 3's 494.
Tracing and translation will bring themes of their own.

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
