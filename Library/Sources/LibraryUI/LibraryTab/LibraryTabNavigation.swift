import LibraryDomain

@MainActor
public struct LibraryTabNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    /// Not from the library itself, whose folder swipe starts matching, but handed on to
    /// the folders and decks it pushes.
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
    func follow(_ effect: LibraryEffect) -> LibraryEffect? {
        guard case .requestMatching(let request) = effect else { return effect }
        didRequestMatching(request)
        return nil
    }
}
