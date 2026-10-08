import LibraryDomain
import LibraryUI

public extension LibraryTabNavigation {
    /// The library tab. A folder's lesson is presented over the whole app.
    static func app(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void
    ) -> Self {
        LibraryTabNavigation(
            didRequestMatching: presentMatching,
            didRequestFlashcards: presentFlashcards,
            didRequestSpeaking: presentSpeaking
        )
    }
}
