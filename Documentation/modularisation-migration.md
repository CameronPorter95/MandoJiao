# Modularisation: migration state

Where the migration has got to, the order things move in, and what is known to be
untidy. The standing rules are in [modularisation.md](modularisation.md); this document
is the part that changes.

---

## Status

**All five steps are done.** Every feature is an SPM package at the repo root, and the
app target is the composition root only: `MandoJiaoApp`, `ContentView` and
`LiveDependencies`. 190 tests in 23 suites: 8 in `Core`, 49 in `Vocabulary`, 92 in
`Speaking`, 37 in `Matching`, 4 in `Settings`, all runnable headlessly with
`swift test` as well as through the scheme. Work happens on `refactor/mvi`.

```
Core/        CoreDomain  CorePersistence  CoreDesignSystem  CoreUI  CoreSound  CoreDI  CoreTestSupport
Vocabulary/  VocabularyDomain  VocabularyData  VocabularyUI  VocabularyDI  VocabularyTestSupport
Speaking/    SpeakingDomain  SpeakingData  SpeakingUI  SpeakingDI  SpeakingTestSupport
Matching/    MatchingDomain  MatchingData  MatchingUI  MatchingDI
Settings/    SettingsUI  SettingsDI
MandoJiao/   the app: MandoJiaoApp, ContentView, LiveDependencies
```

Every package lists `.iOS(.v26)` and `.macOS(.v26)` and builds as Swift 5 language
mode, matching the app. Domain and data targets are nonisolated by default; UI, DI and
test targets set `.defaultIsolation(MainActor.self)`.

**Step 5, Settings.** The screen has no domain or data of its own: every setting it
edits is owned by the lesson that reads it. The speaking and matching settings
repositories gained setters, each behind a use case that clamps to the setting's range
(the ranges moved from `Preferences` into `SpeakingSettings` and `MatchingSettings`).
`SettingsUI` cannot reach `SpeakingData` or `MatchingData`, so `SpeakingSettingsFactory`
and `MatchingSettingsFactory` in each owner's DI hand out the use cases, and the app
passes them in through `SettingsInput`. Tests pin that the repositories read and write
exactly the keys and raw values the old `@AppStorage` properties used.

The quick practice card now shows the rounds setting rather than the default: home asks
for it through an injected closure every time it appears, so a change in settings shows
on return.

**The store gate passed on the simulator in steps 2 and 3.** A real store written
before versioning migrates under the packaged build with every record intact. **Not
checked on a device**, and that is the last check before this branch ships.

What does not match the architecture yet:

- **`ContentView` still decides the presentation** of lessons itself, and builds each
  navigation value inline. `AppNavigation` and per-flow constructors in each `{X}DI`
  (N4) would replace that.
- **The packages build as Swift 5.** Moving to Swift 6 language mode is its own change,
  best done one target at a time starting with the domains.

---

## Sequencing

Layer in folders first, then extract the verticals that are layered, so the compiler
starts enforcing the boundaries while most of the app is still unmigrated. Each
extraction is then a move plus access control, never a redesign at the same time.

1. **Done. The speaking lesson, without packages.** Introduce `SpeakingViewModel` with
   State/Action/Effect, move the microphone rules out of `SpeakLessonView` into it,
   and split the view into Route and Screen. Inject the recogniser, sounds and audio
   session. This is the move with the best return: the untested rules become tests
   driven by a fake recogniser, and nothing about storage changes. It proves the
   pattern in folders before paying for packages.

