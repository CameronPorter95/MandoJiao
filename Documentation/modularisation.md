# Modularisation: packages, targets, and dependency rules

How the codebase is split into SPM targets, what each may depend on, and where a given
file belongs. These are the standing rules for the target shape.

- [architecture.md](architecture.md) covers the layering *inside* a feature (MVI +
  Clean Architecture). The two are aligned: the module boundary and the layer boundary
  are the same line.
- [modularisation-migration.md](modularisation-migration.md) covers where the code is
  today, the order things move in, and what is known to be untidy.

---

## The rule

> **A feature package may not depend on another feature package's concrete target.
> It may depend only on that package's `Domain` product.**

Google's Android guidance, adapted to SPM. No separate `api` target is needed:
`{X}Domain` already *is* the interface. `{X}Domain` is simultaneously the interface
seam and a future KMP `commonMain`, and concern targets scope framework dependencies
(SwiftData, Speech, AVFoundation) to the target that needs them.

---

## Feature package structure

| Target | Contains | Depends on | Imported by |
| --- | --- | --- | --- |
| `{X}Domain` | Domain models, domain rules, repository and seam protocols, use cases, domain errors | `CoreDomain`, peers' `Domain` | Anyone, including other packages |
| `{X}Data` | Repository impls, local sources, `@Model` entities, platform services, mapping | `{X}Domain`, `CorePersistence`, `CoreAudio` as needed | `{X}DI` only |
| `{X}UI` | Views, view models, state, actions, effects; the package's destination enum and navigation values | `{X}Domain`, `CoreUI`, `CoreDesignSystem` | `{X}DI` only |
| `{X}DI` | Factories wiring sources → repository → use cases → view model; per-flow navigation constructors; the package's `@Model` types for the schema | all three above | `Application` |

```mermaid
flowchart TD
    DI["{X}DI<br/><i>composition root</i>"] --> UI["{X}UI"]
    DI --> Data["{X}Data"]
    DI --> Domain["{X}Domain"]
    UI --> Domain
    Data --> Domain
    App["Application"] --> DI
    Peer["another feature package"] --> Domain
```

**Take only the targets you need.** A package with no persistence and no platform
service has no `{X}Data`. `Matching` is the example: it reads words and records
results through `VocabularyDomain` use cases, and owns nothing that touches a
framework except its settings.

**Products.** `{X}Domain` is the only one peers may depend on. `{X}DI` is a product for
`Application` only. `{X}Data` is **never** a product.

**Rules that follow:**

- `{X}Domain` must not import `SwiftUI`, `UIKit`, `SwiftData`, `Speech`, `AVFoundation`
  or `OSLog`.
