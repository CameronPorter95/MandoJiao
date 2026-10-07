import VocabularyDomain
import VocabularyUI

public extension VocabularyNavigation {
    /// The library's stacks, composed from each screen's own constructor.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void
    ) -> Self {
        VocabularyNavigation(
            deckDetail: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking),
            library: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking)
        )
    }
}
