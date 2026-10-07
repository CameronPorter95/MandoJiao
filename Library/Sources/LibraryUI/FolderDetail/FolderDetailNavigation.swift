import Foundation
import LibraryDomain

@MainActor
public struct FolderDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didRequestFlashcards: (LessonRequest) -> Void
    public var didRequestSpeaking: (LessonRequest) -> Void
    public var didOpenDeck: (UUID) -> Void
    public var didOpenFolder: (UUID) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestFlashcards: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void,
        didOpenDeck: @escaping (UUID) -> Void,
        didOpenFolder: @escaping (UUID) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didRequestFlashcards = didRequestFlashcards
        self.didRequestSpeaking = didRequestSpeaking
        self.didOpenDeck = didOpenDeck
        self.didOpenFolder = didOpenFolder
    }
}
