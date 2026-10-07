import LibraryDomain
import LibraryUI

public extension DeckDetailNavigation {
    /// A deck opened from the library. Its lesson is presented over the whole app, so the deck
    /// is still there underneath when the lesson closes.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void
    ) -> Self {
        DeckDetailNavigation(
            didRequestMatching: presentMatching,
            didRequestFlashcards: presentFlashcards,
            didRequestSpeaking: presentSpeaking
        )
    }
}
