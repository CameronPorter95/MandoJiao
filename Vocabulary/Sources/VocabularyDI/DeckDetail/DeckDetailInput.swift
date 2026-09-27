import Foundation
import VocabularyDomain

public struct DeckDetailInput {
    public let deckID: UUID
    public let minimumMatchingWords: Int
    /// Shown until the deck's own subscription delivers, so its name is there at once.
    public let vocabulary: Vocabulary

    public init(deckID: UUID, minimumMatchingWords: Int, vocabulary: Vocabulary = .empty) {
        self.deckID = deckID
        self.minimumMatchingWords = minimumMatchingWords
        self.vocabulary = vocabulary
    }
}
