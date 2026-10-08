import LibraryDomain
import ProgressDomain

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

    /// Carries out an effect that starts a lesson, and returns any other for the presenter.
    func follow(_ effect: HomeEffect) -> HomeEffect? {
        switch effect {
        case .requestMatching(let request): didRequestMatching(request)
        case .requestSpeaking(let request): didRequestSpeaking(request)
        case .requestFlashcards(let request): didRequestFlashcards(request)
        case .requestTodayPlan(let plan): didRequestTodayPlan(plan)
        case .showError: return effect
        }
        return nil
    }
}
