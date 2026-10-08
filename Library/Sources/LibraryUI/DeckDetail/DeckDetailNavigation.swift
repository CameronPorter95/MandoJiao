import CoreUI
import LibraryDomain

@MainActor
public struct DeckDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didRequestFlashcards: (LessonRequest) -> Void
    public var didRequestSpeaking: (LessonRequest) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestFlashcards: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didRequestFlashcards = didRequestFlashcards
        self.didRequestSpeaking = didRequestSpeaking
    }

    /// Carries out an effect that starts a lesson, and returns any other for the presenter.
    func follow(_ effect: DeckDetailEffect) -> DeckDetailEffect? {
        guard case .startLesson(let request, let exercise) = effect else { return effect }
        switch exercise {
        case .matching: didRequestMatching(request)
        case .flashcards: didRequestFlashcards(request)
        case .speaking: didRequestSpeaking(request)
        }
        return nil
    }
}
