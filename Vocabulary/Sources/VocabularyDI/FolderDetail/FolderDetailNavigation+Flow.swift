import VocabularyDomain
import VocabularyUI

public extension FolderDetailNavigation {
    /// A folder opened from home or another folder. Its lesson is presented over the whole
    /// stack, so the folder is still there underneath when the lesson closes.
    static func app(presentMatching: @escaping (LessonRequest) -> Void) -> Self {
        FolderDetailNavigation(didRequestMatching: presentMatching)
    }
}
