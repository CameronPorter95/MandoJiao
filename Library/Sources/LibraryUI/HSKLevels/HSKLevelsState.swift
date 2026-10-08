import DictionaryDomain
import Foundation
import LibraryDomain

struct HSKLevelsState: Equatable {
    var vocabulary: Vocabulary = .empty
    /// Nil until the bundled list is read.
    var words: [HSKWord]?
    var installing: Set<Int> = []

    struct Level: Identifiable, Equatable {
        enum Status: Equatable {
            case notAdded
            /// Some of its decks were deleted.
            case missing(Int)
            case added
        }

        let level: Int
        let wordCount: Int
        let deckCount: Int
        let status: Status
        var id: Int { level }
        var name: String { HSK.levelName(level) }
    }

    var levels: [Level] {
        guard let words else { return [] }
        let present = Set(vocabulary.decks.compactMap(\.builtInKey))
        return HSK.levels.map { level in
            let wordCount = words.filter { $0.level == level }.count
            let deckCount = HSK.deckCount(forWords: wordCount)
            let missing = (1...deckCount).filter { !present.contains(HSK.deckKey(level, $0)) }.count
            let status: Level.Status = missing == 0 ? .added : missing == deckCount ? .notAdded : .missing(missing)
            return Level(level: level, wordCount: wordCount, deckCount: deckCount, status: status)
        }
    }
}

enum HSKLevelsAction: Equatable, Decodable {
    case appeared
    case disappeared
    case installTapped(level: Int)
    case doneTapped
}

enum HSKLevelsEffect: Equatable, Sendable {
    case dismiss
    case showError(VocabularyError)

    /// Carries out a dismissal, which the presenter owns, and returns any other effect.
    func followed(dismiss: () -> Void) -> HSKLevelsEffect? {
        guard self == .dismiss else { return self }
        dismiss()
        return nil
    }
}
