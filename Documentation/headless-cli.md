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
5. **Speaking seams, what is left.** `PracticeTestSupport` becomes a product, and the
   recogniser takes `enqueue` for `say`. `ScriptedRecogniser` will not do as it is: it
   puts the transcript in `partialText` only on `stop`, and consumes one on every `stop`.
   So the automatic listen after a right answer hears nothing, stops without submitting,
   and still eats the next card's answer (read from the code, not yet run). The `say`
   recogniser shows the queued answer from `start` and consumes it only when it has one.
6. **`Tools/MandoCLI`, building `mando`.** A second composition root: the store from
   `openStore(inMemory:)` (a `--store` flag needs `openStore` to take a URL), a small
   coordinator for the tab and the presented lesson, and the commands `tab`, `do`, `open`,
   `say`, `ls`, `state` and `back`. Stdin is read asynchronously, since a blocking
   `readLine` starves the view models' main-actor tasks, and each command waits for the
   main actor to settle before printing `✓`.
7. **Tests that stop the tool rotting.** A golden test running a script through `mando`,
   and one per screen that every listed action name decodes.

## After the spike

- Drivers for the remaining screens.
- One composition shared by the app and the CLI. The duplicated composition root is the
  spike's known cost; the `Application` module [modularisation.md](modularisation.md)
  sketches is the fix.
- A line in [feature-checklist.md](feature-checklist.md): a new screen ships a driver.
- Perhaps a remote mode: a debug-only socket in the app taking the same commands, so they
  drive the simulator too.

## Unchecked

- Whether `LessonExercise` decodes cleanly.
- Whether a copy of the simulator's store opens on the Mac.
- Whether the other packages' DI targets build for macOS.
- Which `UserDefaults` domain the CLI's settings land in.
