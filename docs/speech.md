# Speech

## DictationTranscriber, not SpeechTranscriber

This is the trap in the framework. Both run under a `SpeechAnalyzer` session and
look interchangeable. They are not:

- `SpeechTranscriber` is the long-form module and **ignores contextual strings**.
  Hinting it at the expected word compiles and does nothing.
- `DictationTranscriber` is the short-utterance module, takes
  `ContentHint.shortForm`, and honours `AnalysisContext.contextualStrings`.

The hints are the expected Hanzi and its pinyin. They are what lift isolated-word
accuracy from poor to usable, so the module choice is not a preference.

`.alternativeTranscriptions` must be in the reporting options or
`result.alternatives` is always empty. Grading alternatives without asking for
them is dead code that looks like it works.

## The locale must be reserved

`AssetInventory.reserve(locale:)` has to be called before any module is built
with that locale, whether or not the model needs downloading. Skipping it on the
already-installed path makes the framework log, once per transcriber:

```
Cannot use modules with unallocated locales [zh_CN (fixed zh_CN)].
Currently allocated locales are []. This will be an error in a future release!
```

Reservations are a capped, app-wide resource, so `reserveLocale` checks what is
already reserved and frees one if at the limit.

Locales must be resolved through `DictationTranscriber.supportedLocale(equivalentTo:)`
and compared on `.identifier(.bcp47)`. A hand-built `Locale(identifier: "zh_CN")`
will not match the framework's own `zh-CN`.

## The seam

`SpeechRecognising` is a protocol in a Foundation-only file. `SpeakSession` never
touches it — the view captures audio and hands the session a `SpeechOutcome`,
which is also how typed answers arrive. That is what lets the three-attempt rule
be tested without audio hardware, and it means `SFSpeechRecognizer` could be
dropped in without touching grading or UI.

## Knowing when someone has stopped

The transcriber reports what it has heard but never says "they have stopped", so
the end of an utterance has to be inferred. `Endpointing` polls the live
transcript and ends the card once it has been unchanged for 700ms, with a 5s
backstop.

It polls rather than observing, because what matters is how long the transcript
has been *still*, not that it changed.

700ms is a floor, not a tuning preference: a two-character word has a real gap
between its syllables, and a shorter window cuts words in half. There is a test
for a pause mid-answer that resumes.

## The microphone is not instant

Opening it means building a transcriber, an analyser, resolving an audio format
and starting the engine. The button therefore has three states —
`idle`, `arming`, `listening` — and only claims to be listening once capture is
actually running. Saying "listening" through the setup invites people to speak
into a microphone that is not recording, and the first syllable goes missing.

The audio format is resolved during `prepare()` rather than on the first tap,
since it is the slow step.

`startListening` waits for any previous `stop()` to finish. `stop()` nils the
analyser *after* awaiting finalisation, so starting on top of a teardown in
flight would have the old stop pull the new session's state out from under it.
That is easy to hit now that a correct answer runs straight into the next card.

## Carrying on after a correct answer

A correct answer opens the microphone for the next card by itself, so a run of
them costs one tap. A wrong one stops, because the answer on screen is there to
be read.

The trigger is the **card changing**, not the answer landing. Those are ~850ms
apart and the success tone plays in the gap; an earlier microphone would record
the tone and hand it back as the next answer.

Silence after an automatic start does not spend an attempt. The microphone can
open before the word has been read, so hearing nothing there means "not ready
yet". A tap is a deliberate go, and silence after one still counts.

## The audio session, and why a drill is silent

A drill runs `.playAndRecord` in `.measurement` mode with `.defaultToSpeaker`.

- `.measurement` stays. It is what leaves the recogniser's input unprocessed.
- `.defaultToSpeaker` is not optional: under `.playAndRecord` output otherwise
  goes to the earpiece.

`.measurement` also turns off output processing, which made the per-card tones
markedly quieter than the matching lesson's. Two attempts to compensate both
failed: gain hit the clipping ceiling at about 2.9× the match tone's base, and
shifting the tones up an octave into the most sensitive band of hearing helped
but not enough.

So **the drill plays no per-card tones at all.** Haptics still mark every right
and wrong answer, so feedback is not lost, only its audio. The completion fanfare
does play, because by then the drill is over: the view hands the session back
with `await exitRecordingMode()` before playing it, and it is heard at the normal
level. That call is awaitable for exactly this reason — playing during the switch
collapses the arpeggio to whichever note lands after the engine returns.

The session is only taken over when the microphone is actually usable, so a
typed-only drill leaves it alone. Practising again after finishing reclaims it,
since finishing hands it back.

Session configuration runs off the main thread. `setActive` can block long enough
to stall the UI and AVAudioSession warns about it at runtime; the async
`activate(options:completionHandler:)` it suggests is iOS 27, above this app's
deployment target.

## Reading what happened

`SpeechLog` prints every graded attempt, debug builds only, at `notice` level
because `debug` is unreliable in Xcode's console:

```
──── speech attempt 1/3 · to complete
  want   完成  wán chéng
  accept wancheng
  heard  万座  →  wanzuo  ✗
  alt 1  完成  →  wancheng  ✓
  alt 2  晚场  →  wanchang  ✗
  balanced → CORRECT
```

The `→ normalised` column is the point: that is the string actually compared, so
a surprising verdict stops being a mystery. Filter Xcode's console on `speech`,
or stream it:

```sh
xcrun simctl spawn booted log stream --predicate 'category == "speech"'
```

A transcript is a recording of someone's voice as text, which is why this is
`#if DEBUG` and not in shipping builds.
