# CLAUDE.md

Context for working on MandoJiao, a SwiftUI Mandarin vocabulary app. Read
`README.md` first for what it does; this file is for how to work on it without
repeating mistakes already made.

## Read before changing anything

- `Documentation/exercises.md`: how the exercises and the mistakes list work today, and
  the value-type boundary that keeps exercise logic testable
- `Documentation/grading.md`: every rule in `AnswerGrader` and the cost of each
- `Documentation/speech.md`: the recognition pipeline and the audio session
- `Documentation/working-on-this.md`: build traps and verification

## Architecture

MVI + Clean Architecture in SPM packages, with a domain layer shaped for possible KMP
sharing. One package per business area: `Core/`, `Library/`, `Dictionary/`, `Practice/`,
`Progress/` and `Settings/` are SPM packages at the repo root, and `Library` is the
reference vertical. A new exercise is a folder in `Practice`, never a new package; a view
two packages show goes in `CoreUI`, never imported from a peer's UI. The app target
holds only the entry point and the composition root. See
`Documentation/modularisation-migration.md` for the state and what is left.

- `Documentation/architecture.md`: the layers, UDF, and the reasoning behind each decision
- `Documentation/modularisation.md`: packages, targets, dependency rules, navigation, naming
- `Documentation/modularisation-migration.md`: where each file goes, sequencing, known costs
- `Documentation/feature-checklist.md`: the per-change conformance list
- `Documentation/code-comments.md`: when a comment is warranted, and how long

Packages: `Core` (`CoreDomain`, `CorePersistence`, `CoreSound`, `CoreDesignSystem`,
`CoreUI`, `CoreDI`, `CoreTestSupport`), `Library`, `Dictionary`, `Practice`, `Progress` and `Settings`, each with up to four targets: `{X}Domain`, `{X}Data`, `{X}UI`, `{X}DI`.
The rules most easily broken:

- A feature package may depend only on another package's `Domain` product.
- `{X}UI` must never import `{X}Data`; wiring goes in `{X}DI`.
- `{X}Domain` must not import SwiftUI, UIKit, SwiftData, Speech, AVFoundation or OSLog.
- Domain and UI targets must build for macOS. A view model imports `Observation`, not
  `SwiftUI`, and reaches the recogniser, sounds and audio session only through
  injected seams. Only a factory names `ToneEngine.shared`.
- Views never touch `ModelContext` or `@Query`; the store is behind a repository.
- A screen takes a `{Screen}Navigation` value. Its closures name what happened, not
  where to go, and are never defaulted to `{ }`.
- Never two top-level public types with the same name in co-importable modules.
- Never create a `Shared/`, `Common/` or `Util/` folder.

Before finishing work in a migrated vertical, check the diff against
`Documentation/feature-checklist.md`. The items nothing else catches: every view model `catch`
handles `CancellationError` first and ignores it, catches untyped rather than typed to
the domain error, and calls `log()` on the display error before yielding the effect.

New feature code goes in a package, never the app target.

The settled decisions below are product rules and survive the migration unchanged.
Moving code must not move a pinned cost out of the test suite.

## Build and test

```sh
# Everything, on the simulator: all six packages' tests.
xcodebuild build -scheme MandoJiao -destination 'platform=iOS Simulator,id=<udid>'
xcodebuild test  -scheme MandoJiao -destination 'platform=iOS Simulator,id=<udid>'

# One package, headless on the Mac, in seconds.
cd Practice && swift test
cd Practice && swift test --filter StrictnessTests
```

Get `<udid>` from `xcrun simctl list devices available`. Xcode 27 did not resolve
`name=iPhone 17 Pro` here.

**Run `xcodebuild clean` before `test` whenever a test file changed, and check
the test count moved.** The incremental build silently skips recompiling changed
test files and reports a pass for tests that never ran. This has happened three
times; once it reported `TEST SUCCEEDED` while eight new tests were skipped. A
green result on its own is not evidence that anything ran.

`xcodebuild test` prints one `Test run with` line per test bundle, six in all.
Add them up. Current suite: 475 tests in 55 suites: 13 in `Core`, 175 in `Library`,
75 in `Dictionary`, 188 in `Practice`, 19 in `Progress`, 5 in `Settings`. The app target has no tests of
its own. If a bundle's line is missing, it did not run.

```sh
xcodebuild test -scheme MandoJiao -destination '...' | tee test.log
grep "Test run with" test.log | sed -E 's/.*with ([0-9]+) tests? in ([0-9]+) suites?.*/\1 \2/' \
  | awk '{t+=$1; s+=$2; n++} END {print n, "bundles,", t, "tests in", s, "suites"}'
```

Mind the singular: a bundle with one suite prints `1 suite`, and a pattern that only
matches `suites` silently drops that bundle from the sum.

## Decisions already settled

Do not relitigate these without asking. Each was decided deliberately, most after
looking at real data, and several have tests pinning the consequence.

- **Tones are never graded**, at any strictness. Not a setting, not an oversight.
  A recogniser's tone output is its own guess as much as the speaker's.
