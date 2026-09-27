import Foundation
import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder in the library's middle column. A deck it opens goes in the next column.
    static func library(
        presentMatching: @escaping (LessonRequest) -> Void,
        openDeck: @escaping (UUID) -> Void
    ) -> Self {
        FolderDetailNavigation(didRequestMatching: presentMatching, didOpenDeck: openDeck)
    }
}
