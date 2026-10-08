import CoreUI
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

    /// Carries out an effect that opens a lesson, deck or folder, and returns any other.
    func follow(_ effect: FolderDetailEffect) -> FolderDetailEffect? {
        switch effect {
        case .startLesson(let request, .matching): didRequestMatching(request)
        case .startLesson(let request, .flashcards): didRequestFlashcards(request)
        case .startLesson(let request, .speaking): didRequestSpeaking(request)
        case .openDeck(let id): didOpenDeck(id)
        case .openFolder(let id): didOpenFolder(id)
        case .showError: return effect
        }
        return nil
    }
}
