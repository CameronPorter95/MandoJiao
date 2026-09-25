import Foundation
import VocabularyDomain

/// Screens pushed onto the home stack.
public enum HomeDestination: Hashable {
    case library
    case deck(UUID)
    case settings
}

@MainActor
public struct HomeNavigation {
    public var didRequestMatching: (LessonRequest) -> Void
    public var didRequestSpeaking: (LessonRequest) -> Void

    public init(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void
    ) {
        self.didRequestMatching = didRequestMatching
        self.didRequestSpeaking = didRequestSpeaking
    }
}

@MainActor
public struct DeckDetailNavigation {
    public var didRequestMatching: (LessonRequest) -> Void

    public init(didRequestMatching: @escaping (LessonRequest) -> Void) {
        self.didRequestMatching = didRequestMatching
    }
}
