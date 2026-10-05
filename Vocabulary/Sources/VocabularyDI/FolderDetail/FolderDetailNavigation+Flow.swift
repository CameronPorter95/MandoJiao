import Foundation
import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder in the library's stack. Decks and folders it opens are pushed over it.
    static func library(
        presentMatching: @escaping (LessonRequest) -> Void,
        presentFlashcards: @escaping (LessonRequest) -> Void,
        presentSpeaking: @escaping (LessonRequest) -> Void,
        openDeck: @escaping (UUID) -> Void,
        openFolder: @escaping (UUID) -> Void
    ) -> Self {
        FolderDetailNavigation(
            didRequestMatching: presentMatching,
            didRequestFlashcards: presentFlashcards,
            didRequestSpeaking: presentSpeaking,
            didOpenDeck: openDeck,
            didOpenFolder: openFolder
        )
    }
}
