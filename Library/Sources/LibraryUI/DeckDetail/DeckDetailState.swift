import CoreUI
import Foundation
import LibraryDomain

/// One deck: its own words, and, in a sheet over them, every word in the library to add.
struct DeckDetailState: Equatable {
    let deckID: UUID
    let minimumMatchingWords: Int
    var vocabulary: Vocabulary = .empty
    /// Nil until the deck first loads, then whatever has been typed.
    var name: String?
    /// Searches the deck's own words.
    var searchText = ""
    var isChoosingDestination = false
    var isAddingWords = false
    /// Searches the library's words in the sheet that adds them.
    var pickerSearchText = ""

    /// Read on every appearance.
    var lessonSettings: LessonSettings = .default

    var deck: DeckSummary? { vocabulary.deck(id: deckID) }
    var title: String { (name ?? "").isEmpty ? "Deck" : name ?? "" }

    /// Before any search, usable or not.
    var wordCount: Int { deck.map { vocabulary.words(in: $0).count } ?? 0 }

    /// Every word in it, before any search, for how their strengths are spread.
    var deckWords: [Word] { deck.map { vocabulary.words(in: $0) } ?? [] }

    var words: [Word] {
        guard let deck else { return [] }
        return vocabulary.words(in: deck, sortedBy: .default).filter { $0.matches(searchText) }
    }

    var pickerWords: [Word] {
        vocabulary.words(sortedBy: .default).filter { $0.matches(pickerSearchText) }
    }

    /// What a lesson from it draws, which leaves out learnt words when the settings say to.
    var lessonWords: [Word] { (deck.map { vocabulary.words(in: $0) } ?? []).forLessons(lessonSettings).filter(\.isUsable) }
    var selectedCount: Int { lessonWords.count }
    func canStart(_ exercise: LessonExercise) -> Bool {
        selectedCount >= exercise.minimumWords(matching: minimumMatchingWords)
    }

    var destinations: [MoveDestination] { vocabulary.destinations(forDeck: deckID) }
    /// Shown when there is nowhere to move to, so the row does not look broken.
    var moveUnavailableReason: String? {
        destinations.isEmpty ? "Make a folder first to move this deck into." : nil
    }

    func isIncluded(_ wordID: UUID) -> Bool {
        deck?.wordIDs.contains(wordID) ?? false
    }
}

enum DeckDetailAction: Equatable, Decodable {
    case appeared
    case disappeared
    case nameChanged(String)
    case searchChanged(String)
    case removeTapped(UUID)
    case addWordsTapped
    case addWordsDismissed
    case pickerSearchChanged(String)
    /// In the sheet: in the deck if it was not, out of it if it was.
    case wordToggled(UUID)
    case startLessonTapped(exercise: LessonExercise)
    case moveTapped
    case destinationChosen(UUID?)
    case moveCancelled
}

enum DeckDetailEffect: Equatable, Sendable {
    case startLesson(LessonRequest, LessonExercise)
    case showError(VocabularyError)
}
