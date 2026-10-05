import VocabularyDomain
import VocabularyUI

public extension HomeNavigation {
    /// Home as the app's root. Every kind of lesson is presented over the home stack.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void
    ) -> Self {
        HomeNavigation(
            didRequestMatching: presentMatching,
            didRequestSpeaking: presentSpeaking,
            didRequestFlashcards: presentFlashcards
        )
    }
}