- **Homophones pass.** Inherent to grading audio. Pinned by a test.
- **A word inside a longer phrase counts at every level,** including Strict. The
  recogniser pads single words into phrases; the speaker never said `了`.
- **Mistakes are practised by speaking, not matching.** The speaking lesson exists because the matching
  board needed five pairs and padded short mistakes lists with unrelated words.
- **Four strictness levels**, Relaxed by default. Raw values are storage, titles
  are display; rename titles freely, never raw values.
- **The speaking lesson plays no per-card tones.** Two attempts to make them audible under
  `.measurement` failed. Haptics carry the feedback. Do not reintroduce them by
  weakening the audio session — recognition accuracy outranks tone volume, which
  was an explicit call by the owner. Pinned by a test.
- **`DictationTranscriber`, never `SpeechTranscriber`.** The latter silently
  ignores contextual hints.

## How to work here

**Measure, do not estimate.** The domain types run headlessly with `swift test` in
their package, so a reported transcript can be replayed through all four levels in
seconds by adding a case to `StrictnessTests`. Two
claims in this project's history were wrong when checked: `往昌` was predicted to
pass at Relaxed and does not, and gain compensation was tried twice before
noticing the clipping ceiling made it impossible. Run it before saying it.

**Say what was actually verified.** The simulator cannot judge speech
recognition, device-only runtime warnings, or audio levels. Claiming otherwise is
worse than saying a thing is untested. When a fix cannot be verified here, say so
and say why.

**Record costs as tests.** When a rule makes two real words indistinguishable,
assert it. `是`/`社`, `想`/`兄`, `老师` carrying `是` are all pinned. A comment is
not enough; if the behaviour reverses, a test should say so.

**Commit messages carry the reasoning**, including what was tried and failed.
`git log` is the design record for grading.

## Traps specific to this project

- **Protocols and extensions take the default isolation too.** Domain and data
  protocols are `nonisolated protocol`, and extensions on nonisolated types need
  `nonisolated extension`. Details in `Documentation/working-on-this.md`.
- **Until the first release, the store has one schema and no migration plan.** The app
  is not live, so a schema change edits `VocabularySchemaV1`. With no plan, SwiftData
  infers the change where it can: the fold to one schema, which dropped an attribute and
  added an entity, opened the earlier build's store on the simulator. Where it cannot,
  the store fails to open and the app traps at launch, and the fix is to reinstall; say
  when a change might need that. Before release, versioning comes back: from then on
  never change a built version, add one, and test each migration against a real store
  fixture written by the build before it.
- **A callback closure inside a main-actor type is main-actor, checked at runtime.**
  Everything builds as Swift 6, which traps if a framework calls such a closure on
  another thread. Audio taps and similar callbacks must be `@Sendable` and capture
  copies. The compiler does not catch it, and the simulator cannot reach the audio path.
- **A test that blocks the main actor breaks the timing tests.** Heavy synchronous
  work goes in a `nonisolated` suite.
- **Never name a target after an Apple framework.** `CoreAudio`, `Speech`,
  `SwiftData` and `CoreData` all collide. The sound target is `CoreSound` because
  `CoreAudio` failed with a module cycle through AVFoundation.
- **Adding a resource to a package's manifest needs a clean app build.** The incremental
  Xcode build kept the old manifest and shipped `VocabularyData`'s bundle without the new
  `HSK.tsv`, so the app reported the list unreadable while `swift test` passed. Check the
  built app's `Dictionary_DictionaryData.bundle`, where the `.tsv` files now live, when a
  resource is new or moves.
- **A local package's test target needs a file reference in the project.** Without
  one the scheme lists it and xcodebuild skips it silently, reporting a pass for the
  app's tests alone.
- **Moving a type into a package makes it internal.** Every type, member and init
  used from another target needs `public`, including `public private(set)`, and a
  struct's memberwise init is never public, so it needs an explicit one.
- **Default arguments are evaluated in the caller's context.** With
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, any `static let` used as a default
  must be `nonisolated`. Caught four separate times.
- **Files are picked up from disk,** in the app target (`PBXFileSystemSynchronizedRootGroup`)
  and in the packages alike. New files need no project edit, which is also why
  incremental builds miss changes.
- **The shared scheme's `TestAction` must not contain an empty `<TestPlans>`**, or
  xcodebuild reports the scheme as not configured for testing.
- **Never give `.searchable` a `Binding(get:set:)` into a view model.** SwiftUI's copy
  goes stale, and clearing a field not being edited put the old query back. Use
  `searchField(initial:prompt:onChange:)` from `CoreUI`. Found on a device, not by a test.
- **`Logger` redacts interpolated strings** unless marked `privacy: .public`, and
  `.debug` level is unreliable in Xcode's console. `SpeechLog` uses `.notice`.
- **The light app icon must have no alpha channel.** App Store validation rejects
  a primary icon with transparency.

## Known gaps

- Speech recognition quality is only assessable on a device. The owner tests
  there and reports console logs; `SpeechLog` output is the primary evidence.
- `Endpointing`'s 700ms settle window is judged, not measured.
- No UI tests. Screens are checked by pointing `ContentView` at them temporarily
  and screenshotting the simulator, then reverting.
