import LibraryDomain

@MainActor
public struct LibraryNavigation {
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
}
