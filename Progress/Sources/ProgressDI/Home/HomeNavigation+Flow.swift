import LibraryDomain
import ProgressDomain
import ProgressUI

public extension HomeNavigation {
    /// Home as the app's root. Every kind of lesson is presented over the home stack.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentTodayPlan: @escaping (TodayPlan) -> Void
    ) -> Self {
        HomeNavigation(
            didRequestMatching: presentMatching,
            didRequestSpeaking: presentSpeaking,
            didRequestFlashcards: presentFlashcards,
            didRequestTodayPlan: presentTodayPlan
        )
    }
}
