import VocabularyDomain
import VocabularyUI

public extension DeckDetailNavigation {
    /// A deck opened from home. Its lesson is presented over the home stack, like home's own.
    static func app(presentMatching: @escaping (LessonRequest) -> Void) -> Self {
        DeckDetailNavigation(didRequestMatching: presentMatching)
    }
}
