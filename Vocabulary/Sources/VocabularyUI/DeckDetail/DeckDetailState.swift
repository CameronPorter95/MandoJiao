import Foundation
import VocabularyDomain

struct DeckDetailState: Equatable {
    let deckID: UUID
    let minimumMatchingWords: Int
    var vocabulary: Vocabulary = .empty
    /// Nil until the deck first loads, then whatever has been typed.
    var name: String?
    var searchText = ""

    var deck: DeckSummary? { vocabulary.deck(id: deckID) }
    var title: String { (name ?? "").isEmpty ? "Deck" : name ?? "" }

    var filteredWords: [Word] {
        vocabulary.words.sorted { $0.english < $1.english }.filter { $0.matches(searchText) }
    }

    var selectedCount: Int { deck.map(vocabulary.usableWordCount(in:)) ?? 0 }
    var canStartLesson: Bool { selectedCount >= minimumMatchingWords }

    func isIncluded(_ wordID: UUID) -> Bool {
        deck?.wordIDs.contains(wordID) ?? false
    }
}

enum DeckDetailAction: Equatable {
    case appeared
    case disappeared
    case nameChanged(String)
    case searchChanged(String)
    case wordToggled(UUID)
    case startLessonTapped
}

enum DeckDetailEffect: Equatable, Sendable {
    case startLesson(LessonRequest)
    case showError(VocabularyError)
}
