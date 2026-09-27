import VocabularyDomain
import VocabularyUI

public extension HomeNavigation {
    /// Home as the app's root. Both kinds of lesson are presented over the home stack.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void
    ) -> Self {
        HomeNavigation(didRequestMatching: presentMatching, didRequestSpeaking: presentSpeaking)
    }
}
