import Foundation
import VocabularyDomain

/// One word, shown one way and answered one way. The app chooses both, not the learner.
public nonisolated struct Flashcard: Identifiable, Hashable, Sendable {
    /// How the card is answered.
    public enum Format: Hashable, Sendable {
        /// Typed: English for a card showing Chinese, Hanzi for one showing English.
        case typed
        /// Picked from these, the word among them, in the order shown.
        case picked(options: [WordPair])
    }

    public let word: WordPair
    /// `.chineseToEnglish` or `.englishToChinese`.
    public let direction: Answer.Direction
    public let format: Format
    /// Other Hanzi a typed answer to a card showing English may give: words in the lesson
    /// sharing one of this word's meanings, which the English alone cannot tell apart.
    public let alsoAccepted: [String]

    public init(word: WordPair, direction: Answer.Direction, format: Format, alsoAccepted: [String] = []) {
        self.word = word
        self.direction = direction
        self.format = format
        self.alsoAccepted = alsoAccepted
    }

    public var id: UUID { word.id }

    public var showsChinese: Bool { direction == .chineseToEnglish }

    /// The exercise its answer is recorded under.
    public var exercise: Answer.Exercise {
        switch format {
        case .typed: .flashcardTyped
        case .picked: .flashcardPicked
        }
    }
}

/// A flash card lesson: one card per word.
public nonisolated struct FlashcardPlan: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let cards: [Flashcard]

    public init(id: UUID = UUID(), title: String, cards: [Flashcard]) {
        self.id = id
        self.title = title
        self.cards = cards
    }

    public var cardCount: Int { cards.count }
}

public nonisolated enum FlashcardPlanBuilder {
    public static let maxCards = 20
    /// Including the word itself.
    public static let optionCount = 4

    /// One card per word with Hanzi and a meaning, in a random order, its direction chosen
    /// at random.
    ///
    /// A card showing Chinese is always picked from options. Typed, its English was marked
    /// wrong too often when right: "leave work" for 下班, a wording of 了's "completed action
    /// marker", or 分's "minute", a sense the dictionary has and the word did not keep. No
    /// rule short of judging the meaning fixes that, and picking tests understanding it just
    /// as well. A card showing English is typed or picked at random: Hanzi is right or not.
    ///
    /// Wrong options come from the lesson and `otherWords`, never sharing the word's Hanzi or
    /// a meaning, since one that also fits would mark a right pick wrong. With too few, a card
    /// that would show Chinese shows English and is typed instead.
    ///
    /// A single word is enough for a lesson, as for speaking.
    public static func makeLesson(
        title: String,
        from pool: [WordPair],
        otherWords: [WordPair] = [],
        maxCards: Int = maxCards,
        using random: inout some RandomNumberGenerator
    ) -> FlashcardPlan? {
        var seen = Set<String>()
        let words = pool.filter { pair in
            let hanzi = pair.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
            let english = pair.english.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hanzi.isEmpty, !english.isEmpty else { return false }
            return seen.insert(hanzi).inserted
        }
        guard !words.isEmpty else { return nil }

        let everyWord = words + otherWords.filter { other in
            !other.hanzi.isEmpty && !other.english.isEmpty && !seen.contains(other.hanzi)
        }
        let chosen = words.shuffled(using: &random).prefix(max(1, maxCards))
        let cards = chosen.map { word in
            card(
                for: word, showingChinese: Bool.random(using: &random), picked: Bool.random(using: &random),
                choosingFrom: everyWord, using: &random
            )
        }
        return FlashcardPlan(title: title, cards: cards)
    }

    /// One card for a word. A card showing Chinese is always picked; one showing English is
    /// picked or typed as asked. Without three safe wrong options in `words`, it shows English
    /// and is typed. Words sharing a meaning with it are accepted for its Hanzi.
    public static func card(
        for word: WordPair,
        showingChinese: Bool,
        picked: Bool,
        choosingFrom words: [WordPair],
        using random: inout some RandomNumberGenerator
    ) -> Flashcard {
        let distractors = words.filter { $0.hanzi != word.hanzi && !$0.sharesMeaning(with: word) }
        let canPick = distractors.count >= optionCount - 1
        let direction: Answer.Direction = canPick && showingChinese ? .chineseToEnglish : .englishToChinese
        let format: Flashcard.Format
        if canPick, direction == .chineseToEnglish || picked {
            let options = Array(distractors.shuffled(using: &random).prefix(optionCount - 1)) + [word]
            format = .picked(options: options.shuffled(using: &random))
        } else {
            format = .typed
        }
        let alsoAccepted = words.filter { $0.hanzi != word.hanzi && $0.sharesMeaning(with: word) }.map(\.hanzi)
        return Flashcard(word: word, direction: direction, format: format, alsoAccepted: alsoAccepted)
    }

    public static func makeLesson(title: String, from pool: [WordPair], otherWords: [WordPair] = [], maxCards: Int = maxCards) -> FlashcardPlan? {
        var random = SystemRandomNumberGenerator()
        return makeLesson(title: title, from: pool, otherWords: otherWords, maxCards: maxCards, using: &random)
    }
}
