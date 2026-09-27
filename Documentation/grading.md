# Grading

All of this lives in `Speech/AnswerGrader.swift`. It imports Foundation only and
is the most heavily tested thing in the project, because it decides whether
someone is told they are wrong.

## Why not compare the characters

The obvious implementation compares the recognised Hanzi to the expected Hanzi.
It fails constantly. `是`, `事`, `试` and `势` are all `shì`, and a recogniser
given a single isolated word has no context to choose between them, so it returns
whichever is most common. The speaker says the right thing and is marked wrong.

Everything is reduced to toneless pinyin syllables instead.
`CFStringTransform` with `kCFStringTransformMandarinLatin` does the conversion,
which is in Foundation, so nothing is needed to make it work.

The accepted consequence: **homophones pass, at every level.** Answering `事`
when asked for `是` is correct, because audio alone cannot tell them apart. There
is a test asserting it, so it is a recorded decision rather than a latent bug.

## Why tones are never graded

Dropping tones is deliberate and is not a setting. A recogniser's tone output
reflects its own guess as much as the speaker's, so grading on it would fail
people for reasons they can neither see nor correct. The correct tone marks are
shown when a card is revealed.

## Syllables, not one flat string

`syllables(_:)` returns one entry per syllable. Comparison then happens on
contiguous *runs* of those syllables, joined.

Both halves of that matter:

- **Syllables, because** flat-string containment would accept `完成`
  (`wancheng`) as an answer for `喝` (`he`) — those letters appear inside
  "cheng". Runs start and end on a syllable boundary, so they cannot.
- **Joined, because** the two sides disagree about where syllables break. `完成`
  transforms to two syllables, while the same word typed as `wancheng` arrives
  as one token. Comparing element-wise would reject it.

Both the Hanzi and the stored pinyin are kept as accepted forms, since a word
typed in by hand may split differently from its transform.

## Matching inside a phrase

Not gated by strictness. The recogniser routinely returns a short phrase rather
than a bare word, so a correct answer comes back as `完成了` or `是完成`. The
speaker never said `了`, so failing them for it is judging the recogniser's
phrasing.

The cost, recorded in a test: a single-syllable answer can be found inside a
longer word that contains it as a whole syllable. `老师` is `lao` + `shi`, so it
carries `是`. Multi-syllable answers are far safer, since a chance run of two
syllables is rare.

## The levels

| Level | Adds |
| --- | --- |
| Strict | — |
| Standard | alternatives, empty-rime fold |
| Relaxed | nasal-final fold |
| Generous | initial fold, `-ng`/`-n` fold, edit distance |

**Alternatives.** `DictationTranscriber` reports runner-up transcriptions
alongside its best guess, and on an isolated word the right answer is often
second. Grading them is less a loosening than using information already on offer.
They have to be asked for with `.alternativeTranscriptions`; without that option
the array is always empty.

**Empty-rime fold** maps `zhi`→`zhe`, `chi`→`che`, `shi`→`she`, and the same for
`ri`, `zi`, `ci`, `si`. The vowel in those syllables is not an `[i]` at all, it is
the initial consonant held on, and it sits close enough to `-e` that recognisers
swap them constantly — `知道` comes back as `这倒` over and over.

Safe to run on a joined string: each of those initials only ever begins a
syllable and none takes a further vowel after the `i`, so the sequence `zhi` is
always the syllable `zhi`. `shui` is untouched, being `s-h-u-i`. There is a test
for that, because a careless version would make `是` an answer for `水`.

*Cost:* `是` and `社` merge.

**Nasal-final fold** makes the vowel before a syllable-final `-ng`
interchangeable, so `-ang`, `-eng` and `-ong` are one ending. This is the
confusion behind `完成` returning as `晚昌` or `晚冲`: the initial is right, the
nasal is right, only the vowel differs.

Deliberately limited. `-ing` is left out, so `明` and `忙` stay apart. Compound
finals keep their medial, so `-uang` is not `-ang` and `晚窗` is not `完成`. And
it only forgives the vowel, so `往昌` is still wrong — `wang` and `wan` are
different syllables.

*Cost:* `想` and `兄` merge.

**Edit distance** allows one letter of slack per syllable's worth of word, capped
at two, computed from the *folded* length. Short words get none: with three
letters to play with, half the syllables in the language are one edit apart, and
without that `shi` would pass for `shuǐ`.

This is the blunt instrument and the reason Generous exists as a separate level
rather than being the default. It accepts `晚餐` (dinner) and `王冲` (a name) as
`完成`.

## Typed answers

They go through the same function, so the two paths cannot disagree. Hanzi and
pinyin both work, with or without tone marks, with or without spaces between
syllables, and `v` is accepted for `ü`.
