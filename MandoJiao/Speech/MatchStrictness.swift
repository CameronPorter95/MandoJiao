import Foundation

/// How forgiving answer checking is.
///
/// Tones are ignored at every level, deliberately. A recogniser's tone output reflects
/// its own guess as much as the speaker's, so grading on it would fail people for
/// reasons they cannot see or correct.
enum MatchStrictness: String, CaseIterable, Identifiable, Sendable {
    case strict
    case balanced
    case lenient

    /// Nonisolated so it can serve as a default argument, which is evaluated in the
    /// caller's context rather than this type's.
    nonisolated static let `default` = MatchStrictness.balanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: "Strict"
        case .balanced: "Balanced"
        case .lenient: "Lenient"
        }
    }

    var detail: String {
        switch self {
        case .strict:
            "Only the word itself, exactly as recognised."
        case .balanced:
            "Also accepts the word inside a longer phrase, and the recogniser's second guesses."
        case .lenient:
            "Also accepts near spellings: zh and z, ch and c, sh and s, -ng and -n, and a syllable that is a letter or two out."
        }
    }

    /// Whether a transcript may carry other words alongside the answer.
    ///
    /// The recogniser often returns a short phrase rather than a bare word, so a correct
    /// answer comes back as 完成了 or 是完成 and fails an exact comparison.
    var allowsSurroundingWords: Bool { self != .strict }

    /// Whether the recogniser's alternative transcriptions count, not just its best
    /// guess. This is less a loosening than using information already on offer.
    var allowsAlternatives: Bool { self != .strict }

    /// Whether spellings a step or two away from the answer count.
    var allowsNearSpellings: Bool { self == .lenient }
}
