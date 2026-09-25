import Foundation
import OSLog

/// Prints what the recogniser heard, and what grading made of it, for every answer in a
/// speech drill.
///
/// This exists because the only place speech recognition can actually be judged is a real
/// device, where there is no debugger stepping through the grader. Seeing the alternatives
/// next to the accepted spellings is what makes a wrong verdict diagnosable.
///
/// Debug builds only: a transcript is a recording of someone's voice turned into text, and
/// it has no business in a shipping app's device log.
enum SpeechLog {
    #if DEBUG
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MandoJiao",
        category: "speech"
    )
    #endif

    static func attempt(
        card: WordPair,
        outcome: SpeechOutcome,
        strictness: MatchStrictness,
        attempt: Int,
        of totalAttempts: Int,
        wasCorrect: Bool
    ) {
        #if DEBUG
        var lines: [String] = []

        lines.append("──── speech attempt \(attempt)/\(totalAttempts) · \(card.english)")
        lines.append("  want   \(card.hanzi)\(card.pinyin.isEmpty ? "" : "  \(card.pinyin)")")
        lines.append("  accept \(AnswerGrader.acceptedForms(of: card).sorted().joined(separator: ", "))")

        lines.append("  heard  \(describe(outcome.best, card: card, strictness: strictness))")

        if outcome.alternatives.isEmpty {
            lines.append("  alts   (none)")
        } else {
            for (index, alternative) in outcome.alternatives.enumerated() {
                lines.append("  alt \(index + 1)  \(describe(alternative, card: card, strictness: strictness))")
            }
        }

        lines.append("  \(strictness.rawValue) → \(wasCorrect ? "CORRECT" : "wrong")")

        // notice rather than debug: debug-level messages are unreliable in Xcode's
        // console, and the whole point of this is being read there.
        logger.notice("\(lines.joined(separator: "\n"), privacy: .public)")
        #endif
    }

    #if DEBUG
    /// Each candidate next to what it normalises to, and whether that alone would pass.
    /// The normalised form is the thing actually compared, so seeing it is the difference
    /// between "why was that wrong" and knowing.
    private static func describe(
        _ text: String,
        card: WordPair,
        strictness: MatchStrictness
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(nothing)" }

        let normalised = AnswerGrader.normalised(trimmed)
        let passes = AnswerGrader.isCorrect(trimmed, for: card, strictness: strictness)
        return "\(trimmed)  →  \(normalised)  \(passes ? "✓" : "✗")"
    }
    #endif
}
