# Feature conformance checklist

The checkable form of [architecture.md](architecture.md). That document explains *why*
the pattern looks the way it does and is read once; this one is the list a reviewer
walks per change, so every item is a single assertion that is either true or false of
the diff in front of you.

Rules are stated here and justified there. Where an item links a decision, the
reasoning lives in that decision and is not repeated. `MandoJiao/Vocabulary/` is the
reference implementation for every layer, and `MandoJiao/Speaking/` for a view model
driving platform seams; copying them is the fastest way to pass this list.

Module and target dependency rules are not repeated here either; they are in
[modularisation.md](modularisation.md).

---

## Scope

Applies to code in layer targets (`{X}Domain`, `{X}Data`, `{X}UI`, `{X}DI`) and to any
new vertical.

Does **not** apply to code still in the app target's `Views/`, `Game/`, `Audio/` and
`Models/` folders. Those follow their local convention until their
vertical moves; see [modularisation-migration.md](modularisation-migration.md).
Holding unmigrated code to this list would block ordinary feature work for nothing.

The project rules in [CLAUDE.md](../CLAUDE.md) apply everywhere, migrated or not.

---

## Domain layer

- [ ] **D1** The domain target imports `Foundation`, `CoreDomain` and peers' `Domain`
      targets, and nothing else. No SwiftUI, UIKit, SwiftData, Speech, AVFoundation or
      OSLog. ([why](architecture.md#module-placement))
- [ ] **D2** The repository protocol names a capability, never a mechanism. No `store`,
      `context`, `fetch…FromDisk` in its names or parameters, and it returns domain
      models, never `@Model` types.
      ([why](architecture.md#1-the-repository-is-a-domain-protocol-orchestration-is-a-data-detail))
- [ ] **D3** Each use case is one business action invoked through `callAsFunction`, thin,
      and delegates to the repository. It lives in its own file in the domain target's
      `UseCases/` folder, never beside the model or the repository protocol. A rule that needs no data (grading, dealing a
      board) is a domain rule type, not a use case.
- [ ] **D4** Domain operations are untyped `async throws`. No typed throws, no
      completion handlers, no `Result` in the contract. A read of a local value that
      cannot fail (`SpeakingSettingsRepository`) may be synchronous.
      ([why](architecture.md#3-untyped-throws-not-typed-throws))
- [ ] **D5** The domain error is a bare `Sendable` enum classifying the *cause*
      (`persistence`, `unexpected`, plus any expected outcome the UI must branch on),
      each case carrying a `DomainErrorModel`. The UI never has to inspect a platform
      error. ([why](architecture.md#4-two-errors-a-domain-error-and-a-display-error))
- [ ] **D6** The domain error carries no user-facing copy, no `LocalizedError`, and no
      logging.
- [ ] **D7** Observation is exposed as an `AsyncStream` of domain models, not as a
      SwiftUI or Observation type. ([why](architecture.md#7-observing-the-store-without-query))
- [ ] **D8** Domain types, protocols and their extensions are `nonisolated`, so the
      app target's `MainActor` default does not pin them to the main actor.

---

## Data layer

- [ ] **Da1** The repository implementation is the only type that knows the store
      exists. Nothing above the data layer names `ModelContext`, `ModelContainer`,
      `FetchDescriptor` or an entity.
      ([why](architecture.md#1-the-repository-is-a-domain-protocol-orchestration-is-a-data-detail))
- [ ] **Da2** Mutations go through the repository and are saved in the same operation.
      No view calls `insert`, `delete` or `save`.
      ([why](architecture.md#6-mutations-write-through-the-repository))
- [ ] **Da3** Every repository method that can fail ends with the full classification
      ladder, in this order:
      ```swift
      catch is CancellationError { throw CancellationError() }
      catch let error as LocalStoreError { throw XDomainError.persistence(model: error.model) }
      catch { throw XDomainError.unexpected(model: DomainErrorModel(error)) }
      ```
      Cancellation is rethrown as cancellation, never reclassified as a failure, and the
      untyped final `catch` means no platform error can escape unclassified. No `try?`
      on a save.
      ([why](architecture.md#15-log-an-error-where-it-originates-classify-for-the-boundary))
- [ ] **Da4** Every source and platform service sits behind a protocol. A local source
      is a `@ModelActor` whose context is private, and no `@Model` instance crosses its
      boundary. ([why](architecture.md#11-the-local-source-keeps-its-context-private))
- [ ] **Da5** Entities stay internal to the data layer. Their mapping to domain models
      is declared there too.
      ([why](architecture.md#module-placement))
- [ ] **Da6** Settings storage reads and writes the existing `Preferences.Key` strings
      and raw values. A renamed key or raw value strands every saved preference.
- [ ] **Da7** The data target imports no UIKit and never touches `AVAudioSession`
      directly. The audio session is `CoreSound`'s.
      ([why](modularisation.md#building-for-macos))

---

## UI layer: state, actions, effects

- [ ] **U1** `State` is an `Equatable` value type and the single source of truth for the
      screen. Derived values (progress, attempts left, the mistakes sort) are computed
      properties on it, not stored duplicates. The view model's only non-private
      stored `var` is `private(set) var state`. Other stored properties are `private`
      and carry no `@ObservationIgnored`: the view reads only `state`, so nothing else
      is ever tracked.
- [ ] **U2** One-shot concerns (showing an error, firing a haptic, navigating,
      dismissing) are `Effect` cases sent through an `EffectChannel`, never fields on
      `State`. No counters in state whose only job is to trigger a one-shot. A presented
      sheet or dialog is the opposite: it lasts until dismissed, so it is state, with an
      action for the dismissal.
      ([why](architecture.md#9-effects-through-a-channel-state-over-the-observable-property))
- [ ] **U3** The `Screen` is stateless: `state` in, `onAction` out, previewable. The
      `Route` owns the view model, consumes effects, and holds the environmental wiring
      (navigation, scene phase, haptics).
      ([why](architecture.md#8-route--screen-split))
- [ ] **U4** Mutations update state optimistically and revert on failure.
- [ ] **U5** Effects are exposed as `func effects() -> AsyncStream<Effect>` backed by an
      `EffectChannel`, and the only caller is the `Route`, in `.task`. Never a stored
      `AsyncStream` property: `.task` is cancelled whenever the view disappears,
      including when a screen is pushed over it, and a cancelled consumer ends a bare
      stream permanently, so every later effect would go nowhere.
      ([why](architecture.md#9-effects-through-a-channel-state-over-the-observable-property))
- [ ] **U6** The view model is passed to the `Route`'s `init` and held as `@State`, never
      owned by a parent view or the environment. A view model that observes a stream
      subscribes on `.appeared` and cancels on `.disappeared`, so a popped screen stops
      listening.
- [ ] **U7** The view model, state, action, effect and display error use no UIKit and no
      iOS-only API. The view model imports `Observation`, not `SwiftUI`.
      ([why](modularisation.md#building-for-macos))
- [ ] **U8** The view model never reaches a platform service except through an injected
      seam. The recogniser, sounds and the audio session mode are all protocols handed
      in by the factory. Nothing calls `ToneEngine.shared` or `MatchSounds.shared`.
- [ ] **U9** A view uses no iOS-only modifier or UIKit bridge directly. It goes through a
      `CoreDesignSystem` wrapper that compiles on macOS. No `#if os(iOS)` in a feature
      view. ([why](modularisation.md#building-for-macos))

---

## UI layer: errors and reporting

This is the section most easily missed, because nothing about it fails to compile.

- [ ] **E1** A feature that can fail owns a display error in `{X}UI` conforming to
      `LoggedError, LocalizedError, Sendable`, with a case per failing operation and a
      user-facing `errorDescription`.
      ([why](architecture.md#4-two-errors-a-domain-error-and-a-display-error))
- [ ] **E2** The display error implements `log()`, writing the domain descriptor
      (`domain`, `code`, `description`) through the `ErrorLog` seam with
      `privacy: .public` on anything that must be readable in a device log.
- [ ] **E3** Every `catch` in a view model handles cancellation first and ignores it:
      ```swift
      catch is CancellationError { /* cancelled, not a failure */ }
      ```
      No state change, no log, no effect. A speaking lesson closed mid-listen is not something the
      user did wrong. ([why](architecture.md#3-untyped-throws-not-typed-throws))
- [ ] **E4** No view model *ends* its catch ladder on a typed catch. `catch let error as
      XDomainError` as the last rung leaves every other throw to vanish into the enclosing
      `Task`. Catch untyped and map:
      ```swift
      let domainError = error as? XDomainError ?? .unexpected(model: .init(error))
      ```
- [ ] **E5** Each failure path mints the display error, calls `log()` on it, and *then*
      sends the effect. In Vocabulary, `VocabularyError.performing` does all three, and
      a write goes through it rather than repeating the ladder. The log call is the easy one to drop, and dropping it is silent.
      ```swift
      let displayError = XError.saveFailed(domainError: domainError)
      displayError.log()
      effectChannel.send(.showError(displayError))
      ```
- [ ] **E6** Logging happens in the view model only. A `Route`, `Screen` or factory
      never calls `log()`.
- [ ] **E7** Domain error cases that are *expected outcomes* rather than failures (the
      recogniser unavailable because permission was refused, say) are resolved in state
      and neither logged nor shown as an error.
- [ ] **E8** The view model never inspects a platform error type (`SwiftDataError`,
      `NSError`). If it needs to branch on a cause, the data layer classifies it into a
      domain error case first.
      ([why](architecture.md#15-log-an-error-where-it-originates-classify-for-the-boundary))

---

## Wiring

- [ ] **W1** The factory lives in `{X}DI` and builds the whole graph: repository, use
      cases, seams, view model, Route. It is the only place naming a concrete
      implementation. It is a stateless `public enum` conforming to a `CoreDI` route
      factory protocol, taking `Dependencies` and holding nothing. Shared state, such as
      the one repository per store, lives in the data layer.
      ([why](architecture.md#13-dependency-injection-via-a-composition-root-factory))
- [ ] **W2** `{X}UI` does not import `{X}Data`, and no type constructs its own
      dependencies inline (`recogniser ?? DictationRecogniser()` in a view is service
      location, not injection).
- [ ] **W3** Environment-bound or non-deterministic inputs (the recogniser, sounds,
      the auto-advance delay, `Endpointing`'s timings, clocks, `UserDefaults`) are
      injected with production defaults so tests can supply fakes.
      ([why](architecture.md#14-test-seams-are-injected-not-hard-coded))
- [ ] **W4** A `static let` used as a default argument in a `MainActor`-default target
      is `nonisolated`. ([why](../CLAUDE.md#traps-specific-to-this-project))

---

## Navigation

Rules stated and justified in [modularisation.md](modularisation.md#navigation).

- [ ] **N1** The screen receives a `{Screen}Navigation` value. It does not construct
      another package's screen inline.
- [ ] **N2** Every closure is named for what happened, not where it goes.
      `didRequestSpeaking`, `didFinishLesson`, `didClose`; never `presentSpeakLesson`,
      `showX`, `navigateToY`.
- [ ] **N3** No navigation closure carries a `= { }` or `= { _ in }` default at its
      declaration site. A defaulted closure compiles, silently does nothing at runtime,
      and reads on review exactly like working navigation. An empty closure written
      *inside a flow constructor* is fine, with a comment saying so.
- [ ] **N4** Per-flow constructors live in `{X}DI`: one folder per screen, with the
      package's own bundle at the target root composing them.
- [ ] **N5** Dismissal is owned by whatever presents the screen, not by the navigation
      value.
- [ ] **N6** Every closure declared on a `{Screen}Navigation` is invoked somewhere in that
      screen's `Route`. Check it from the declaration outwards.

---

## Tests

- [ ] **T1** New tests use Swift Testing and live in the package test target.
- [ ] **T2** View model tests cover: action to state, the error effect, revert on a
      failed mutation, and that a cancelled operation emits nothing.
- [ ] **T3** Repository tests cover the classification itself: a store failure becomes
      `persistence`, anything else becomes `unexpected`, and cancellation propagates as
      `CancellationError`.
- [ ] **T4** No test file imports UIKit unguarded.
      ([why](modularisation.md#building-for-macos))
- [ ] **T5** A rule with a cost has a test asserting the cost, not a comment
      mentioning it. Moving code does not move the pinned costs (`是`/`社`, `想`/`兄`,
      `老师` carrying `是`, homophones passing) out of the suite.
- [ ] **T6** The run was preceded by a clean, and the test count moved by the number of
      tests added. A green result alone is not evidence.

---

## How this is enforced

Three tiers. A rule belongs in the cheapest one that can catch it.

| Tier | Mechanism | Catches |
| --- | --- | --- |
| Compiler | SPM target dependencies | D1 and W2, once targets exist: a forbidden import does not build |
| Import boundaries | SwiftLint custom rules (not yet set up) | The typed-catch half of E4, N3, Da7, U7's UIKit half, T4 |
| Everything else | Review, human and automated, against this list | The structural, error-handling and navigation rules, which no regex can see |

Until the first package exists, everything is caught by review. The SPM split is what
moves D1 and W2 into the compiler for free, and it is the strongest argument for
packages over folders.
