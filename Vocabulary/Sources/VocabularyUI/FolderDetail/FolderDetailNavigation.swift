import Foundation
import VocabularyDomain

@MainActor
public struct FolderDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didOpenDeck: (UUID) -> Void
    public var didOpenFolder: (UUID) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didOpenDeck: @escaping (UUID) -> Void,
        didOpenFolder: @escaping (UUID) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didOpenDeck = didOpenDeck
        self.didOpenFolder = didOpenFolder
    }
}
