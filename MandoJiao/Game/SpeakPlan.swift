import Foundation

/// A speech drill: one card per word, in the order given.
struct SpeakPlan: Identifiable, Hashable {
    let id: UUID
    let title: String
    let cards: [WordPair]

    init(id: UUID = UUID(), title: String, cards: [WordPair]) {
        self.id = id
        self.title = title
        self.cards = cards
    }

    var cardCount: Int { cards.count }
}

enum SpeakLessonBuilder {
    static let maxCards = 20
    static let attemptsPerCard = 3

    /// One card per word, no repeats, keeping the pool's order so the worst offenders
    /// come first.
    ///
    /// Unlike `LessonBuilder`, a single word is enough for a lesson. Dropping the
    /// five-at-a-time floor is the point of this exercise: the matching board had to pad
    /// a short mistakes list with unrelated words to fill a round.
    static func makeLesson(title: String, from pool: [WordPair]) -> SpeakPlan? {
        var seen = Set<String>()
        let cards = pool.filter { pair in
            let hanzi = pair.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
            let english = pair.english.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hanzi.isEmpty, !english.isEmpty else { return false }
            return seen.insert(hanzi).inserted
        }

        guard !cards.isEmpty else { return nil }
        return SpeakPlan(title: title, cards: Array(cards.prefix(maxCards)))
    }
}
