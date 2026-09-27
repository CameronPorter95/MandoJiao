import VocabularyDomain

@MainActor
public struct FolderDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void

    public init(didRequestMatching: @escaping (LessonRequest) -> Void) {
        self.didRequestMatching = didRequestMatching
    }
}
