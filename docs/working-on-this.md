# Working on this

## Build and test

```sh
xcodebuild build -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -scheme MandoJiao -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

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

Injecting a stub recogniser through `SpeakLessonView(request:recogniser:onClose:)`
is how the drill's states get looked at without a microphone.

## Checking behaviour without the app

The pure types — `AnswerGrader`, `MatchBoard`, both builders, `MistakeLog` — can
be compiled into a command-line program with `swiftc` and run directly. This is
how reported transcripts get replayed through all four strictness levels before
deciding anything. Far quicker than a simulator round trip, and it produces real
numbers instead of an estimate.

```sh
swiftc -o check MandoJiao/Models/WordPair.swift MandoJiao/Speech/AnswerGrader.swift \
    MandoJiao/Speech/MatchStrictness.swift MandoJiao/Speech/SpeechRecognising.swift main.swift
```

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
`MatchSounds.shared`, `MatchStrictness.default`, `ToneEngine.scale` and
`Endpointing`'s constants. The warning is "main actor-isolated static property
... can not be referenced from a nonisolated context", and it is an error under
Swift 6.

## Recording decisions

Where a rule has a cost, there is a test asserting the cost rather than a comment
mentioning it — that homophones pass, that `是`/`社` merge, that `想`/`兄` merge,
that `老师` carries `是`. If one of those starts failing, a decision was reversed,
and the test says which.

Commit messages carry the reasoning. `git log` is the record of why grading works
the way it does, including the things that were tried and did not work.
