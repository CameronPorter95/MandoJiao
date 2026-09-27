import VocabularyDomain

@MainActor
public struct DeckDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void

    public init(didRequestMatching: @escaping (LessonRequest) -> Void) {
        self.didRequestMatching = didRequestMatching
    }
}
