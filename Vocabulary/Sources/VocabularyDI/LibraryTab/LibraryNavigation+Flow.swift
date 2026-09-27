import VocabularyDomain
import VocabularyUI

public extension LibraryNavigation {
    /// The library tab. A folder's lesson is presented over the whole app.
    static func app(presentMatching: @escaping (LessonRequest) -> Void) -> Self {
        LibraryNavigation(didRequestMatching: presentMatching)
    }
}
