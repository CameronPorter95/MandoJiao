# Modularisation: migration state

Where the migration has got to, the order things move in, and what is known to be
untidy. The standing rules are in [modularisation.md](modularisation.md); this document
is the part that changes.

---

## Status

**Step 1 is done: the drill is on MVI, still in folders.** The app is a single target
with folders (`Views/`, `Game/`, `Speech/`, `Audio/`, `Models/`, and now `Drill/`),
and 114 tests in 10 suites. Work happens on `refactor/mvi`.

The drill now looks like this:

| File | Layer | Role |
| --- | --- | --- |
| `Game/DrillLesson.swift` | domain | The card state machine as a value: attempts, verdicts, tallies. No timers. |
| `Drill/DrillState.swift`, `DrillAction.swift`, `DrillEffect.swift` | UI | State (with `MicState`), intents, and the `.haptic` / `.close` effects. |
| `Drill/DrillViewModel.swift` | UI | Microphone rules, auto-advance, the audio session hand-off, recording results. Imports `Observation`, not `SwiftUI`. |
| `Drill/DrillRoute.swift`, `DrillScreen.swift`, `SpeakCardView.swift` | UI | Route owns the view model and performs effects; Screen and card are stateless. |
| `Drill/DrillNavigation.swift` | UI | `didClose`, no default. |
| `Drill/DrillFactory.swift` | wiring | The only place naming `DictationRecogniser` and `ToneEngine` for the drill. |
| `Audio/AudioSessionSwitching.swift` | seam | Recording mode on and off, implemented by `ToneEngine`. |

`SpeakSession` and `SpeakLessonView` are gone. `SpeechRecognising` now requires
`Observable`, because the view model mirrors the recogniser's live values into state
through observation tracking.

What already matches the target shape, and why the migration is smaller than the
document count suggests:

- **The domain/data boundary exists.** Lessons are built from `WordPair`, never from
  `VocabWord`. That is the domain model / entity split under another name.
- **Most domain rules are already Foundation-only.** `AnswerGrader`, `MatchStrictness`,
  `Endpointing`, `LessonBuilder`, `SpeakLessonBuilder`, `MatchBoard` and the plan types
  import nothing platform-specific, and compile standalone with `swiftc`.
- **Two seams exist.** `SpeechRecognising` (with `ScriptedRecogniser` as its fake) and
  `MatchSoundPlaying` (with `SilentSounds`).
- **`LessonSession` is nearly a view model.** An `@Observable` driver taking values
  in and exposing state, with no SwiftData.

What does not match:

- **Views own the store.** `HomeView`, `WordLibraryView`, `DeckDetailView` and
  `WordEditorView` use `@Query` and `modelContext` directly.
- **One global left in use.** `LessonView` reaches `ToneEngine.shared` and
  `LessonSession` defaults to `MatchSounds.shared`. The drill reaches neither.
- **Settings are read with `@AppStorage` in `LessonView`.** The drill reads them once,
  in `DrillFactory`, through `Preferences`.
- **Results are written with a closure over a `ModelContext`.** `DrillFactory` wraps
  `MistakeLog.apply` until step 2 puts a repository there.

---

## Where each file goes

