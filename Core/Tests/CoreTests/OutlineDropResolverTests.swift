import Testing
@testable import CoreDesignSystem

/// New Folder, test, HSK > Level 1 > Part A, Empty. The same tree as the Notes screenshots.
@Suite("Outline drops")
nonisolated struct OutlineDropResolverTests {
    private let roots: [OutlineNode<String>] = [
        OutlineNode(id: "New Folder", title: "New Folder"),
        OutlineNode(id: "test", title: "test"),
        OutlineNode(id: "HSK", title: "HSK", children: [
            OutlineNode(id: "Level 1", title: "Level 1", children: [OutlineNode(id: "Part A", title: "Part A")]),
        ]),
        OutlineNode(id: "Empty", title: "Empty"),
    ]
    private let visible = ["New Folder", "test", "HSK", "Level 1", "Part A", "Empty"]

    private func move(_ item: String, _ drop: OutlineDrop<String>) -> OutlineMove<String>? {
        OutlineDropResolver.move(item, dropped: drop, in: roots)
    }

    @Test("dropping onto a folder nests the item as its last child, even an empty folder")
    func into() {
        #expect(move("test", .into("New Folder")) == OutlineMove(item: "test", parent: "New Folder", index: 0))
        #expect(move("test", .into("Level 1")) == OutlineMove(item: "test", parent: "Level 1", index: 1))
    }

    @Test("dropping in a gap joins the level of the row below, just before it")
    func before() {
        #expect(move("Part A", .before("test")) == OutlineMove(item: "Part A", parent: nil, index: 1))
        #expect(move("test", .before("Part A")) == OutlineMove(item: "test", parent: "Level 1", index: 0))
        #expect(move("New Folder", .before("Empty")) == OutlineMove(item: "New Folder", parent: nil, index: 2))
    }

    @Test("dropping below everything goes last at the top level")
    func atEnd() {
        #expect(move("Part A", .atEnd) == OutlineMove(item: "Part A", parent: nil, index: 4))
    }

    @Test("a drop that changes nothing, or would put a folder inside itself, is no move")
    func refused() {
        #expect(move("test", .before("HSK")) == nil)
        #expect(move("Empty", .atEnd) == nil)
        #expect(move("Part A", .into("Level 1")) == nil)
        #expect(move("HSK", .into("HSK")) == nil)
        #expect(move("HSK", .into("Part A")) == nil)
        #expect(move("HSK", .before("Level 1")) == nil)
    }

    @Test("a gap takes the row below it, skipping the dragged row and what is beneath it")
    func gaps() {
        let drop = { (gap: Int, item: String) in
            OutlineDropResolver.drop(atGap: gap, visible: visible, moving: item, in: roots)
        }
        #expect(drop(1, "Part A") == .before("test"))
        #expect(drop(4, "test") == .before("Part A"))
        #expect(drop(2, "HSK") == .before("Empty"))
        #expect(drop(3, "HSK") == .before("Empty"))
        #expect(drop(6, "test") == .atEnd)
    }
}
