import Foundation
import VocabularyUI

@MainActor
public struct FolderDetailInput {
    public let folderID: UUID
    public let minimumMatchingWords: Int
    public let expansion: FolderExpansion

    public init(folderID: UUID, minimumMatchingWords: Int, expansion: FolderExpansion) {
        self.folderID = folderID
        self.minimumMatchingWords = minimumMatchingWords
        self.expansion = expansion
    }
}
