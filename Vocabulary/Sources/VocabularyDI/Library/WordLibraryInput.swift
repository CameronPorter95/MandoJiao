import Foundation
import VocabularyDomain
import VocabularyUI

@MainActor
public struct WordLibraryInput {
    /// Nil for every word in the library, or the folder whose decks' words are listed.
    public let folderID: UUID?
    /// The list's share of the library's layout, which the library owns.
    public let layout: WordListLayout
    /// Shown until the list's own subscription delivers.
    public let vocabulary: Vocabulary

    public init(folderID: UUID?, layout: WordListLayout, vocabulary: Vocabulary) {
        self.folderID = folderID
        self.layout = layout
        self.vocabulary = vocabulary
    }
}
