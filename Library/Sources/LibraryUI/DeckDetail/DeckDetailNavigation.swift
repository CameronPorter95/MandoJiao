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
}
