import Foundation

public struct DeckDetailInput {
    public let deckID: UUID
    public let minimumMatchingWords: Int

    public init(deckID: UUID, minimumMatchingWords: Int) {
        self.deckID = deckID
        self.minimumMatchingWords = minimumMatchingWords
    }
}
