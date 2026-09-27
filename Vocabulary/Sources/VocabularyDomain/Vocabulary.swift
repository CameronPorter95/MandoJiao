import Foundation

/// Every word and deck, as one snapshot.
public nonisolated struct Vocabulary: Equatable, Sendable {
    public var words: [Word]
    public var decks: [DeckSummary]

    public init(words: [Word], decks: [DeckSummary]) {
        self.words = words
        self.decks = decks
    }

    public static let empty = Vocabulary(words: [], decks: [])

    public var usableWords: [Word] { words.filter(\.isUsable) }

    /// Words carrying outstanding mistakes, worst first, then most recently missed.
    public var mistakeWords: [Word] {
        usableWords
            .filter { $0.missCount > 0 }
            .sorted {
                ($0.missCount, $0.lastMissedAt ?? .distantPast)
                    > ($1.missCount, $1.lastMissedAt ?? .distantPast)
            }
    }

    public func deck(id: UUID) -> DeckSummary? {
        decks.first { $0.id == id }
    }

    /// In the deck's own order.
    public func words(in deck: DeckSummary) -> [Word] {
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return deck.wordIDs.compactMap { byID[$0] }
    }

    public func usableWordCount(in deck: DeckSummary) -> Int {
        words(in: deck).filter(\.isUsable).count
    }
}
