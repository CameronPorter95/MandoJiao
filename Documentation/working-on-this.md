# Working on this

## Build and test

```sh
# Everything, on the simulator: all five packages' tests.
xcodebuild build -scheme MandoJiao -destination 'platform=iOS Simulator,id=<udid>'
xcodebuild test  -scheme MandoJiao -destination 'platform=iOS Simulator,id=<udid>'

# One package, headless on the Mac, in seconds.
cd Practice && swift test
cd Practice && swift test --filter StrictnessTests
```

Get `<udid>` from `xcrun simctl list devices available`. Xcode 27 did not resolve
`name=iPhone 17 Pro` here.

The scheme's test action lists four test bundles, one per package: `CoreTests`,
`VocabularyTests`, `PracticeTests` and `SettingsTests`. The app has
no test target. Each prints its own `Test run with` line; CLAUDE.md has the one-liner
that adds them up.

The scheme is shared (`xcshareddata/xcschemes`), so a fresh clone can run the
tests. Its `TestAction` must not carry an empty `<TestPlans>` element: that puts
the scheme in test-plan mode with no plans, and xcodebuild reports the scheme as
not configured for testing.

## The incremental build will lie to you

**This has bitten three times. It is the most important thing on this page.**

The project uses `PBXFileSystemSynchronizedRootGroup` for both targets, so files
are picked up by being on disk. Incremental builds do not reliably notice that a
test file changed. Two failure modes:

1. **Stale module.** The test target compiles against a previous build of the app
   module, so a renamed method reads as `extra argument 'x' in call` or a new type
   as `cannot find 'X' in scope`, in code that is perfectly correct.
2. **Silently skipped tests, reporting a pass.** Worse. A changed test file is not
   recompiled, the run reports `TEST SUCCEEDED`, and the tests you just wrote
   never executed. Once, eight new tests were skipped and the count stayed at 82
   while the suite went green.

So:

```sh
xcodebuild clean -scheme MandoJiao -destination '...' && xcodebuild test -scheme MandoJiao -destination '...'
```

And **watch the test count move.** If you added tests and
`Test run with N tests` did not change, they did not run, whatever the result
says. There is no shortcut around this; a green tick alone is not evidence.

## Simulator, not device

The deployment target is iOS 26.0 and the installed simulators are 26.5.

What the simulator cannot tell you:

- **Speech recognition.** No usable microphone. The typed path is fully testable
  there, and the whole app runs apart from the microphone.
- **Some runtime warnings.** The simulator uses `AVAudioSessionImpl_Simulator.mm`
  while a device uses `AVAudioSession_iOS.mm`. The main-thread `setActive`
  warning appears only on a device. This was confirmed by A/B: the warning is
  absent on the simulator even with the offending call deliberately restored.
- **Audio levels.** The attenuation under `.measurement` happens in the audio
  path, not in the sample data, so it cannot be measured from the buffer either.

## Seeing a screen without tapping

`simctl` cannot tap. To look at a screen that is behind navigation, point
`ContentView` at it temporarily, build, install, screenshot, then revert and
confirm with `git diff --stat MandoJiao/ContentView.swift` that it is empty.

```sh
xcrun simctl install <udid> "$(xcodebuild -showBuildSettings ... | awk ...)/MandoJiao.app"
xcrun simctl launch <udid> com.cameronporter.MandoJiao
xcrun simctl io <udid> screenshot out.png
```

The speaking lesson's states are easier still: `SpeakingScreen` is a pure function of
`SpeakingState`, so its previews show any state without a microphone, and
`SpeakingViewModel` takes any `SpeechRecognising`, so `ScriptedRecogniser` can drive
the whole speaking lesson.

## Checking behaviour without the app

The domain types (`AnswerGrader`, both builders, `MistakeUpdate`, the view models
with their fakes) live in packages that build for macOS, so their tests run headlessly
with `swift test`, no simulator. This is how a reported transcript gets replayed
through all four strictness levels before deciding anything: add the case to
`StrictnessTests` and run it. About two seconds warm, and it produces real numbers
instead of an estimate.

```sh
cd Practice && swift test --filter StrictnessTests
```

The old `swiftc` one-liner no longer works, because the domain files now import
each other's modules.

## The app icon is generated

`Tools/MakeAppIcon` renders all three variants from one source:

```sh
swift Tools/MakeAppIcon/main.swift MandoJiao/Assets.xcassets/AppIcon.appiconset
```

The light variant must have **no alpha channel** — App Store validation rejects a
primary icon carrying transparency. Dark and tinted are transparent, because the
system composites its own background behind them.

## Concurrency

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on both targets, so types are
main-actor isolated unless marked otherwise.

The recurring trap: **a default argument is evaluated in the caller's context**,
so `static let` values used as defaults must be `nonisolated`. This has caught
`MatchSounds.shared` (since deleted), `AnswerStrictness.default`, `ToneEngine.scale` and
`Endpointing`'s constants. The warning is "main actor-isolated static property
... can not be referenced from a nonisolated context", and it is an error under
Swift 6.

Everything builds in the Swift 6 language mode. The trap the compiler will not catch:
**a closure written inside a main-actor type and handed to a callback API is inferred
main-actor, and Swift 6 checks that at runtime.** If the framework calls it on another
thread, the process traps. `AVAudioEngine`'s input tap is the case in this app: it runs
on the audio thread, so the recogniser's tap is `@Sendable` and works from local copies
of what it needs. Any new callback into Speech or AVFAudio needs the same look, and none
of it can be exercised on the simulator.

## Recording decisions

Where a rule has a cost, there is a test asserting the cost rather than a comment
mentioning it — that homophones pass, that `是`/`社` merge, that `想`/`兄` merge,
that `老师` carries `是`. If one of those starts failing, a decision was reversed,
and the test says which.

Commit messages carry the reasoning. `git log` is the record of why grading works
the way it does, including the things that were tried and did not work.

## Traps found moving to layers

- **Protocols pick up the default isolation too.** Under
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` a plain `protocol` is main-actor
  isolated, and an `actor` cannot conform to it. Domain and data protocols are
  declared `nonisolated protocol`, and domain types `nonisolated struct`. Extensions
  on them need `nonisolated extension` as well; they do not inherit it.
- **With versions, never create an older version's model object in a process that has
  opened a newer one.** SwiftData resolved version 1's `Deck` to version 2's entity and
  threw on the missing `uuid`, so migrations were tested on a copy of a real store
  written by the old build instead. There are no versions until the first release.
- **A test that blocks the main actor breaks the timing tests.** Every suite shares
  the main actor, and `EndpointingTests` needs a 100ms sleep to wake before a 150ms
  window. The migration test opens an on-disk store synchronously, which starved it
  on every run. Heavy synchronous work goes in a `nonisolated` suite.
- **The simulator refuses back-to-back launches sometimes** ("Application failed
  preflight checks", "Busy"). The run reports zero tests. Wait a few seconds and run
  again; it is not a test failure.
- **Xcode 27 did not resolve `name=iPhone 17 Pro`** as a destination here. Use the
  simulator's id from `xcrun simctl list devices available`.
