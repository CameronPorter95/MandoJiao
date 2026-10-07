import Foundation
import LibraryDomain
import LibraryUI

@MainActor
public struct FolderDetailInput {
    public let folderID: UUID
    public let minimumMatchingWords: Int
    public let layout: FolderLayout
    /// How the search's results are sorted, which the library owns.
    public let wordList: WordListLayout
    /// Shown until the folder's own subscription delivers, so its name is there at once.
    public let vocabulary: Vocabulary
    public let dictionary: DictionaryAccess

    public init(
        folderID: UUID,
        minimumMatchingWords: Int,
        layout: FolderLayout,
        wordList: WordListLayout,
        vocabulary: Vocabulary,
        dictionary: DictionaryAccess
    ) {
        self.folderID = folderID
        self.minimumMatchingWords = minimumMatchingWords
        self.layout = layout
        self.wordList = wordList
        self.vocabulary = vocabulary
        self.dictionary = dictionary
    }
}