| Today | Target | Notes |
| --- | --- | --- |
| `Models/WordPair.swift` | `VocabularyDomain` | Unchanged apart from `public`. |
| `LessonRequest` (in `Views/LessonView.swift`) | `VocabularyDomain` | Its `canStart` references `LessonBuilder.pairsPerExercise`, a Matching rule. Move the check to Matching. |
| `Models/VocabWord.swift`, `Models/Deck.swift` | `VocabularyData` | `Deck.canStartLesson` has the same Matching dependency. |
| `Models/MistakeLog.swift` | `VocabularyDomain` (the arithmetic) + `VocabularyData` (the write) | Becomes `RecordLessonResultsUseCase` and `ClearMistakesUseCase`. |
| `Models/SampleVocabulary.swift` | `VocabularyData` | Seeding stays a data concern, triggered once at launch. |
| `Models/Preferences.swift` | split: `DrillDomain` / `MatchingDomain` settings, storage in each `Data` | Keys and raw values unchanged. |
| `Models/PreviewData.swift` | `VocabularyTestSupport` or preview fixtures | |
| `Game/LessonPlan.swift`, `Game/MatchBoard.swift` | `MatchingDomain` | |
| `Game/LessonSession.swift` | `MatchingUI` as `MatchingViewModel` | |
| `Game/SpeakPlan.swift` | `DrillDomain` | |
| `Game/DrillLesson.swift` | `DrillDomain` | Done in folders (was `SpeakSession`). |
| `Drill/*` | `DrillUI`, except `DrillFactory` → `DrillDI` | Done in folders. |
| `Speech/AnswerGrader.swift`, `MatchStrictness.swift`, `Endpointing.swift` | `DrillDomain` | |
| `Speech/SpeechRecognising.swift` | `DrillDomain` (protocol, `SpeechOutcome`, `SpeechAvailability`) + `DrillTestSupport` (`ScriptedRecogniser`) | |
| `Speech/DictationRecogniser.swift` | `DrillData` | |
| `Speech/SpeechLog.swift` | `DrillData`, reached through a seam | |
| `Audio/MatchSounds.swift`, `Audio/AudioSessionSwitching.swift` | `CoreDomain` | The `shared` global is deleted once matching migrates. |
| `Audio/ToneEngine.swift` | `CoreAudio` | Also implements `AudioSessionSwitching`. |
| `Theme.swift`, `Views/LessonProgressBar.swift` | `CoreDesignSystem` | |
| `Views/LessonCompleteView.swift` | `CoreUI` | Two consumers. |
| `Views/HomeView.swift` | `VocabularyUI` as Home Route/Screen/ViewModel | |
| `Views/WordLibraryView.swift`, `WordEditorView.swift`, `DeckDetailView.swift`, `WordRow.swift` | `VocabularyUI` | |
| `Views/LessonView.swift`, `MatchBoardView.swift`, `WordTileView.swift` | `MatchingUI` | |
| `Views/SettingsView.swift` | `SettingsUI` | |
| `MandoJiaoApp.swift`, `ContentView.swift` | `Application` | Builds the `ModelContainer` from each package's schema, registers seams. |

---

## Sequencing

Layer in folders first, then extract the verticals that are layered, so the compiler
starts enforcing the boundaries while most of the app is still unmigrated. Each
extraction is then a move plus access control, never a redesign at the same time.

1. **Done. The drill, without packages.** Introduce `DrillViewModel` with
   State/Action/Effect, move the microphone rules out of `SpeakLessonView` into it,
   and split the view into Route and Screen. Inject the recogniser, sounds and audio
   session. This is the move with the best return: the untested rules become tests
   driven by a fake recogniser, and nothing about storage changes. It proves the
   pattern in folders before paying for packages.

