import VocabularyDomain

@MainActor
public struct HomeNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didRequestSpeaking: (LessonRequest) -> Void
    public var didRequestFlashcards: (LessonRequest) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void,
        didRequestFlashcards: @escaping (LessonRequest) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didRequestSpeaking = didRequestSpeaking
        self.didRequestFlashcards = didRequestFlashcards
    }
}
