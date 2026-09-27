import VocabularyDomain

@MainActor
public struct LibraryNavigation {
    public var didRequestMatching: (LessonRequest) -> Void

    public init(didRequestMatching: @escaping (LessonRequest) -> Void) {
        self.didRequestMatching = didRequestMatching
    }
}
