import Foundation

/// What a set of words can be practised with, one row each wherever it is offered. In Core
/// because the library and Home both offer them, and it names no feature type.
public enum LessonExercise: CaseIterable, Equatable, Sendable {
    case matching
    case flashcards
    case speaking

    public var title: String {
        switch self {
        case .matching: "Match pairs"
        case .flashcards: "Flash cards"
        case .speaking: "Read aloud"
        }
    }

    /// What it trains, under its name.
    public var detail: String {
        switch self {
        case .matching: "Recognise words in pairs"
        case .flashcards: "Recall one word at a time"
        case .speaking: "Say the Hanzi out loud"
        }
    }

    public var systemImage: String {
        switch self {
        case .matching: "square.grid.2x2"
        case .flashcards: "rectangle.on.rectangle"
        case .speaking: "mic"
        }
    }

    /// A matching board needs `matching` words to fill; one is enough for a card.
    public func minimumWords(matching: Int) -> Int {
        self == .matching ? matching : 1
    }
}
