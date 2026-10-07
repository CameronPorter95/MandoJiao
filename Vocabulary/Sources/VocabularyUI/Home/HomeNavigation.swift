import VocabularyDomain

@MainActor
public struct HomeNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didRequestSpeaking: (LessonRequest) -> Void
    public var didRequestFlashcards: (LessonRequest) -> Void
    public var didRequestTodayPlan: (TodayPlan) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void,
        didRequestFlashcards: @escaping (LessonRequest) -> Void,
        didRequestTodayPlan: @escaping (TodayPlan) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didRequestSpeaking = didRequestSpeaking
        self.didRequestFlashcards = didRequestFlashcards
        self.didRequestTodayPlan = didRequestTodayPlan
    }
}
