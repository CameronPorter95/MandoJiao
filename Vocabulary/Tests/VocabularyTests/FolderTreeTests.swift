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
        #expect(vocabulary.folders(in: nil).map(\.name) == ["HSK", "Empty"])
        #expect(vocabulary.decks(in: nil).map(\.name) == ["Full"])
        #expect(vocabulary.decks(in: Fixtures.level1.id).map(\.name) == ["Part 1", "Part 2"])
        #expect(vocabulary.folders(beneath: Fixtures.hsk.id).map(\.name) == ["Level 1"])
        #expect(vocabulary.decks(beneath: Fixtures.hsk.id).map(\.name) == ["Part 1", "Part 2"])
        #expect(vocabulary.path(to: Fixtures.level1.id).map(\.name) == ["HSK", "Level 1"])
    }

    @Test("a deck moves into any folder or to the top level, but not where it already is")
    func movingDecks() {
        #expect(vocabulary.canMoveDeck(Fixtures.part1.id, into: nil))
        #expect(vocabulary.canMoveDeck(Fixtures.part1.id, into: Fixtures.emptyFolder.id))
        #expect(!vocabulary.canMoveDeck(Fixtures.part1.id, into: Fixtures.level1.id))
        #expect(!vocabulary.canMoveDeck(Fixtures.fullDeck.id, into: nil))
        #expect(!vocabulary.canMoveDeck(Fixtures.fullDeck.id, into: UUID()))
    }

    @Test("a folder never moves into itself, beneath itself, or where it already is")
    func movingFolders() {
        #expect(!vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.hsk.id))
        #expect(!vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.level1.id))
        #expect(!vocabulary.canMoveFolder(Fixtures.hsk.id, into: nil))
        #expect(!vocabulary.canMoveFolder(Fixtures.level1.id, into: Fixtures.hsk.id))

        #expect(vocabulary.canMoveFolder(Fixtures.level1.id, into: nil))
        #expect(vocabulary.canMoveFolder(Fixtures.hsk.id, into: Fixtures.emptyFolder.id))
    }
}
