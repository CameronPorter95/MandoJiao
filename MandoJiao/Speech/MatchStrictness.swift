import Foundation

/// How forgiving answer checking is, from tightest to loosest.
///
/// Tones are ignored at every level, deliberately. A recogniser's tone output reflects
/// its own guess as much as the speaker's, so grading on it would fail people for
/// reasons they cannot see or correct.
///
/// The raw values are storage and the titles are display, so the labels can be reworded
/// without stranding anyone's saved setting.
enum MatchStrictness: String, CaseIterable, Identifiable, Sendable {
    case strict
    case balanced
    case relaxed
    case lenient

    /// Nonisolated so it can serve as a default argument, which is evaluated in the
    /// caller's context rather than this type's.
    nonisolated static let `default` = MatchStrictness.relaxed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: "Strict"
        case .balanced: "Standard"
        case .relaxed: "Relaxed"
        case .lenient: "Generous"
        }
    }

    var detail: String {
        switch self {
        case .strict:
            "The word spelled exactly, from the recogniser's first guess. It may sit inside a longer phrase."
        case .balanced:
            "Also accepts the recogniser's second guesses, and zhi for zhe, shi for she and the like."
        case .relaxed:
            "Also accepts one -ng ending for another, so cheng, chang and chong all count."
        case .lenient:
            "Also accepts zh for z, ch for c, sh for s, -ng for -n, and a syllable that is a letter or two out."
        }
    }

    /// Whether the recogniser's alternative transcriptions count, not just its best
    /// guess. This is less a loosening than using information already on offer.
    var allowsAlternatives: Bool { self != .strict }

    /// Whether the empty-rime vowel counts as interchangeable with -e: zhi against zhe,
    /// shi against she, zi against ze, and so on.
    ///
    /// Narrow and specific. Recognisers confuse exactly these, because the vowel in zhi
    /// and shi is not really an [i] at all, it is the consonant held on, and it sits
    /// acoustically close to -e.
    var allowsVowelConfusions: Bool { self != .strict }

    /// Whether the vowel in a syllable-final -ng counts as interchangeable, so -ang, -eng
    /// and -ong are one ending.
    ///
    /// The single most common thing to come back wrong from a learner saying a word
    /// correctly enough to be understood: 完成 transcribed as 晚昌 or 晚冲.
    var allowsNasalFinals: Bool { self == .relaxed || self == .lenient }

    /// Whether spellings a step or two away from the answer count. Implies everything
    /// above: there is no level that allows near spellings but not the rest.
    var allowsNearSpellings: Bool { self == .lenient }
}
