import Foundation
import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder in the library's stack. Decks and folders it opens are pushed over it.
    static func library(
        presentMatching: @escaping (LessonRequest) -> Void,
        openDeck: @escaping (UUID) -> Void,
        openFolder: @escaping (UUID) -> Void
    ) -> Self {
        FolderDetailNavigation(
            didRequestMatching: presentMatching,
            didOpenDeck: openDeck,
            didOpenFolder: openFolder
        )
    }
}
