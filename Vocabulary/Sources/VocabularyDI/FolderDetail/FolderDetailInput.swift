import Foundation

public struct FolderDetailInput {
    public let folderID: UUID
    public let minimumMatchingWords: Int

    public init(folderID: UUID, minimumMatchingWords: Int) {
        self.folderID = folderID
        self.minimumMatchingWords = minimumMatchingWords
    }
}
