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

- Drivers for the remaining screens. The tabs are done, below.
- One composition shared by the app and the CLI. The duplicated composition root is the
  spike's known cost; the `Application` module [modularisation.md](modularisation.md)
  sketches is the fix.
- A line in [feature-checklist.md](feature-checklist.md): a new screen ships a driver.
- Remote mode, below.

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

Not driven yet: home's settings, the dictionary's headword pages, the library's search
results, word editor and HSK levels, and matching, flash cards and today's plan. A pushed
screen's leftover errors are relayed to its tab, and print as notes.

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
   `registry.app`: `selectTab`, and `back` dismisses the lesson. Only `send`, `summary`,
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
5. **Deferred. A launch argument for scripted speech.** `say` is refused in remote mode
   with the `typedAnswerSubmitted` to send instead, which is graded the same way. The app's speaking lesson uses
   `DictationRecogniser`, and recognition on the simulator is not to be judged. Under
   the argument, the speaking factory builds with `ScriptedRecogniser` and `say` feeds
   it. The card reacts in the simulator, which proves the flow and nothing about
   recognition.

**Found by running it on the simulator, and fixed.**

- The registry's environment was set inside the full-screen cover's modifier, so a
  lesson's screens never registered. It is set outside the cover now.
- A screen leaves the registry only when its disappearance ends, after the pop or
  dismissal animation, and nothing on show changes meanwhile, so the settle ended early
  and `ls` listed screens already gone. After a command that changes anything, remote
  mode waits 600ms for the transition, then settles again.
- On iPhone the library's split view shows its sidebar or its detail by the Route's own
  `compactColumn`, which only a sidebar tap moved. A selection made through the view model
  left the sidebar showing. The column now follows the selection, and the library's
  `back` deselects once its stack is empty, as back does on iPhone.

Checked on the iPhone 17 Pro simulator with a screenshot after each command: a tab
switched, a folder selected and a deck pushed, a speaking lesson presented and a typed
answer graded, then back through each, with `ls` matching the screen every time.

**Rules.**

- Never shipped. Everything sits behind `#if DEBUG` and a launch argument, so it is off
  unless asked for. An open port in a release build is a security hole and an App Store
  rejection.
- Sounds and haptics are real in remote mode. That is fine for watching and says
  nothing about the logic.
- `✓` means state has settled, not that an animation has finished. A screenshot taken
  straight after a push can catch it mid-slide; wait before capturing.

## Unchecked

- Whether a copy of the simulator's store opens on the Mac.
- Whether the other packages' DI targets build for macOS.
- Which `UserDefaults` domain the CLI's settings land in.
