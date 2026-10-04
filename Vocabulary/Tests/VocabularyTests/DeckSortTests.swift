import Foundation
import Testing
import VocabularyTestSupport
@testable import VocabularyDomain

@Suite("Deck sort")
struct DeckSortTests {
    private let folder = UUID()

    private func deck(_ name: String, created: TimeInterval, edited: TimeInterval, words: [Word]) -> DeckSummary {
        DeckSummary(
            id: UUID(), name: name,
            createdAt: Date(timeIntervalSince1970: created),
            editedAt: Date(timeIntervalSince1970: edited),
            wordIDs: words.map(\.id), folderID: folder
        )
    }

    private var vocabulary: Vocabulary {
        Vocabulary(words: Fixtures.words, decks: [
            deck("Beta", created: 1, edited: 30, words: [Fixtures.water]),
            deck("alpha", created: 3, edited: 10, words: [Fixtures.water, Fixtures.tea, Fixtures.book]),
            deck("Gamma 10", created: 2, edited: 20, words: [Fixtures.water, Fixtures.tea]),
            deck("Gamma 2", created: 4, edited: 20, words: [Fixtures.water, Fixtures.tea]),
        ])
    }

    private func names(_ field: DeckSort.Field, ascending: Bool) -> [String] {
        vocabulary.decks(in: folder, sortedBy: DeckSort(field: field, ascending: ascending)).map(\.name)
    }

    @Test("dates sort latest first by default, and ties fall back to the title")
    func dates() {
        #expect(DeckSort.default == DeckSort(field: .dateEdited, ascending: false))
        #expect(names(.dateEdited, ascending: false) == ["Beta", "Gamma 2", "Gamma 10", "alpha"])
        #expect(names(.dateCreated, ascending: true) == ["Beta", "Gamma 10", "alpha", "Gamma 2"])
    }

    @Test("titles sort ignoring case, with numbers compared as numbers")
    func titles() {
        #expect(names(.title, ascending: true) == ["alpha", "Beta", "Gamma 2", "Gamma 10"])
        #expect(names(.title, ascending: false) == ["Gamma 10", "Gamma 2", "Beta", "alpha"])
    }

    @Test("size counts usable words, largest first by default")
    func size() {
        #expect(names(.size, ascending: false) == ["alpha", "Gamma 2", "Gamma 10", "Beta"])
    }

    @Test("changing a deck's words marks it edited")
    func editing() {
        let before = deck("Beta", created: 1, edited: 1, words: [])
        let after = before.settingMembership(of: Fixtures.water.id, to: true)
        #expect(after.editedAt > before.editedAt)
        #expect(after.createdAt == before.createdAt)
    }
}