2. **Done. Repositories, still in folders.** This is where the domain and data layers first
   exist as layers rather than as habits.
   - **Vocabulary.** Put `VocabularyRepository` in front of SwiftData behind a `@ModelActor`
     local source, replace `MistakeLog` with `RecordLessonResultsUseCase` and
     `ClearMistakesUseCase`, and move the four store-owning views onto view models.
     This is where `@Query` goes, and where the cost of
     [decision 7](architecture.md#7-observing-the-store-without-query) is paid.
   - **Speaking.** `SpeakingFactory` hands `SpeakingViewModel` the results use case instead of
     the `MistakeLog` closure. Strictness and the card limit move behind a
     `SpeakingSettingsRepository` in the speaking lesson's domain, backed by `UserDefaults` in its
     data layer, reading the existing `Preferences.Key` strings and raw values.
   - **Folders mirror the targets to come.** `Vocabulary/` and `Speaking/` each get
     `Domain/`, `Data/`, `UI/` and `DI/` subfolders, so step 3 moves folders into
     targets rather than sorting files.
   - **Version the schema.** Add a `VersionedSchema` for the current `VocabWord` and
     `Deck` shape before step 3 moves them. Cheap insurance for the upgrade check
     there.

3. **Done. Extract `Core`, `Vocabulary` and `Speaking`.** The first SPM packages, together
   because `Speaking` depends on `VocabularyDomain` for `WordPair`, `LessonRequest` and
   the results use case. `DictationRecogniser` and `SpeechLog` land in `SpeakingData`,
   `ToneEngine` in `CoreSound`, `LessonCompleteView` in `CoreUI`, and the
   `ModelContainer` is built in the app from the packages' schemas. Each package lists
   `.macOS(.v26)`, and the domain and view model tests run headlessly from here on.
   The app target keeps `Matching` and `Settings`, which import only the new packages'
   `Domain` and `DI` products. **Gate:** the store upgrade check in
   [What will cost time](#what-will-cost-time) passes on a device before this ships.

4. **Done. Matching, layered and extracted in one go.** The pattern is proven and the
   package plumbing exists, so there is no reason to stop in folders.
   `MatchingLesson` becomes a view model, results go through the Vocabulary use case,
   rounds and pinyin visibility get a `MatchingSettingsRepository`, and `MatchingLessonView`
   stops reaching `ToneEngine.shared`. `MatchSounds.shared` is deleted.

5. **Done. Settings.** The screen moves to a `Settings` package editing speaking and matching
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
and set the language mode per target deliberately rather than inheriting it. Step 3
chose Swift 5 mode for every package to match the app; moving to Swift 6 is its own
change, best done one target at a time starting with the domains.

**The SwiftData store has live user data.** It was unversioned until step 2 and is now
`VocabularySchemaV1` and `V2`. Moving the `@Model` classes into a package did not
change how SwiftData identifies them, on the simulator. Before this branch ships:
install the current App Store build on a device, add words and mistakes, upgrade to
this build, and check nothing is lost. That device run is the one check still owed.

**`@testable import MandoJiao` stops being enough.** Tests move with their code, into
package test targets. The app scheme must include each package test target, and the
count has to be checked after every move.

**Previews need a factory.** Screens become previewable from state alone, which is
easier, but any preview that currently relies on `PreviewData.container` needs a fake
repository instead.

---

## Known untidiness

**`recordResults` still visits every word.** Fine at 65 words. A predicate on the ids
in the results fixes it when it matters.

**A failed read leaves screens on their last snapshot.** `vocabulary()` is an
`AsyncStream`, which cannot carry an error, so a read failure after a write is not
shown. The write itself did succeed. Worth revisiting if reads ever fail in practice.

**Vocabulary is handed Matching's numbers.** The five-word floor and the round count
reach Home and deck detail as plain integers from `MandoJiaoApp`, so `Vocabulary`
never imports Matching and step 4 cannot create a package cycle.

**The audio session switch now lives in `SpeakingViewModel`,** through
`AudioSessionSwitching`, rather than in the recogniser implementation. It stays there
until there is a reason to move it. The rule in CLAUDE.md holds either way: recognition
accuracy outranks tone volume, and the session is not weakened to make tones audible.

**The speaking lesson's live transcript is mirrored, not read directly.** The screen used to read
`recogniser.partialText` itself. It now reads `SpeakingState.partialText`, which the view
model copies across on each observed change, one main-actor hop later. Whether that
hop is visible while speaking has not been checked on a device.

**No enforcement exists yet.** No SwiftLint, no CI. Review against
[feature-checklist.md](feature-checklist.md) is the only check until packages make the
compiler do part of it.
