import Foundation

/// Every word and deck, as one snapshot.
nonisolated struct Vocabulary: Equatable, Sendable {
    var words: [Word]
    var decks: [DeckSummary]

    static let empty = Vocabulary(words: [], decks: [])

    var usableWords: [Word] { words.filter(\.isUsable) }

    /// Words carrying outstanding mistakes, worst first, then most recently missed.
    var mistakeWords: [Word] {
        usableWords
            .filter { $0.missCount > 0 }
            .sorted {
                ($0.missCount, $0.lastMissedAt ?? .distantPast)
                    > ($1.missCount, $1.lastMissedAt ?? .distantPast)
            }
    }

    func deck(id: UUID) -> DeckSummary? {
        decks.first { $0.id == id }
    }

    /// In the deck's own order.
    func words(in deck: DeckSummary) -> [Word] {
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return deck.wordIDs.compactMap { byID[$0] }
    }

    func usableWordCount(in deck: DeckSummary) -> Int {
        words(in: deck).filter(\.isUsable).count
    }
}
