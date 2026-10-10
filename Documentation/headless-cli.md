# Headless CLI: spike plan

A command-line tool, `mando`, that drives the app's screens on a Mac with no simulator,
so an agent can open a deck, run a lesson and read what the screen would show in
milliseconds. This is the agent tooling [architecture.md](architecture.md#guiding-principles)
principle 7 and [modularisation.md](modularisation.md#building-for-macos) already aim at.

The idea comes from Shopify's
[move back to native](https://shopify.engineering/back-to-native): business logic runs
headlessly on desktop, and a CLI exposes it to agents so they can inspect state, navigate
and perform actions without a simulator. Their CLI is a REPL: `do <action> {json}` acts
and acknowledges with `✓ <action>`, and reading is a separate command (`ls`).

> [!NOTE]
> This is a plan, not a description of the code. Sections are marked done as the work lands.

---

## What it proves and what it does not

It proves logic and navigation: what a screen does with an action, what state results,
which effects fire and where navigation goes. It says nothing about layout, whether a
view renders its state correctly, recognition quality (a scripted recogniser replaces the
real one), audio levels, haptics or device-only runtime warnings. Those stay with the
simulator and the device.

It does not replace tests. A view model test plus `swift test --filter` already runs in
seconds. The CLI is for exploring a flow without writing a test file, replaying a
reported bug, and long unattended agent sessions.

## What the code looks like today

**Identity.** Every `@Model` carries its own `uuid`, and every domain and navigation type
uses it (`DeckSummary.id`, `LessonSource.deck(UUID)`, `LibraryPage.deck(UUID)`);
`PersistentIdentifier` never leaves the data layer. The ids are random per store, so a
fresh in-memory store has new ones every run. `builtInKey` is stable for the HSK folders
and decks and the `starter` folder; the six starter decks have no key and are found by
name. So `ls` prints ids, and `open deck <name|key|uuid>` resolves against the vocabulary.

**Actions decode as they are.** Synthesised `Codable` on an action enum, measured:

```
.continueTapped                → {"continueTapped":{}}
.typedAnswerSubmitted("老师")   → {"typedAnswerSubmitted":{"_0":"老师"}}
.typedLabelled(answer: "老师")  → {"typedLabelled":{"answer":"老师"}}
.opened(.deck(uuid))           → {"opened":{"_0":{"deck":{"_0":"…"}}}}
```

`do <name> {args}` wraps its input as `{name: args ?? {}}` and decodes the real action, so
there is no per-screen parser. A labelled payload reads well; an unlabelled one becomes
`_0`. `SpeakingAction` has 12 cases, 11 without a payload, and needs only
`typedAnswerSubmitted(answer:)` labelled. Nested navigation payloads decode but are
unpleasant to type, hence an `open` shortcut over `do`.

**State and effects are not made `Codable`.** That would pull `SpeakingLesson`, `WordPair`
and `UUID`-keyed dictionaries into `Encodable`, surface on the KMP-shaped domain for the
sake of printing. Instead `ls` prints a summary written per screen, `state` prints `dump()`
of the whole state, and effects print with `String(describing:)`.

**Already headless:** `PracticeDI` builds for macOS with `swift build`, `DictationRecogniser`
and `ToneEngine` included (the other packages' DI targets are unchecked). The library's
stack is view model state, `LibraryState.path: [LibraryPage]`, which `LibraryRoute` binds.

**Not headless yet:**

- `TabView` has no selection state, `AppNavigationCoordinator` is in the app target, and
  the screens' inputs are composed inside `ContentView`, a `View`.
- Each Route maps effects to navigation in its `.task` loop. A driver needs the same
  mapping, and a copy would drift from the app. This is the main risk.
- `send`, `state` and `effects()` are internal.
- `ScriptedRecogniser` is in `PracticeTestSupport`, which is not a product, and replays
  transcripts given up front, so it cannot take a `say` typed at the prompt.

## The spike

Goal: open the library tab, open a starter deck, start a speaking lesson, `say` answers
and `ls` the result, with no simulator. Three screens: the library tab, deck detail and
speaking. Home, the dictionary, flash cards, matching and the mixed lesson are out.

```
mando> open deck Greetings
✓ open
mando> do startLessonTapped {"exercise":"speaking"}
✓ startLessonTapped
mando> say 你好
✓ say
mando> ls
speaking  card 2/10  谢谢  mic: idle  last: correct
actions: startListeningTapped, typedAnswerSubmitted, continueTapped, closeTapped, …
```

`say` is not a `do`: it feeds the scripted recogniser rather than acting on the view model.
Action names are the code's own, `continueTapped` rather than an imperative alias, so the
CLI's vocabulary cannot drift from the code's.

1. **Done for speaking. `ScreenDriver` in `CoreUI`.** A public struct of closures: its name,
   the action names it accepts, `send(name, json)`, `summary()`, `dump()` and `effects()`,
   which yields what navigation leaves over, described. Speaking's is
   `SpeakingViewModel.driver(navigation:)`.
2. **Not needed.** The plan was `package` access so `{X}DI` could build drivers. The view
   model builds its own driver in `{X}UI` instead, where `send`, `state` and `effects()`
   are already visible, so nothing is widened. `{X}DI` still supplies the seams when
   `makeDriver` arrives in step 4.
3. **Done for speaking. Effect handling out of the Routes.** `SpeakingNavigation.follow`
   carries out `.close` and returns any other effect. `SpeakingRoute` and the driver both
   call it, and haptics and alerts stay the Route's. `SpeakingStepRoute` has no
   navigation and is unchanged. Checklist U5 now names the driver as the second caller
   of `effects()`.

   Effects are described with `String(describing:)`, which gives
   `haptic(PracticeUI.SpeakingHaptic.success)`. Readable, but the module prefix is noise
   worth trimming before agents use it.
4. **Done for speaking. `makeDriver` beside `makeRoute`** on `LibraryFactory`,
   `DeckDetailFactory` and `SpeakingFactory`. The library's driver observes `state.path`
   and builds or drops a deck detail driver as pages are pushed and popped.

   `SpeakingFactory.makeDriver` takes the recogniser and the attempt log from its caller
   and fixes the rest: `SilentAudioSession` and `SilentSounds`, `advanceDelay` of
   `.zero`, and `Endpointing.endAtOnce`, which ends a listen at once, settled if
   anything was heard. That pulled most of step 5 forward. The test harness uses
   `endAtOnce` too, so one rule serves both.
5. **Done. Speaking seams.** `PracticeTestSupport` is a product, and `ScriptedRecogniser`
   is a queue with `enqueue`. It shows the next queued answer from `start` and takes it
   only on a `stop` that has one. Before, it set `partialText` only on `stop` and took an
   answer on every `stop`, so the automatic listen after a right answer heard nothing and
   ate the next card's answer; a test now fails on that behaviour. `say` in the CLI is
   `enqueue` then `startListeningTapped`. An answer queued ahead is heard by the automatic
   listen, as a learner carrying on would be.
6. **Done, without navigation between tabs. `Tools/MandoCLI`, building `mando`.** A second composition root: the store from
   `openStore(inMemory:)` (a `--store` flag needs `openStore` to take a URL), a small
   coordinator for the tab and the presented lesson, and the commands `tab`, `do`, `open`,
   `say`, `ls`, `state` and `back`. Stdin is read asynchronously, since a blocking
   `readLine` starves the view models' main-actor tasks, and each command waits for the
   main actor to settle before printing `✓`.
   What landed: `ls` lists the decks when nothing is open, `open deck <name|key|id>`
   pushes deck detail, and its `startLessonTapped` presents speaking through the real
   `DeckDetailNavigation.follow`. Matching and flash cards answer "not driven yet". There
   is no `tab`, since the library tab has no driver yet. Deck detail got its driver and
   `makeDriver` here, the rest of step 4 for it: `DeckDetailAction` is `Decodable`, only
   `startLessonTapped(exercise:)` is labelled (its other payloads decode as `_0`), and
   `LessonExercise` gained `String` raw values so it decodes from `"speaking"` rather
   than `{"speaking":{}}`. The speaking summary shows pinyin, so an agent can answer
   from `ls`.

   Each command waits until the open screen's dump, the stack and the effects stop
   changing for 30ms, capped at 2s, then prints `✓` and what happened meanwhile, one
   `·` line each. A whole ten-card Greetings lesson was driven from a script reading
   `ls` and saying toneless pinyin, ten right, no failed attempts.

   ```sh
   cd Tools/MandoCLI && swift run mando
   ```

7. **Done. Tests that stop the tool rotting.** Every listed action decodes: speaking's in
   `SpeakingDriverTests`, deck detail's in `DeckDetailViewModelTests`.

   Not a golden file. Deck ids are random and card order follows the store's fetch, so a
   whole transcript cannot be compared. Instead the commands live in a `MandoKit`
   library, `mando` itself is only the stdin loop, and `InterpreterTests` runs commands
   in-process and reads the transcript: the starter decks listed, a whole lesson
   answered from `ls` with ten right, closing back to the deck, an undriven lesson
   saying so, and refusals worded as sentences. Sending speaking to the flash cards
   callback in `DeckDetailNavigation.follow` fails both lesson tests. Five runs in a row
   passed, about 2.6s each, so the 30ms settle has held so far.

   ```sh
   cd Tools/MandoCLI && swift test
   ```

## After the spike

All done: drivers for every screen ([Every screen](#every-screen)), one composition shared
by the app and mando ([One composition](#one-composition)), checklist items H1 to H5 in
[feature-checklist.md](feature-checklist.md), and remote mode, below.

## Tabs

`mando` starts on home, as the app does, and `tab home|vocabulary|dictionary` switches. `open
deck` and `open folder` go through the vocabulary tab: a top-level folder is selected in its
sidebar and anything else pushed onto its stack, as tapping would. `ls` prints one line
per open screen, the tab first and the front last.

- **A screen in front of another.** `ScreenDriver` has `front`, the screen pushed or shown
  over it, and `back`, which pops its own stack. Commands go to the end of that chain, and
  `back` pops the deepest stack that has anything to pop.
- **`ChildDrivers`** (CoreUI) keeps a driver's pushed screens alive while they stay in its
  stack. Only the front one has appeared, as in a `NavigationStack`, and its effects are
  followed only while it is in front, as its Route's `.task` follows them. Without that, a
  lesson started from a pushed deck never presented: nothing followed the deck's effects.
  What the front screen leaves over reaches the parent's effects through an `EffectRelay`.
- **`isBusy`.** A dictionary search changes nothing for seconds while it reads the whole
  dictionary, so the 30ms quiet check gave up early and `ls` showed "searching". A busy
  screen now holds the settle, which is capped at 10s, and the settle runs before every
  command as well as after it.
- **The library's page context** moved from `LibraryRoute` to `LibraryViewModel`, so the
  Route and the driver build pushed screens from the same one.
- **Folder detail's opens** went through navigation closures straight from the Screen, so
  there was no action to send. They are now `deckOpened(id:)` and `folderOpened(id:)`,
  effects followed by `FolderDetailNavigation.follow`, as checklist U2 asks.
- **The dictionary's results** are picked by place, `vocabularyTapped {"result":0}`,
  rather than by a whole `DictionarySearchResult` in JSON.
- **Factories** share one `makeViewModel` between `makeRoute` and `makeDriver`.
- **`tab` is refused under a lesson**, as the app's full-screen cover hides the tab bar.

A pushed screen's leftover errors are relayed to its tab, and print as notes.

## Every screen

Every screen has a driver, and each is reachable from `mando`, headless and remote:

| Screen | Reached by | Notes |
| --- | --- | --- |
| Matching, flash cards | a deck's or folder's `startLessonTapped`, home | driver-only actions: `tileTapped {"tile":"水"}` by English or Hanzi, `optionPicked {"option":1}` by place |
| Today's plan | home's `todayPlanTapped` | its current step is in front (`matching step`, `flashcard step`, `speaking`); `continueTapped` passes a teach step; `say` reaches a read-aloud step, and `-scripted-speech` covers its steps in the app too |
| Settings | home's `opened {"destination":"settings"}` | strictness by the title the screen shows |
| Headword page | the dictionary's `opened {"result":0}`, a page's `characterOpened {"character":1}` | readings by place |
| Search results, word editor, HSK levels | the vocabulary tab and folders, in front while open | `back` closes a sheet or search before popping the stack |

To be pushed by an action, two pushes moved from the views into view-model state: the
dictionary tab's stack is `DictionarySearchState.path`, bound to its `NavigationStack`, and
home's settings is `HomeState.destination`, its toolbar `NavigationLink` now a `Button`.
Where an action carries a value nobody would type as JSON (a tile, an option's id, a
whole search result, a strictness), the driver takes a small action enum of its own and
picks it by name or place; the screen's own actions are unchanged.

In the app, a screen pushed over another that disappears, as settings over home or a page
over the dictionary's search, leaves nothing registered that can pop it. So each registered
screen also carries SwiftUI's own way out: remote `back` tries the app, then each screen's
own `back`, and only then the frontmost screen's `dismiss`, as its back button would. Its
`isPresented` is read when back runs: read as the screen appeared, it was still false.

A dictionary page opened from the word editor or the search results is a Dictionary screen,
which Library cannot see, so `DictionaryAccess` carries `pageDriver` beside its `page` view:
nil in the app, where the page's own view registers, and `DictionaryFactory.makeDriver` in
mando. The editor and the results put it in front while open, and `back` closes it before
anything else. The other way round, the word editor a dictionary reading opens is a Library
screen, so `DictionaryVocabulary` carries `editorDriver` beside its `editor` view; the
dictionary's search and pages put it in front while open, and `back` closes it before popping
a page. `AppComposer` builds both seams. Today's plan is busy while the teach card on show waits for its example
sentence (`MixedLessonState.examplesPending`), so `ls` shows the sentence once it has come;
only that card's, since the model takes seconds a sentence and the rest are looked up ahead.

## One composition

Every screen's input is built once, in `AppComposer` (the `AppComposition` package), and both
`ContentView` and mando's `Session` take theirs from it. Before, each built its own, and they
drifted: today's plan gained `speech` in its input and only mando's copy passed it, so the
app's read-aloud steps went on hearing the microphone under `-scripted-speech`. Inputs carry
both seams where a neighbour is another package's screen, a view for the app and a driver for
mando (`DictionaryAccess.page` and `pageDriver`). How screens are shown stays with each: the
app's tabs and full-screen cover, mando's stack. `AppComposerTests` pins scripted speech
reaching both lessons that listen; like mando's tests it is outside the Xcode scheme, so run
`swift test` in `AppComposition`.

## At a terminal

At a terminal, `mando` reads with libedit, which macOS ships (`CEditLine`, a system library
target): left and right move the cursor, up and down walk the history, and the history lasts
between runs in `~/.mando_history`, a command repeated running kept once. libedit blocks while
it waits for a line, so it reads on a thread of its own and waits for the reply to print
before the next prompt; the screens' work stays on the main actor. Piped input, as from a
script or an agent, keeps the plain reader and its echo. `LineEditingTests` runs
`Tests/line-editing.exp` through `/usr/bin/expect` in a pseudo-terminal, with a HOME of its
own so the real history is never touched: arrows, Chinese typed whole, Ctrl-D, and history
across two runs.

## Remote mode: the same commands, driving the simulator

`mando --remote` sends the same commands to the app running in the simulator, and its
screens update as they arrive. Shopify's video shows exactly this: `dev cli ios --remote`
beside a simulator that changes tab and opens a product as the commands go in.

**How.** The CLI never touches the UI: no taps, accessibility tree or screenshots. It
sends actions to the view models the live screens render, and the UI follows because
each screen renders its state. This is the MVI layering paying off.
`ScreenDriver` already wraps the real view model, so in the app it drives the screen
itself, not a copy.

**What it adds.** Headless `mando` stays the fast loop for agents. Remote mode is for
watching, and for bugs that only exist in the real composition: `ContentView`'s wiring,
the coordinator, sheets and covers, and the simulator's real store. It also replaces
pointing `ContentView` at a screen to screenshot it (Known gaps in CLAUDE.md): drive to
the screen by command, then screenshot.

1. **Partly done. Tabs and the coordinator become drivable.** `TabView` takes its
   selection from `AppNavigationCoordinator.selectedTab`, and headless `mando` has `tab`.
   The coordinator's driver, with `selectTab` and the presented lesson, waits for step 2's
   registry, since nothing in the app could call it before then. The library stack is already state
   (`LibraryState.path`), so a deck opened by command slides in for free.
2. **Done. Routes register their drivers.** `.drivable { viewModel.driver(navigation:) }`
   offers a driver to the `ScreenRegistry` in the environment as the Route appears and takes
   it back as it disappears. The registry is nil unless the app was launched with
   `-remote`, so feature packages need no `#if DEBUG`. The coordinator's driver is
   `registry.app`: `selectTab`. A lesson is closed by its own screen's `back`, which sends
   `closeTapped` as its ✕ does (see "Watching it drive"). Only `send`, `summary`,
   `dump`, `back` and `open` are used from a registered driver: the Route keeps following
   its effects, so the app navigates as if tapped.
3. **Done. A listener in the app.** `CoreRemote`: `RemoteServer` listens on
   127.0.0.1:9393, one `RemoteRequest` JSON line in and one `RemoteReply` line out;
   `RemoteControl` answers from the registry. The target is not main-actor by default,
   since Network calls back on its own queue, and the control hops to the main actor.
   Started in `MandoJiaoApp` under `#if DEBUG` and `-remote` only.
4. **Done. `MandoKit` gets a remote backend.** The interpreter runs against a `Backend`:
   the local `Session`, or `RemoteBackend` over the loopback. `open deck|folder` moved into
   the library's driver, `ScreenDriver.open`, so one lookup serves both.
5. **Done. A launch argument for scripted speech.** A debug build launched with
   `-scripted-speech` hears `ScriptedSpeech` (PracticeDI) in place of the microphone, and
   remote `say` queues on it through `ScreenRegistry.speak`, then taps the mic, as headless
   `say` does. It is separate from `-remote`, so remote mode can still use the real
   microphone; without it, `say` is refused with the `typedAnswerSubmitted` to send instead.
   `ScriptedRecogniser` moved from `PracticeTestSupport`, now gone, to `PracticeData`, so
   the app links no test support.

   Found by running it: the app's endpointing keeps the listen it opens after a right answer
   open for up to 5s, and an answer queued during it was taken unheard as that listen ended
   empty. An answer queued mid-listen now becomes its transcript, as speech into an open
   microphone would, and the listen settles on it. Headless mode never showed this, since its
   listens end at once. Today's plan's read-aloud steps hear the same scripted speech.

**Found by running it on the simulator, and fixed.**

- The registry's environment was set inside the full-screen cover's modifier, so a
  lesson's screens never registered. It is set outside the cover now.
- A screen leaves the registry only when its disappearance ends, after the pop or
  dismissal animation, and nothing on show changes meanwhile, so the settle ended early
  and `ls` listed screens already gone. Remote mode first waited a fixed 600ms after every
  command; see "Watching it drive" for what replaced it.
- On iPhone the library's split view shows its sidebar or its detail by the Route's own
  `compactColumn`, which only a sidebar tap moved. A selection made through the view model
  left the sidebar showing. The column now follows the selection, and the library's
  `back` deselects once its stack is empty, as back does on iPhone.

Checked on the iPhone 17 Pro simulator with a screenshot after each command: a tab
switched, a folder selected and a deck pushed, a speaking lesson presented and a typed
answer graded, then back through each, with `ls` matching the screen every time.

**Knowing what is driven.** The two modes answer alike, which is right for an agent and
misleading for a person: headless commands succeed with no simulator open, and remote ones
drive whichever app holds the port, perhaps on a simulator with no window. So mando's first
line says which: `headless: …`, or `remote: MandoJiao on iPhone 17 Pro Max (1DD26091)`, from
a `hello` the app answers with its simulator's name and id. The prompt is `mando remote>`
when remote. Only one app can hold 9393; a second launched with -remote now logs
`remote: cannot listen on 127.0.0.1:9393 …` in Xcode's console instead of failing silently.
Checked with two simulators launched with -remote.

**Rules.**

- Never shipped. Everything sits behind `#if DEBUG` and a launch argument, so it is off
  unless asked for. An open port in a release build is a security hole and an App Store
  rejection.
- Sounds and haptics are real in remote mode. That is fine for watching and says
  nothing about the logic.
- `✓` means state has settled, not that an animation has finished. A screenshot taken
  straight after a push can catch it mid-slide; wait before capturing.

## Handing a flow to an agent

```sh
Tools/test-flow "test a speaking lesson on Greetings: one right, one wrong, then close it"
Tools/test-flow "test the new feature we've been working on"
```

The script builds the app and mando, installs the app on the simulator DeviceHub shows
(see "Watching it drive"), and launches it with `-remote -scripted-speech` as launch
arguments, so the scheme is never ticked. It checks that mando's banner names that
simulator, then runs `claude -p` with the prompt. The agent follows the `drive-app` skill
(`.claude/skills/drive-app/SKILL.md`): it pipes a few commands into `mando --remote` at a
time, reads `ls`, decides, and goes on, since the state lives in the app between runs. It
ends with a report of each step, what it expected and what it saw.

`claude -p` prints nothing until the agent finishes, so the script reads its event stream
instead and prints each step as the agent takes it: `→` and the commands it sent mando, `·`
for anything else it does, a reading or a screenshot, and any `✗` that comes back. The report
follows. `--quiet` prints only the report.

```
→ help, tab vocabulary, open deck Greetings, ls
→ do startLessonTapped {"exercise":"speaking"}, ls, state
→ say xuesheng, ls, do continueTapped, ls, say pingguo, ls
→ do closeTapped, ls
· read .build/test-flow/shots/speaking-quit-confirm.png
→ do quitConfirmed, ls
```

The agent may read code and git history, run mando and take screenshots, and nothing else:
`--allowedTools` names those and `--disallowedTools` refuses edits. `--fresh` uninstalls
the app first, so a run starts from a new install, `--device <udid>` drives another simulator, `--no-build` reuses the
last build, and `--prepare` only launches the app, for an agent already running in a
session, which the skill tells it to use.

It refuses when another app holds 9393, such as one launched with -remote on the user's own
simulator.

`Tools/smoke-test` hands it a fixed prompt that visits every screen once, as shallow as
covers it: settings, today's plan, quick practice, a folder, a deck and its search, the
dictionary and a result's character, and a speaking and a flash-card lesson. It takes the
same options, so `Tools/smoke-test --no-build` reruns it against the installed app.

Lessons deal their cards in a random order, so an agent used to read each card and answer it
in the next run, a turn per card. `answer` and `answer wrong` answer whatever card is in front
as a learner would, and go on once the card is done, so a lesson goes in one run:

- speaking types the pinyin, or `zzz`; typed, so it needs no `-scripted-speech`
- flash cards pick the right option or another, or type the answer, or a wrong one
- matching taps a pair, or one pair's English and another's Hanzi
- today's plan goes on from a taught word, and its exercise steps answer as their lessons do

Each driver gives its own through `ScreenDriver.answer`, which reports what it gave and the
verdict. A matching board with one pair left has no wrong match and says so. Its wrong
match adds words to the mistakes list, and its quit lessons save what they answered.

Checked on a throwaway iPhone 18 Pro simulator, iOS 27, which was deleted afterwards:
`--prepare` reached the app in 44s from a cold build, and the prompt above ran from start to
finish. On its first try the agent found that a `continueTapped` sent while the lesson
was advancing on its own skipped a card unrecorded: `SpeakingLesson.advance()` has no
guard on the phase, where `FlashcardLesson.advance()` has one. Whether the app's view can
send that is unchecked.

## Watching it drive

The script drives the simulator DeviceHub shows, so a run can be watched as it happens.
DeviceHub has no way to be told which simulator to show: no launch argument, and its
`devices://` links did nothing visible for a simulator's id. So the script goes the other way
and drives the one shown, which DeviceHub stores as `lastSelectedDeviceIdentifier` in
`com.apple.dt.Devices`, keeping the app's data unless `--fresh`. With none stored it falls
back to a simulator of its own, "MandoJiao Agent". A MandoJiao on another simulator holding
the port is closed first; anything else holding it is refused. For that to look like driving rather than waiting, commands have to land at the
pace of the animations, and the agent has to send a flow at once rather than a step a turn:
the skill says to scout, then send the whole flow in one run.

Measured on the iPhone 18 Pro simulator, iOS 27, debug build:

| | Before | After |
| --- | --- | --- |
| A command that changes nothing, `tab home` on home | 0.88s | 0.28s |
| `ls` with a speaking lesson open | 1.8s | 0.16s |
| 17 commands: three tabs, a deck, settings, a lesson with an answer | about 16s | 9.8s |

- **No fixed wait.** Remote mode waited 600ms after every command, for a screen animating
  out to leave the registry. Now a reply waits until no screen is leaving and UIKit has
  shown no transition for 100ms, capped at 2s. Leaving runs from UIKit's
  `viewWillDisappear` to `viewDidDisappear`, through a view controller `.drivable` puts
  behind each screen; SwiftUI's `isPresented` was tried first and does not change until the
  screen has gone. The 100ms covers a transition that starts as another ends: a lesson's
  cover closes only once its quit dialog has, and with no quiet period `ls` still listed
  the lesson.
- **A cheap settle.** The settle compared every screen's `dump()` each 10ms, and a lesson's
  dump reflects all its cards, so a settle with a lesson open took over a second. It
  compares `fingerprint`, the state described in one line, instead.
- **`say` waits for its grade.** Endpointing ends a listen after the answer is heard, so a
  reply came back with the answer still ungraded. The speaking screen is busy while the
  microphone arms, or while it listens having heard something.
- **A screen keeps its place.** Back on the vocabulary tab, SwiftUI showed the pushed deck
  before the list, which registered after it and took the front, so commands went to the
  list. A screen now keeps the place it first registered in.
- **`open` on what is already in front does nothing.** Opening the deck on show pushed a
  second copy beneath it, which a `back` popped with nothing to see, and which never
  disappeared from the registry.

- **`back` taps a lesson's ✕.** It dismissed the lesson outright, skipping the "Quit this
  drill?" dialog, and with it the results recording that quitting does: an agent quit a
  lesson with a card answered and found nothing recorded and Continue unmoved. Each lesson's
  screen now answers `back` by sending `closeTapped`; a speaking step in today's plan has no
  ✕ of its own, so `back` passes it to the plan's. Headless mando does the same.

Found by an agent's tour and not fixed: a `continueTapped` sent while a speaking lesson
advances on its own after a right answer skips the next card, since
`SpeakingLesson.advance()` has no guard on the phase. A person tapping Continue just as it
advances could do the same; that is the app's to decide.

## Unchecked

- Whether a copy of the simulator's store opens on the Mac: mando has no `--store` flag yet.

Answered: every package's DI target builds for macOS, since mando links them all. mando keeps
its settings in the `mando` defaults domain (`~/Library/Preferences/mando.plist`), apart from
the app's; `defaults read mando` shows them.
