import LibraryDomain
import ProgressDomain
import ProgressUI

public extension ProgressNavigation {
    /// The home tab, composed from each screen's own constructor.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentTodayPlan: @escaping (TodayPlan) -> Void
    ) -> Self {
        ProgressNavigation(home: .app(
            presentMatching: presentMatching, presentSpeaking: presentSpeaking,
            presentFlashcards: presentFlashcards, presentTodayPlan: presentTodayPlan
        ))
    }
}
