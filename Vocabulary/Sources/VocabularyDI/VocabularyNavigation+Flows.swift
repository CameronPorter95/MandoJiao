import VocabularyDomain
import VocabularyUI

public extension VocabularyNavigation {
    /// The home stack, composed from each screen's own constructor.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void
    ) -> Self {
        VocabularyNavigation(
            home: .app(presentMatching: presentMatching, presentSpeaking: presentSpeaking),
            deckDetail: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking),
            library: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking)
        )
    }
}
