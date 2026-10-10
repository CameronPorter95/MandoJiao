---
name: drive-app
description: Test a flow or feature of MandoJiao by driving the app on a simulator with mando --remote, and report what each screen showed. Use when asked to test a flow, try a feature, check a screen, or reproduce a bug in the running app.
---

# Driving the app to test a flow

mando sends the app the same actions its screens take from taps, and prints what each
screen would show. Through it you can open decks, run lessons, answer by speaking and read
every screen's state, on the simulator, without screenshots. `Documentation/headless-cli.md`
describes it in full.

## Setup

If you were told the app is already running for you, with the simulator named, skip this.
Otherwise run:

```sh
Tools/test-flow --prepare
```

It builds the app and mando, installs the app on the simulator the user is watching in
DeviceHub, keeping its data, launches it with `-remote -scripted-speech`, and prints the
banner of the app it reached. Never tick those flags in the scheme. The data is the user's:
drive it as they would, and do not delete or reset what you did not make.

## Driving

Each run pipes commands in and prints a transcript:

```sh
printf '%s\n' 'tab vocabulary' 'open deck Greetings' 'ls' | Tools/MandoCLI/.build/debug/mando --remote
```

**Scout, then run the flow in one go.** A command takes a fraction of a second; a turn of
yours takes seconds, and the user may be watching the simulator. So:

1. Plan before the app moves. Take commands and payloads from the map below; read code only
   for what it does not cover, and do all of that reading before your first run. Once the
   app starts moving the user is watching it, and a pause to search code leaves it sitting
   on one screen for a minute.
2. Write the whole flow as one run, with an `ls` after each step whose result you will
   check, and send it. The transcript shows every step's result after the fact.
3. Read it. Only where something surprised you, go back to one step at a time.

Do not send one command per turn when the next one does not depend on reading the last.

## Map

Every command below was run as written. Payload keys differ from screen to screen, and
an action whose payload has no label takes `_0`. The `do` lines shown under a screen are
sent while that screen is in front.

- **home**
  - Settings: `do opened {"destination":"settings"}`, then `back`.
  - Today's plan: `do todayPlanTapped`.
  - Quick practice, which is a matching lesson: `do quickPracticeTapped`.
  - The continue card: `do continueTapped {"exercise":"speaking"}`.
  - Mistakes, when there are any: `do practiseMistakesTapped`.
- **vocabulary**
  - `open folder Starter` shows a folder's decks. `open deck Greetings` opens a deck from any tab.
  - A deck can start a lesson: `do startLessonTapped {"exercise":"speaking"}`, or `matching` or `flashcards`.
  - Search a deck: `do searchChanged {"_0":"ni"}`.
  - The add-words sheet: `do addWordsTapped`, then `do addWordsDismissed`.
  - `back` pops one level: deck, then folder.
- **dictionary**
  - Search: `do queryChanged {"query":"pengyou"}`. Results are numbered from 0.
  - Open a result's page: `do opened {"result":0}`.
  - A page's character: `do characterOpened {"character":0}`.
  - `back` pops the page.
- **settings** (opened from home)
  - `do strictnessChanged {"strictness":"strict"}`
  - `do showsPinyinChanged {"showsPinyin":true}`
  - `do matchingRoundsChanged {"rounds":5}`
  - `do speakingCardLimitChanged {"cardLimit":10}`
  - `do skipsLearntWordsChanged {"skips":true}`
  - These change the user's settings, so set back anything you change.
- **lessons**
  - Speaking: `say <pinyin>`, then `do continueTapped`.
  - Matching: a tile by its text, `do tileTapped {"tile":"hot"}` then `do tileTapped {"tile":"热"}`.
  - Flash cards: `do optionPicked {"option":0}` for a card with options (numbered from 0 in
    `ls`), or `do typedAnswerSubmitted {"answer":"名字"}` for one that asks for the Hanzi.
    `do dontKnowTapped` gives up on a card.
  - Every lesson: `back`, then `do quitConfirmed` only if `ls` shows `confirming quit`.
    A lesson with nothing answered closes without asking.

Some actions change the user's data and are left off the map: `vocabularyTapped` saves a
word, and the delete, remove, move and rename actions do what they say. Use them only when
the flow is about them, and undo what you can.

**Write each run exactly in that shape**: `printf '%s\n'`, then each command in its own single
quotes, piped to the mando path written out in full. A run started by `Tools/test-flow` may
only run what its allow list names, so anything else is refused and costs a turn:

- no shell variables, `$'…'` or double-quoted commands; a JSON payload goes inside the
  single quotes as it is: `'do startLessonTapped {"exercise":"speaking"}'`
- nothing chained with `;`, `&&` or a second pipe; a screenshot is a call of its own

- The state lives in the app, so the next run carries on from where this one left it.
- Take action names and payload keys from `ls` and `state`; never guess them.
  `do <action> {json}` sends one, for example `do startLessonTapped {"exercise":"speaking"}`.
- A lesson's cards come in a random order. To answer from a plan made in advance, read
  them from `state` once the lesson has started, then send the answers as the next run.
- End every run with `ls`, so you see where it left the app.
- A line starting `✗` is a failure. mando still exits 0, so read the transcript.
- A line starting `·` is an effect a screen sent: a navigation, a save, a lesson's result.
- `say <answer>` answers the speaking lesson, or a read-aloud step of today's plan, with
  toneless pinyin or Hanzi. The summary shows the pinyin, so answers can come from `ls`.
  Cards come in a random order, so for a wrong answer say `zzz`, which is no card's
  answer, rather than another card's word.
- A right answer moves on to the next card by itself after 850ms. Between runs it will
  have moved, so `do continueTapped` is only needed within the same run.
- `back` taps a lesson's ✕, or closes a sheet or a search, then pops the open tab. A lesson
  with a card settled asks first, `confirming quit`; answer `do quitConfirmed` or
  `do quitCancelled`. A speaking card counts as a mistake only once it is out of tries.
- Use the app's names: the tabs are home, vocabulary and dictionary.

## What to test

For a named flow, drive it as a user would, then its edges: going back mid-way, a wrong
answer, an empty deck, the same action twice.

A tour goes a level below each tab's root, not just to it:

- vocabulary: open a folder, then a deck, then search it.
- dictionary: search, open a result, then one of its characters.
- home: settings, today's plan, and quick practice, each closed again.

Then any lesson the prompt names. All of it is one run.

For "the new feature" or "what we've been working on", read `git log develop..HEAD` and
`git diff develop...HEAD --stat`, then the changed screens' view models and actions. Test
what changed, and the flows next to it that the change could break.

## Screenshots

When how something looks matters, take one and read it:

```sh
xcrun simctl io <udid> screenshot .build/test-flow/shots/<name>.png
```

## What this cannot judge

Say so in the report rather than implying it was checked:

- Layout and appearance, beyond any screenshots taken.
- Speech recognition: `say` replaces the recogniser, so grading of a queued answer is
  tested and hearing is not.
- Audio, haptics and device-only runtime warnings.
- Example sentences from the on-device model on an iOS 27 simulator, which has none.

## Do not fix

Report what you found; do not edit code, rebuild or reinstall mid-test. If the app stops
answering, say so and stop.

## Report

1. One line: what was tested and whether it worked.
2. Each step: the command, what you expected, what `ls` showed.
3. Each failure or surprise, with the transcript lines that show it.
4. What could not be judged here.
