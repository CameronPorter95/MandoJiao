import Foundation

/// What a deck or folder can be practised with, from its Start lesson menu.
enum LessonExercise: CaseIterable, Equatable, Sendable {
    case matching
    case flashcards
    case speaking

    var title: String {
        switch self {
        case .matching: "Match pairs"
        case .flashcards: "Flash cards"
        case .speaking: "Read aloud"
        }
    }

    var systemImage: String {
        switch self {
        case .matching: "square.grid.2x2"
        case .flashcards: "rectangle.on.rectangle"
        case .speaking: "mic"
        }
    }

    /// A matching board needs `matching` words to fill; one is enough for a card.
    func minimumWords(matching: Int) -> Int {
        self == .matching ? matching : 1
    }
}
