import Foundation
import VocabularyDomain

/// The lesson Home suggests for today: a theme, a line saying what it will do, and its steps
/// in order, drawing on several exercises. The mixed lesson turns each step into the real
/// exercise; this says only what each is for.
public nonisolated struct TodayPlan: Identifiable, Hashable, Sendable {
    public enum Theme: Hashable, Sendable {
        /// Meet a few unstarted words, then practise them, then review.
        case newWords
        /// Practise words whose strength is fading.
        case review
    }

    public enum Step: Hashable, Sendable {
        /// Show a word never answered, before it is asked: its Hanzi, pinyin and meanings.
        case teach(WordPair)
        /// One matching board of these.
        case match([WordPair])
        /// One flash card.
        case recall(WordPair, Recall)
    }

    /// What a flash card asks of a word.
    public enum Recall: Hashable, Sendable {
        /// Its Chinese shown, its meaning picked: for a word still being learnt.
        case recognise
        /// Its English shown, its Hanzi typed: for a word that is known well enough to.
        case produce
    }

    public let id: UUID
    public let theme: Theme
    public let title: String
    public let synopsis: String
    public let steps: [Step]
    /// The deck or folder its new words came from, marked practised when it is recorded.
    public let source: LessonSource?
    /// The rest of the vocabulary, for a flash card's wrong options.
    public let otherWords: [WordPair]

    public init(
        id: UUID = UUID(),
        theme: Theme,
        title: String,
        synopsis: String,
        steps: [Step],
        source: LessonSource?,
        otherWords: [WordPair]
    ) {
        self.id = id
        self.theme = theme
        self.title = title
        self.synopsis = synopsis
        self.steps = steps
        self.source = source
        self.otherWords = otherWords
    }
}

/// Chooses today's plan from how the vocabulary's strengths stand. Plain rules, tested, so
/// the choice can grow as more exercises and themes arrive.
public nonisolated enum TodayPlanner {
    /// New words met in one plan.
    public static let newWordCount = 5
    /// Words reviewed in one plan.
    public static let reviewLimit = 12
    /// This many fading words, or more, make the plan a review rather than new words: new
    /// words wait while old ones are slipping.
    public static let reviewThreshold = 8
    /// A word is fading below this chance of recall, FSRS's usual target.
    public static let dueRecall = 0.9

    /// `current` is what Home carries on with, where new words come from first. `boardSize` is
    /// a matching board's size, which Vocabulary does not own. Nil when there is nothing to
    /// learn or review.
    public static func suggest(
        vocabulary: Vocabulary,
        current: LessonSource?,
        settings: LessonSettings,
        boardSize: Int,
        now: Date
    ) -> TodayPlan? {
        let words = vocabulary.usableWords.forLessons(settings)
        let due = words
            .filter { $0.memory.lastAnsweredAt != nil && $0.memory.recall(at: now) < dueRecall }
            .sorted { $0.memory.recall(at: now) < $1.memory.recall(at: now) }
        let unstarted = { (pool: [Word]) in pool.filter { $0.band(at: now) == .new && !$0.isLearnt } }
        let fromCurrent = current.map { unstarted(vocabulary.words(in: $0).forLessons(settings).filter(\.isUsable)) } ?? []
        let newWords = Array((fromCurrent.isEmpty ? unstarted(words) : fromCurrent).prefix(newWordCount))
        let newSource = fromCurrent.isEmpty ? nil : current
        let otherWords = vocabulary.usableWords.pairs

        if due.count >= reviewThreshold || (newWords.isEmpty && !due.isEmpty) {
            let reviewed = Array(due.prefix(reviewLimit))
            let count = reviewed.count == 1 ? "1 word" : "\(reviewed.count) words"
            return TodayPlan(
                theme: .review,
                title: "Review",
                synopsis: "Practise \(count) you've met that are starting to fade.",
                steps: reviewed.map { review($0, at: now) },
                source: nil,
                otherWords: otherWords
            )
        }
        guard !newWords.isEmpty else { return nil }

        let pairs = newWords.map(\.pair)
        var steps = pairs.map(TodayPlan.Step.teach)
        if let board = board(for: pairs, from: words.map(\.pair), size: boardSize) {
            steps.append(.match(board))
        }
        steps += pairs.map { .recall($0, .recognise) }
        let reviewed = Array(due.prefix(reviewLimit - newWords.count))
        steps += reviewed.map { review($0, at: now) }

        let place = newSource.flatMap(vocabulary.name(of:)).map { " from \($0)" } ?? ""
        let count = newWords.count == 1 ? "1 new word" : "\(newWords.count) new words"
        let then = reviewed.isEmpty ? "" : ", then review \(reviewed.count) you've met before"
        return TodayPlan(
            theme: .newWords,
            title: "New words",
            synopsis: "Learn \(count)\(place)\(then).",
            steps: steps,
            source: newSource,
            otherWords: otherWords
        )
    }

    /// A weak word is recognised from its Chinese, a familiar or known one has its Hanzi typed.
    private static func review(_ word: Word, at now: Date) -> TodayPlan.Step {
        .recall(word.pair, word.band(at: now) >= .familiar ? .produce : .recognise)
    }

    /// The new words, padded to a board with others sharing no Hanzi or meaning with any on it,
    /// since a board where a tile fits two partners cannot be solved. Nil with too few.
    private static func board(for words: [WordPair], from pool: [WordPair], size: Int) -> [WordPair]? {
        var board: [WordPair] = []
        for candidate in words + pool where board.count < size {
            let clashes = board.contains { $0.hanzi == candidate.hanzi || $0.sharesMeaning(with: candidate) }
            if !clashes { board.append(candidate) }
        }
        return board.count == size ? board : nil
    }
}
