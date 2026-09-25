import Foundation

/// Screens pushed onto the home stack.
enum HomeDestination: Hashable {
    case library
    case deck(UUID)
    case settings
}

@MainActor
struct HomeNavigation {
    var didRequestMatching: (LessonRequest) -> Void
    var didRequestSpeaking: (LessonRequest) -> Void
}

@MainActor
struct DeckDetailNavigation {
    var didRequestMatching: (LessonRequest) -> Void
}