2. **Repositories, still in folders.** This is where the domain and data layers first
   exist as layers rather than as habits.
   - **Vocabulary.** Put `WordRepository` in front of SwiftData behind a `@ModelActor`
     local source, replace `MistakeLog` with `RecordLessonResultsUseCase` and
     `ClearMistakesUseCase`, and move the four store-owning views onto view models.
     This is where `@Query` goes, and where the cost of
     [decision 7](architecture.md#7-observing-the-store-without-query) is paid.
   - **Drill.** `DrillFactory` hands `DrillViewModel` the results use case instead of
     the `MistakeLog` closure. Strictness and the card limit move behind a
     `DrillSettingsRepository` in the drill's domain, backed by `UserDefaults` in its
     data layer, reading the existing `Preferences.Key` strings and raw values.
   - **Folders mirror the targets to come.** `Vocabulary/` and `Drill/` each get
     `Domain/`, `Data/`, `UI/` and `DI/` subfolders, so step 3 moves folders into
     targets rather than sorting files.
   - **Version the schema.** Add a `VersionedSchema` for the current `VocabWord` and
     `Deck` shape before step 3 moves them. Cheap insurance for the upgrade check
     there.

3. **Extract `Core`, `Vocabulary` and `Drill`.** The first SPM packages, together
   because `Drill` depends on `VocabularyDomain` for `WordPair`, `LessonRequest` and
   the results use case. `DictationRecogniser` and `SpeechLog` land in `DrillData`,
   `ToneEngine` in `CoreAudio`, `LessonCompleteView` in `CoreUI`, and the
   `ModelContainer` is built in the app from the packages' schemas. Each package lists
   `.macOS(.v26)`, and the domain and view model tests run headlessly from here on.
   The app target keeps `Matching` and `Settings`, which import only the new packages'
   `Domain` and `DI` products. **Gate:** the store upgrade check in
   [What will cost time](#what-will-cost-time) passes on a device before this ships.

4. **Matching, layered and extracted in one go.** The pattern is proven and the
   package plumbing exists, so there is no reason to stop in folders.
   `LessonSession` becomes a view model, results go through the Vocabulary use case,
   rounds and pinyin visibility get a `MatchingSettingsRepository`, and `LessonView`
   stops reaching `ToneEngine.shared`. `MatchSounds.shared` is deleted.

5. **Settings.** The screen moves to a `Settings` package editing drill and matching
   settings through their domains. What remains in the app target is the entry point,
   `ContentView` and `AppNavigation`.

Each step leaves the app shippable and the suite green, so the order can pause at any
point without leaving half a pattern in place. Moving tests into package targets
changes where the count comes from: after every step, clean, run, and check the count
against the previous step.

---

## What will cost time

**Implicit `internal`.** Nothing about the layering resists a split; the build failures
come from types that were implicitly internal because all their callers were in one
module.

- **Synthesised memberwise inits are internal.** `WordPair` has an explicit init, but
  several plan and state types do not, and silently lose their initialiser on moving.
- **A witness to a public protocol requirement must itself be public.**
- **Access errors do not always look like access errors.** An internal `async` method
  can make the compiler fall back to a global function of the same name and report a
  type error instead.

**Concurrency settings change.** The app target builds as Swift 5 with
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. A package on tools version 6 defaults to
the Swift 6 language mode and nonisolated types. Domain types moving to nonisolated is
the intent, but expect every `@MainActor` assumption in them to surface as an error,
and set the language mode per target deliberately rather than inheriting it.

**The SwiftData store has live user data and no versioned schema.** The container is
built as `ModelContainer(for: VocabWord.self, Deck.self)` with no `VersionedSchema`.
Whether moving the `@Model` classes into another module changes how SwiftData
identifies them in an existing store is **not verified**. Before step 3 ships, install
the current App Store build, add words and mistakes, upgrade to the packaged build on
the same device, and check nothing is lost. Step 2 adds a `VersionedSchema` for the
current shape first, so there is a defined schema to migrate from if the check fails.

**`@testable import MandoJiao` stops being enough.** Tests move with their code, into
package test targets. The app scheme must include each package test target, and the
count has to be checked after every move.

**Previews need a factory.** Screens become previewable from state alone, which is
easier, but any preview that currently relies on `PreviewData.container` needs a fake
repository instead.

---

## Known untidiness

**Failed saves are silently dropped.** `MistakeLog.apply` and `clearAll` use
`try? context.save()`, and `MistakeLog.apply` returns early if the fetch fails. A lost
mistakes update is invisible. Step 2 gives these a classification and a log line.

**`MistakeLog.apply` fetches every word to update a few.** Fine at 65 words, and a
predicate on `uuid` in the local source fixes it when it matters.

**`LessonRequest.canStart` and `Deck.canStartLesson` reach into Matching.** Both use
`LessonBuilder.pairsPerExercise`. The five-word floor is a matching rule, so the check
belongs in Matching, and the drill has no floor at all.

**The audio session switch now lives in `DrillViewModel`,** through
`AudioSessionSwitching`, rather than in the recogniser implementation. It stays there
until there is a reason to move it. The rule in CLAUDE.md holds either way: recognition
accuracy outranks tone volume, and the session is not weakened to make tones audible.

**The drill's live transcript is mirrored, not read directly.** The screen used to read
`recogniser.partialText` itself. It now reads `DrillState.partialText`, which the view
model copies across on each observed change, one main-actor hop later. Whether that
hop is visible while speaking has not been checked on a device.

**No enforcement exists yet.** No SwiftLint, no CI. Review against
[feature-checklist.md](feature-checklist.md) is the only check until packages make the
compiler do part of it.