- `{X}UI` must not import `{X}Data`. If it needs to, the wiring belongs in `{X}DI`.
- `{X}Data` must not import `{X}UI`.
- Only `{X}DI` may name a concrete implementation type.
- Domain and UI targets must build for macOS. See
  [Building for macOS](#building-for-macos).

**Why `{X}DI` exists.** Something has to construct a repository from its sources and
hand use cases to a view model, and that something must see all three layers. Swift has
no Hilt, so the wiring is manual and needs a home. Keeping it out of `{X}UI` is what
preserves the UI-to-Data non-dependency.

**Application may import `{X}DI`; a feature package may not.** `{X}Domain` hands out
*types*, which is all a peer needs because it receives instances by injection. `{X}DI`
hands out *instances*, which requires seeing implementations. Application is the root
that does the injecting, not a peer.

---

## Feature packages

| Package | Owns | Targets |
| --- | --- | --- |
| `Vocabulary` | Words, decks, the mistakes list, the library and word editor, deck detail, and the home screen. `WordPair`, `LessonRequest`, `VocabWord`, `Deck`, sample seeding. | all four |
| `Matching` | The matching exercise. `LessonPlan`, `LessonBuilder`, `MatchBoard`, the matching view model, board and tile views, matching settings. | all four; `Data` holds only settings storage |
| `Drill` | The speech drill. `SpeakPlan`, `SpeakLessonBuilder`, `AnswerGrader`, `MatchStrictness`, `Endpointing`, the `SpeechRecognising` seam and `DictationRecogniser`, `SpeechLog`, the drill view model and card views, drill settings. | all four |
| `Settings` | The settings screen. Edits matching and drill settings through their domains. | `UI`, `DI` |

**The home screen lives in `Vocabulary`,** because everything on it is vocabulary data:
the word count, the mistakes list, the decks. Starting a lesson is a navigation event
(`didRequestMatching`, `didRequestDrill`) that `Application` turns into a presentation.

**Settings are owned by the feature that reads them.** Strictness and the card limit
belong to `Drill`; rounds and pinyin visibility belong to `Matching`. The settings
screen is a composition over both domains. The alternative, `Settings` owning every
preference, forces `Drill → Settings → Drill`, which SPM rejects. Storage keys are
unchanged from `Preferences.Key`, and strictness raw values remain storage (see
[CLAUDE.md](../CLAUDE.md#decisions-already-settled)).

---

## Core package structure

One package, concern targets. Not sibling packages.

| Target | Contains | Membership test |
| --- | --- | --- |
| `CoreDomain` | Shared pure types: `MatchSoundPlaying`, `AudioSessionSwitching`, `DomainErrorModel`, `ErrorLog` | Zero dependencies beyond Foundation |
| `CorePersistence` | SwiftData container plumbing: the `@ModelActor` base helpers, schema composition, in-memory configuration for tests | Names no feature entity |
| `CoreAudio` | `ToneEngine` and the audio session | Implements `CoreDomain` seams, names no feature |
| `CoreDesignSystem` | `Theme`, `LessonProgressBar`, view primitives, wrappers over iOS-only view APIs | Needs nothing but SwiftUI, and builds for macOS |
| `CoreUI` | Screens shared by more than one feature: `LessonCompleteView` | Used by two or more packages |

There is no `CoreNetworking`, because there is no backend, and no `CoreDI` until a DI
primitive is shared by two packages. Add a target when its first real member exists,
not in anticipation.

> [!WARNING]
> The persistence target must not be called `SwiftData`. It collides with Apple's.

**`CoreDomain` may hold platform glue, in files named for what they bridge.** A shared
KMP module has `commonMain` and `iosMain`, and a Swift bridge onto a shared type belongs
in the latter. The rule is the naming, not an exemption: glue goes in
`{Type}+{PlatformType}.swift` and never mixes into the portable declaration.

**Seams are for things the app must decide,** such as which sound engine plays and where
errors are logged. They are registered once, in `Application`, and injected from there.
A value baked into the build is read from `Bundle.main` instead.

---

## Building for macOS

> **Domain and UI targets must build for macOS as well as iOS.**

The aim is to run a feature's logic headlessly on a Mac. View model tests and agent
tooling can then drive a screen by sending actions and reading state and effects. That
takes milliseconds, with no simulator, no accessibility tree and no screenshots. The
project already leans on this by compiling the grading types with `swiftc`; this rule
extends it to whole screens.

| Target | What it means |
| --- | --- |
| `{X}Domain` | Nothing extra. It is already platform-free. |
| `{X}Data` | Should build for macOS. SwiftData, `Speech` and `AVAudioEngine` all exist there. `AVAudioSession` does not, which is why only `CoreAudio` may touch it. |
| `{X}UI`: view model, state, action, effect, display error | No UIKit and no iOS-only API. The view model imports `Observation` for `@Observable`, not `SwiftUI`, so it never sees a view type. A platform-bound call (haptics, a settings URL) is an effect the `Route` performs, or a seam injected with a production default. |
| `{X}UI`: views | Cross-platform SwiftUI by default. An iOS-only modifier or UIKit bridge goes behind a `CoreDesignSystem` wrapper that compiles on both platforms. Never put `#if os(iOS)` in a feature view. |
| `{X}DI` | No UIKit. It builds the graph and returns the `Route`. |
| `CoreAudio` | The one sanctioned `#if os(iOS)`: audio session configuration. Everything else in it compiles on macOS. |
| `{X}Tests` | A test that needs UIKit goes in its own file wrapped in `#if canImport(UIKit)`. The rest of the target then still builds for macOS. |

**A package opts in by listing `.macOS(.v26)` in `platforms`,** matching the iOS 26
floor the app already has. It changes nothing about the iOS build.

**Build for macOS with `xcodebuild`:**

```
xcodebuild -scheme DrillDomain -destination 'platform=macOS' build
```

**A seam is what keeps a platform service out of a target.** `MatchSoundPlaying` and
`SpeechRecognising` are the pattern. A headless run registers fakes (`SilentSounds`,
`ScriptedRecogniser`). Reach for one before importing a framework into a layer target.

---

## Concurrency settings per target

The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Packages set it per
target in `swiftSettings`, and the right answer differs by layer:

| Target | Default isolation | Why |
| --- | --- | --- |
| `{X}Domain` | nonisolated | Grading and plan building are pure and should run anywhere. Also the KMP shape. |
| `{X}Data` | nonisolated | Local sources are actors of their own. |
| `{X}UI`, `{X}DI` | `MainActor` | View models and routes are main-actor by nature. |

The trap in [CLAUDE.md](../CLAUDE.md#traps-specific-to-this-project) about default
arguments applies wherever `MainActor` is the default. It stops applying in domain
targets, which is one less place to get it wrong.

---

## Cross-feature dependencies

Two kinds of seam, in different places:

| Seam | Example | Declared in | Implemented in |
| --- | --- | --- | --- |
| **Behaviour** | Matching needs to record which words were missed | `{owner}Domain` (`VocabularyDomain`) | `{owner}Data`, injected in `Application` |
| **Screen** | Home needs to open a matching lesson | a navigation closure in `{consumer}UI` | `Application` |

A view factory protocol must name a `View`, so it cannot live in `Domain` without
destroying its portability.

Package graph (target):

```
Core        <- everyone
Vocabulary  <- Matching, Drill
Matching    <- Settings
Drill       <- Settings
Settings    (no inbound edges)
```

Only `Vocabulary`, `Matching` and `Drill` need a `Domain` seam for peers.

---

## Navigation

> **A screen names what happened. Only the composition root names where to go.**

A screen never builds its destination inline. It receives a `{Screen}Navigation`: a
struct of closures, one per way of leaving.

```swift
@MainActor
public struct HomeNavigation {
  public var didRequestMatching: (LessonRequest) -> Void
  public var didRequestDrill: (LessonRequest) -> Void
  public var didRequestSettings: () -> Void
}
```

**Closures are named for the event, not the destination.** `didRequestDrill`, never
`presentSpeakLesson`. The moment a name says where it goes, the screen has taken a
position on a stack it cannot see, and the same screen can no longer serve two flows.
`DrillNavigation` is the first of these. `HomeView` still decides the presentation
itself for now, and still builds `LessonView` inline.

**One bundle per package.** `{X}Navigation` holds one member per screen, so a factory
signature stays at a single navigation parameter however many screens the package
gains.

**Flow constructors live in `{X}DI`,** as `{Type}Navigation+Flows.swift`. A constructor
belongs with the stack it navigates, which is not always the package that declares the
type.

**`AppNavigation` is the composition root's own bundle.** It is the only place that sees
every package, so a cross-package jump (home to a lesson, home to settings) is
expressed there.

**Never default a navigation closure.** A `= { }` at an injection site compiles, silently
does nothing at runtime, and is the most common defect this pattern produces. Make it a
compile error instead. An empty closure written *inside a flow constructor* is different
and fine, because it states that this flow wants nothing further; say so in a comment.

**Dismissal belongs to the presenter, not to navigation.** Whether a modal closes is not
knowable when a navigation value is constructed, so the wrapper that presents it owns
`dismiss()` and the injected navigation says only what should happen as well. The
lesson views' `onClose` is this already.

---

## Folder conventions inside a target

> **A folder names a resource. The target's own mechanism has no folder.**

Mechanism sits at the target root; resource-shaped code goes in a folder named for the
resource.

```
VocabularyUI/
  VocabularyNavigation.swift         <- the target's own mechanism
  Home/HomeRoute.swift
  Home/HomeScreen.swift
  Home/HomeViewModel.swift
  Library/WordLibraryRoute.swift
  WordEditor/WordEditorScreen.swift
```

**Never create `Shared/`, `Common/`, `Util/`, `Helpers/` or `Client/`.** A folder you can
only name after its shared-ness has not been classified yet, and it will attract
everything. Add structure to a mechanism only when it earns it, and then split by role,
never into one bucket.

---

## Naming

**Names repeat across layers by design.** `Deck`, `DeckSummary`, `DeckRepository`,
`DeckDetailViewModel`, `DeckDetailScreen` is the ubiquitous language working, not
duplication. One grep finds the whole vertical.

**Data is named for the aggregate; UI is named for the task.** `HomeScreen` is right
even though its data layer says `VocabWord` and `Deck`.

**Existing names are not renamed for the sake of it.** `SpeakSession` splitting into
`DrillLesson` and `DrillViewModel` was a rename with a reason (it became two things); `WordPair`
becoming `Word` is not, and would churn every test for nothing.

**The one hard rule:**

> Never let two types with the identical *unqualified* name exist in modules that can be
> imported together.

Suffixes carry the layer, so `Deck` (entity) and `DeckSummary` (domain) is fine; two
targets both declaring `Deck` is not. Nested types never collide and are exempt.

**Filenames are unique too.** Two files with the same basename make jump-to-file a coin
toss. An extension in another target is named for what it adds.

**A flow file is plural when it composes and singular when it does not.** A bundle
constructor at a DI target's root is `+Flows`; a per-screen constructor in a screen
folder is `+Flow`.

---

## Deciding where code lives

**Placement is decided by consumers, not names.** Ask:

1. **How many independent consumers?** One means the whole vertical lives in that
   feature package and the Core question never arises. This is the common case.
2. **Is the second consumer real?** A preview or a test is not a consumer.
3. **Would deleting the feature delete this code?** If yes it belongs to the feature,
   however generic it looks. Deleting the drill would delete `AnswerGrader`, so it
   lives in `Drill` even though it is the most reusable code in the app.

### Share domain models, not entities

> The sharing level is the domain model and the use case, never the `@Model` type.

An entity is the data layer's private vocabulary for the current schema. **An entity
that has to be shared means the vertical has two implementations, not two consumers**;
the fix is for the second caller to use the use case.

**If a type appears to fit nowhere, it is usually two things welded together: a pure
contract and a platform implementation.** `ToneEngine` is the example already in the
code: `MatchSoundPlaying` is the contract, `ToneEngine` the implementation. Split it
and each half has an obvious home. Never invent a target named for shared-ness
(`CoreShared`, `CoreUtil`).

---

## Test targets

**One `{X}Tests` target per package**, organised by resource folder, mirroring the
source layout. Not one per layer.

**`{X}TestSupport`** holds shared test doubles and fixtures, depends on `{X}Domain`, and
is depended on by `{X}Tests` and peers' tests. `ScriptedRecogniser` belongs in
`DrillTestSupport`; a fake `VocabularyRepository` belongs in `VocabularyTestSupport`. A fake
used by exactly one test file stays private to that file; hoist when a second consumer
appears.

Keep the test target macOS-buildable too, per [Building for macOS](#building-for-macos).
One test target per package means one UIKit import blocks the whole target.

> [!WARNING]
> Moving tests into packages changes where the test count comes from. The CLAUDE.md
> rule (clean, then check the count moved) applies per scheme, and the app scheme must
> list every package test target or those tests silently stop running with it.
