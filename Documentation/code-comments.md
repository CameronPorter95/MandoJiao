# Code comments

A comment exists only to give detail that cannot be conveyed by the code itself.
It does not describe the code to someone who does not understand the code.

Before writing one, ask: can this go in the code (a name, a structure, a constant)?
If yes, do that and write no comment. If in doubt, no comment.

## Warranted

- A why that is not deducible from the code.
- A deliberate-choice marker ("tones are never graded, do not add them").
- An external constraint, such as a framework behaviour found on device.
- A gotcha needed to use the code.

## Not warranted

- Restating the function name, signature, or switch cases.
- Interesting facts discovered along the way.
- A history of what was tried. That belongs in the commit message, which is where this
  project keeps its design record.

## Length

When warranted, one line. Two lines is already worse.

Some existing doc comments run longer, because they carry settled decisions that were
reached on device and have no test to pin them (the audio session, the microphone
timing). Leave those alone. New code follows the one-line rule, and a decision that can
be pinned by a test goes in a test instead.

## Register

Short sentences, concrete verbs. No em-dashes, no semicolons, no multi-clause
sentences. Use "move", "run", "delete", not "promote", "leverage", "facilitate".

## Tests

No narrating implementation. If a comment would change when the implementation
changes, delete it. Rename the test or the variable.

## Scope

Applies to `.swift` files. Not user-facing docs, and not commit messages, which carry
the full reasoning by design (see [CLAUDE.md](../CLAUDE.md#how-to-work-here)).
