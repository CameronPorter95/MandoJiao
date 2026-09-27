import Foundation

public struct FolderDetailInput {
    /// Nil for the decks at the top level.
    public let folderID: UUID?
    public let minimumMatchingWords: Int
    /// The deck open in the library's next column, if any.
    public let openDeck: UUID?

    public init(folderID: UUID?, minimumMatchingWords: Int, openDeck: UUID?) {
        self.folderID = folderID
        self.minimumMatchingWords = minimumMatchingWords
        self.openDeck = openDeck
    }
}
