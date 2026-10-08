import LibraryDomain
import LibraryUI

public extension LibraryNavigation {
    /// The library's stacks, composed from each screen's own constructor.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void
    ) -> Self {
        LibraryNavigation(
            deckDetail: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking),
            libraryTab: .app(presentMatching: presentMatching, presentFlashcards: presentFlashcards, presentSpeaking: presentSpeaking)
        )
    }
}
