import Foundation
import VocabularyDomain
import VocabularyUI

@MainActor
public struct FolderDetailInput {
    public let folderID: UUID
    public let minimumMatchingWords: Int
    public let layout: FolderLayout
    /// Shown until the folder's own subscription delivers, so its name is there at once.
    public let vocabulary: Vocabulary

    public init(folderID: UUID, minimumMatchingWords: Int, layout: FolderLayout, vocabulary: Vocabulary) {
        self.folderID = folderID
        self.minimumMatchingWords = minimumMatchingWords
        self.layout = layout
        self.vocabulary = vocabulary
    }
}
