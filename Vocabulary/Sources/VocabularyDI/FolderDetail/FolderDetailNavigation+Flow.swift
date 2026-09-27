import Foundation
import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder in the library's middle column. A deck it opens goes in the next column; a
    /// folder it opens takes its place, and is highlighted in the sidebar.
    static func library(
        presentMatching: @escaping (LessonRequest) -> Void,
        openDeck: @escaping (UUID) -> Void,
        openFolder: @escaping (UUID) -> Void
    ) -> Self {
        FolderDetailNavigation(didRequestMatching: presentMatching, didOpenDeck: openDeck, didOpenFolder: openFolder)
    }
}
