import VocabularyDomain
import VocabularyUI

public extension DeckDetailNavigation {
    /// A deck opened from the library. Its lesson is presented over the whole app, so the deck
    /// is still there underneath when the lesson closes.
    static func app(presentMatching: @escaping (LessonRequest) -> Void) -> Self {
        DeckDetailNavigation(didRequestMatching: presentMatching)
    }
}
