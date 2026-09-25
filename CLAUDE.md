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

## Architecture (target)

The app is moving to MVI + Clean Architecture in SPM packages, with a domain layer
shaped for possible KMP sharing. `MandoJiao/Drill/` and `MandoJiao/Vocabulary/` are
layered (`Domain/`, `Data/`, `UI/`, `DI/`) and are the reference; Vocabulary shows the
repository and the store. See `Documentation/modularisation-migration.md` for the
state and the order.

- `Documentation/architecture.md`: the layers, UDF, and the reasoning behind each decision
- `Documentation/modularisation.md`: packages, targets, dependency rules, navigation, naming
- `Documentation/modularisation-migration.md`: where each file goes, sequencing, known costs
- `Documentation/feature-checklist.md`: the per-change conformance list
- `Documentation/code-comments.md`: when a comment is warranted, and how long

Target packages: `Core` (`CoreDomain`, `CorePersistence`, `CoreAudio`,
`CoreDesignSystem`, `CoreUI`), then `Vocabulary`, `Matching`, `Drill`, `Settings`,
each with up to four targets: `{X}Domain`, `{X}Data`, `{X}UI`, `{X}DI`. The rules most
easily broken:

- A feature package may depend only on another package's `Domain` product.
- `{X}UI` must never import `{X}Data`; wiring goes in `{X}DI`.
- `{X}Domain` must not import SwiftUI, UIKit, SwiftData, Speech, AVFoundation or OSLog.
- Domain and UI targets must build for macOS. A view model imports `Observation`, not
  `SwiftUI`, and reaches the recogniser, sounds and audio session only through
  injected seams. Nothing calls `ToneEngine.shared` or `MatchSounds.shared`.
- Views never touch `ModelContext` or `@Query`; the store is behind a repository.
- A screen takes a `{Screen}Navigation` value. Its closures name what happened, not
  where to go, and are never defaulted to `{ }`.
- Never two top-level public types with the same name in co-importable modules.
- Never create a `Shared/`, `Common/` or `Util/` folder.

Before finishing work in a migrated vertical, check the diff against
`Documentation/feature-checklist.md`. The items nothing else catches: every view model `catch`
handles `CancellationError` first and ignores it, catches untyped rather than typed to
the domain error, and calls `log()` on the display error before yielding the effect.

Code still in the app target's folders follows its local convention until its vertical
moves. Do not start a third pattern.

The settled decisions below are product rules and survive the migration unchanged.
Moving code must not move a pinned cost out of the test suite.

## Build and test

```sh
xcodebuild build -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Run `xcodebuild clean` before `test` whenever a test file changed, and check
the test count moved.** The incremental build silently skips recompiling changed
test files and reports a pass for tests that never ran. This has happened three
times; once it reported `TEST SUCCEEDED` while eight new tests were skipped. A
green result on its own is not evidence that anything ran.

Current suite: 159 tests in 18 suites.

## Decisions already settled

Do not relitigate these without asking. Each was decided deliberately, most after
looking at real data, and several have tests pinning the consequence.

- **Tones are never graded**, at any strictness. Not a setting, not an oversight.
  A recogniser's tone output is its own guess as much as the speaker's.
- **Homophones pass.** Inherent to grading audio. Pinned by a test.
- **A word inside a longer phrase counts at every level,** including Strict. The
  recogniser pads single words into phrases; the speaker never said `了`.
- **The mistakes drill is speech, not matching.** It exists because the matching
  board needed five pairs and padded short mistakes lists with unrelated words.
- **Four strictness levels**, Relaxed by default. Raw values are storage, titles
  are display; rename titles freely, never raw values.
- **The drill plays no per-card tones.** Two attempts to make them audible under
  `.measurement` failed. Haptics carry the feedback. Do not reintroduce them by
  weakening the audio session — recognition accuracy outranks tone volume, which
  was an explicit call by the owner. Pinned by a test.
- **`DictationTranscriber`, never `SpeechTranscriber`.** The latter silently
  ignores contextual hints.

## How to work here

**Measure, do not estimate.** The pure types compile standalone with `swiftc`, so
a reported transcript can be replayed through all four levels in seconds. Two
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
- **Never instantiate a `VocabularySchemaV1` model in-process.** It resolves to the
  version 2 entity and crashes. Migration is tested against a real v1 store fixture.
- **A test that blocks the main actor breaks the timing tests.** Heavy synchronous
  work goes in a `nonisolated` suite.

- **Default arguments are evaluated in the caller's context.** With
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, any `static let` used as a default
  must be `nonisolated`. Caught four separate times.
- **Files are picked up from disk** (`PBXFileSystemSynchronizedRootGroup`). New
  files need no project edit, which is also why incremental builds miss changes.
- **The shared scheme's `TestAction` must not contain an empty `<TestPlans>`**, or
  xcodebuild reports the scheme as not configured for testing.
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
