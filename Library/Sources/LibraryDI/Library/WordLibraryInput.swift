import Foundation
import LibraryDomain
import LibraryUI

@MainActor
public struct WordLibraryInput {
    /// Nil for every word in the library, or the folder whose decks' words are listed.
    public let folderID: UUID?
    /// The list's share of the library's layout, which the library owns.
    public let layout: WordListLayout
    /// What the screen searched has typed so far.
    public let searchText: String
    /// Shown until the list's own subscription delivers.
    public let vocabulary: Vocabulary
    public let dictionary: DictionaryAccess

    public init(folderID: UUID?, layout: WordListLayout, searchText: String, vocabulary: Vocabulary, dictionary: DictionaryAccess) {
        self.folderID = folderID
        self.layout = layout
        self.searchText = searchText
        self.vocabulary = vocabulary
        self.dictionary = dictionary
    }
}
