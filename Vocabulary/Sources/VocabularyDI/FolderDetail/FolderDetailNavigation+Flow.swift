import Foundation
import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder in the library's stack. Decks, folders and word lists it opens are pushed
    /// over it.
    static func library(
        presentMatching: @escaping (LessonRequest) -> Void,
        openDeck: @escaping (UUID) -> Void,
        openFolder: @escaping (UUID) -> Void,
        openWords: @escaping (UUID) -> Void
    ) -> Self {
        FolderDetailNavigation(
            didRequestMatching: presentMatching,
            didOpenDeck: openDeck,
            didOpenFolder: openFolder,
            didOpenWords: openWords
        )
    }
}
