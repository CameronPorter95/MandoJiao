import Testing
@testable import MandoJiao

@Suite("Matching board")
struct MatchBoardTests {
    private let pairs = [
        ("water", "水"), ("tea", "茶"), ("to eat", "吃"), ("to drink", "喝"), ("book", "书")
    ].map { WordPair(english: $0.0, hanzi: $0.1, pinyin: "") }

    private func makeBoard() -> MatchBoard { MatchBoard(pairs: pairs) }

    private func english(_ index: Int, on board: MatchBoard) -> Tile {
        board.englishTiles.first { $0.pairID == pairs[index].id }!
    }

    private func hanzi(_ index: Int, on board: MatchBoard) -> Tile {
        board.hanziTiles.first { $0.pairID == pairs[index].id }!
    }

    @Test("a board deals both columns and starts clean")
    func dealing() {
        let board = makeBoard()
        #expect(board.englishTiles.count == 5)
        #expect(board.hanziTiles.count == 5)
        #expect(board.englishTiles.allSatisfy { $0.side == .english })
        #expect(board.hanziTiles.allSatisfy { $0.side == .hanzi })
        #expect(board.missedPairIDs.isEmpty)
        #expect(!board.isComplete)
    }

    @Test("english first then hanzi matches")
    func matchFromEnglish() {
        var board = makeBoard()
        #expect(board.tap(english(0, on: board)) == .selected)
        #expect(
            board.tap(hanzi(0, on: board))
                == .matched(step: 0, boardComplete: false, wasMissedEarlier: false)
        )
        #expect(board.isMatched(english(0, on: board)))
        #expect(board.isMatched(hanzi(0, on: board)))
        #expect(board.selected == nil)
    }

    @Test("hanzi first then english also matches, so either side can start")
    func matchFromHanzi() {
        var board = makeBoard()
        #expect(board.tap(hanzi(1, on: board)) == .selected)
        #expect(
            board.tap(english(1, on: board))
                == .matched(step: 0, boardComplete: false, wasMissedEarlier: false)
        )
    }

    @Test("a wrong guess is recorded against both words")
    func missRecordsBothWords() {
        var board = makeBoard()
        _ = board.tap(english(2, on: board))
        let result = board.tap(hanzi(3, on: board))

        #expect(result == .missed(tiles: [english(2, on: board), hanzi(3, on: board)]))
        // Both, not just the first tapped: the two were confused for each other.
        #expect(board.missedPairIDs == Set([pairs[2].id, pairs[3].id]))
        #expect(board.selected == nil)
        #expect(board.isMissed(english(2, on: board)))
        #expect(board.isMissed(hanzi(3, on: board)))
        #expect(!board.isMatched(english(2, on: board)))
    }

    @Test("the shake flag is transient but the board's record is not")
    func shakeFlagClears() {
        var board = makeBoard()
        _ = board.tap(english(2, on: board))
        _ = board.tap(hanzi(3, on: board))
        #expect(board.missedTileIDs.count == 2)

        _ = board.tap(english(2, on: board))
        #expect(board.missedTileIDs.isEmpty)
        #expect(board.missedPairIDs.count == 2)
    }

    @Test("solving a pair that already went wrong is flagged as a recovery")
    func recoveryIsDistinguishable() {
        var board = makeBoard()
        _ = board.tap(english(2, on: board))
        _ = board.tap(hanzi(3, on: board))

        _ = board.tap(english(2, on: board))
        let result = board.tap(hanzi(2, on: board))

        #expect(result == .matched(step: 0, boardComplete: false, wasMissedEarlier: true))
        #expect(board.missedPairIDs.contains(pairs[2].id))
    }

    @Test("selection can be dropped or moved within a column")
    func selectionHandling() {
        var board = makeBoard()
        _ = board.tap(english(2, on: board))
        #expect(board.tap(english(2, on: board)) == .deselected)

        _ = board.tap(english(2, on: board))
        #expect(board.tap(english(3, on: board)) == .switched)
        #expect(board.isSelected(english(3, on: board)))
    }

    @Test("a matched tile stops responding")
    func matchedTilesAreInert() {
        var board = makeBoard()
        _ = board.tap(english(0, on: board))
        _ = board.tap(hanzi(0, on: board))
        #expect(board.tap(english(0, on: board)) == .ignored)
    }

    @Test("the last match reports the board complete")
    func completion() {
        var board = makeBoard()
        for index in 0..<4 {
            _ = board.tap(english(index, on: board))
            _ = board.tap(hanzi(index, on: board))
        }
        #expect(board.matchedCount == 4)
        #expect(!board.isComplete)

        _ = board.tap(hanzi(4, on: board))
        let result = board.tap(english(4, on: board))
        #expect(result == .matched(step: 4, boardComplete: true, wasMissedEarlier: false))
        #expect(board.isComplete)
    }
}
