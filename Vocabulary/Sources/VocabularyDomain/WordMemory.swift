import Foundation

/// How strongly a word is remembered, a word's strength band, shown instead of a number.
public nonisolated enum StrengthBand: Int, Comparable, CaseIterable, Sendable {
    /// Never answered.
    case new
    case learning
    case familiar
    case known

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .familiar: "Familiar"
        case .known: "Known"
        }
    }
}

public nonisolated extension Array where Element == Word {
    /// How many are in each band now. Bands with none are left out.
    func bandCounts(at now: Date) -> [StrengthBand: Int] {
        reduce(into: [:]) { counts, word in counts[word.band(at: now), default: 0] += 1 }
    }
}

/// What the app believes about remembering one word, worked out from its answers.
///
/// A simplified FSRS, the model modern spaced repetition uses. `stability` is how many days
/// until the chance of recalling the word falls to 90%; recall then fades on FSRS's power
/// curve. A right answer grows stability, by more the more the word had faded, so a word
/// answered twice in one lesson gains almost nothing the second time. A wrong one cuts it.
///
/// The constants are FSRS's published defaults where it has one, with difficulty held at
/// the middle, and judged otherwise: how far each exercise counts, and the band edges.
/// None is fitted to this app's answers, which did not exist when it was written. Every
/// answer is kept, so the model can be replayed over them once there are enough to tune it.
public nonisolated struct WordMemory: Hashable, Sendable {
    /// Days until recall falls to 90%. Zero for a word never answered.
    public var stability: Double
    public var lastAnsweredAt: Date?
    /// When it was marked learnt, nil if it is not.
    public var learntAt: Date?

    public init(stability: Double = 0, lastAnsweredAt: Date? = nil, learntAt: Date? = nil) {
        self.stability = stability
        self.lastAnsweredAt = lastAnsweredAt
        self.learntAt = learntAt
    }

    public static let new = WordMemory()

    public var isLearnt: Bool { learntAt != nil }

    /// The chance of recalling it now, 0 for a word never answered.
    public func recall(at now: Date) -> Double {
        guard let lastAnsweredAt, stability > 0 else { return 0 }
        let days = max(0, now.timeIntervalSince(lastAnsweredAt) / 86_400)
        return 1 / (1 + days / (9 * stability))
    }

    /// Known and Familiar need the word still likely to be recalled now, so one left too
    /// long slips back a band.
    public func band(at now: Date) -> StrengthBand {
        guard lastAnsweredAt != nil else { return .new }
        let recall = recall(at: now)
        if stability >= Self.knownStability, recall >= 0.8 { return .known }
        if stability >= Self.familiarStability, recall >= 0.7 { return .familiar }
        return .learning
    }

    /// Learnt puts it at Known: three weeks' stability or more, as if answered now. It fades
    /// from there like any word.
    public func markedLearnt(at date: Date) -> WordMemory {
        WordMemory(stability: max(stability, Self.learntStability), lastAnsweredAt: date, learntAt: date)
    }

    /// No longer learnt, keeping whatever strength it has.
    public func unmarkedLearnt() -> WordMemory {
        WordMemory(stability: stability, lastAnsweredAt: lastAnsweredAt, learntAt: nil)
    }

    public func answered(_ answer: Answer, at date: Date) -> WordMemory {
        let weight = Self.weight(of: answer)
        let next: Double
        if lastAnsweredAt == nil || stability <= 0 {
            next = answer.isCorrect
                ? max(Self.floor, Self.firstStability * weight * (Self.isHard(answer) ? 0.5 : 1))
                : Self.floor
        } else if answer.isCorrect {
            let recall = recall(at: date)
            let growth = exp(1.49) * (11 - Self.difficulty) * pow(stability, -0.14) * (exp(0.94 * (1 - recall)) - 1)
            next = stability * (1 + growth * weight * (Self.isHard(answer) ? 0.5 : 1))
        } else {
            let recall = recall(at: date)
            let lapsed = 2.18 * pow(Self.difficulty, -0.05) * (pow(stability + 1, 0.34) - 1) * exp(1.26 * (1 - recall))
            let forgotten = max(Self.floor, min(stability, lapsed))
            next = stability - (stability - forgotten) * Self.lapseWeight(of: answer)
        }
        return WordMemory(stability: next, lastAnsweredAt: date, learntAt: learntAt)
    }

    // MARK: - Constants

    static let familiarStability = 7.0
    static let knownStability = 21.0
    static let learntStability = 30.0
    /// A first right answer typed: three days, as FSRS's first "good" review roughly gives.
    static let firstStability = 3.0
    /// Never less than a few hours.
    static let floor = 0.3
    /// FSRS's difficulty, held at the middle of its 1 to 10 scale.
    static let difficulty = 5.0

    /// How far an answer counts as recall. Typing the Hanzi recalls the word outright.
    /// Reading aloud recalls how it is said from its characters. Picking from options and
    /// matching only recognise it, and a matching board's last pair solves itself.
    static func weight(of answer: Answer) -> Double {
        switch answer.exercise {
        case .flashcardTyped: 1.0
        case .speaking: 0.8
        case .flashcardPicked: 0.5
        case .matching: 0.3
        }
    }

    /// How far a wrong answer counts. A wrong pair on a matching board counts against both
    /// words, though only one may be unknown, so it counts for half.
    static func lapseWeight(of answer: Answer) -> Double {
        answer.exercise == .matching ? 0.5 : 1
    }

    /// Right after wrong tries. Not for speaking, where up to three tries exist because the
    /// recogniser mishears single words, so spending them is not evidence of not knowing.
    static func isHard(_ answer: Answer) -> Bool {
        answer.wrongAttempts > 0 && answer.exercise != .speaking
    }
}
