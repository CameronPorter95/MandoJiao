import VocabularyDomain
import VocabularyUI

public extension VocabularyNavigation {
    /// The home stack, composed from each screen's own constructor.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentTodayPlan: @escaping (TodayPlan) -> Void
    ) -> Self {
        VocabularyNavigation(
            home: .app(
                presentMatching: presentMatching, presentSpeaking: presentSpeaking,
                presentFlashcards: presentFlashcards, presentTodayPlan: presentTodayPlan
            ),
            deckDetail: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking),
            library: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking)
        )
    }
}
