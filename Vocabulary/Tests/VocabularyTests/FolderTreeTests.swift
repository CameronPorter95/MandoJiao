import Foundation
import Testing
import VocabularyTestSupport
@testable import VocabularyDomain

@Suite("Folders")
struct FolderTreeTests {
    private let vocabulary = Fixtures.nested

    @Test("a folder practises every word in every deck beneath it, once each, in order")
    func wordsBeneath() {
        #expect(vocabulary.words(in: Fixtures.hsk).map(\.english) == ["water", "tea", "book", "mobile phone", "green"])
        #expect(vocabulary.usableWordCount(in: Fixtures.level1) == 5)
        #expect(vocabulary.words(in: Fixtures.emptyFolder).isEmpty)
    }

    @Test("each level lists its own folders and decks, and a path runs from the top down")
    func levels() {
        #expect(vocabulary.folders(in: nil).map(\.name) == ["Starter", "HSK", "Empty"])
        #expect(vocabulary.decks(in: nil).isEmpty)
        #expect(vocabulary.decks(in: Fixtures.starter.id).map(\.name) == ["Full"])
        #expect(vocabulary.decks(in: Fixtures.level1.id).map(\.name) == ["Part 1", "Part 2"])
        #expect(vocabulary.folders(beneath: Fixtures.hsk.id).map(\.name) == ["Level 1"])
        #expect(vocabulary.decks(beneath: Fixtures.hsk.id).map(\.name) == ["Part 1", "Part 2"])
        #expect(vocabulary.path(to: Fixtures.level1.id).map(\.name) == ["HSK", "Level 1"])
    }

    @Test("a deck moves into any folder that exists, or within its own, but never to the top level")
    func movingDecks() {
        #expect(!vocabulary.canMoveDeck(Fixtures.part1.id, into: nil))
        #expect(vocabulary.canMoveDeck(Fixtures.part1.id, into: Fixtures.emptyFolder.id))
        #expect(vocabulary.canMoveDeck(Fixtures.part1.id, into: Fixtures.level1.id))
        #expect(!vocabulary.canMoveDeck(Fixtures.fullDeck.id, into: UUID()))
        #expect(!vocabulary.canMoveDeck(UUID(), into: nil))
    }

    @Test("a folder never moves into itself or beneath itself, but may reorder within its parent")
    func movingFolders() {
        #expect(!vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.hsk.id))
        #expect(!vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.level1.id))

        #expect(vocabulary.canMoveFolder(Fixtures.hsk.id, into: nil))
        #expect(vocabulary.canMoveFolder(Fixtures.level1.id, into: Fixtures.hsk.id))
        #expect(vocabulary.canMoveFolder(Fixtures.level1.id, into: nil))
        #expect(vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.emptyFolder.id))
    }

    @Test("a move places the item among its new siblings at the index given, or last")
    func order() {
        let reordered = vocabulary.movingFolder(Fixtures.emptyFolder.id, into: nil, at: 0)
        #expect(reordered.folders(in: nil).map(\.name) == ["Empty", "Starter", "HSK"])

        let nested = vocabulary.movingFolder(Fixtures.emptyFolder.id, into: Fixtures.hsk.id, at: 0)
        #expect(nested.folders(in: Fixtures.hsk.id).map(\.name) == ["Empty", "Level 1"])
        #expect(nested.folders(in: nil).map(\.name) == ["Starter", "HSK"])

        let decks = vocabulary.movingDeck(Fixtures.part2.id, into: Fixtures.level1.id, at: 0)
        #expect(decks.decks(in: Fixtures.level1.id).map(\.name) == ["Part 2", "Part 1"])

        let last = vocabulary.movingDeck(Fixtures.fullDeck.id, into: Fixtures.level1.id, at: nil)
        #expect(last.decks(in: Fixtures.level1.id).map(\.name) == ["Part 1", "Part 2", "Full"])
        #expect(last.decks(in: Fixtures.starter.id).isEmpty)

        #expect(vocabulary.movingFolder(Fixtures.hsk.id, into: Fixtures.level1.id, at: 0) == vocabulary)
    }
}
