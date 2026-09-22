import SwiftUI

struct MatchBoardView: View {
    let board: MatchBoard
    let showsPinyin: Bool
    let onTap: (Tile) -> Void

    var body: some View {
        // A Grid rather than two VStacks: a Hanzi tile carrying a line of
        // pinyin is taller than its English partner, and the rows have to stay
        // level when that happens.
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(zip(board.englishTiles, board.hanziTiles)), id: \.0.id) { english, hanzi in
                GridRow {
                    tile(english)
                    tile(hanzi)
                }
            }
        }
    }

    private func tile(_ tile: Tile) -> some View {
        WordTileView(
            tile: tile,
            pinyin: board.pinyin(for: tile),
            isSelected: board.isSelected(tile),
            isMatched: board.isMatched(tile),
            isMissed: board.isMissed(tile),
            showsPinyin: showsPinyin
        ) {
            onTap(tile)
        }
    }
}

#Preview {
    @Previewable @State var board = MatchBoard(pairs: Array(SampleVocabulary.previewPairs.shuffled().prefix(5)))
    @Previewable @State var showsPinyin = true

    VStack {
        Toggle("Show pinyin", isOn: $showsPinyin)
        MatchBoardView(board: board, showsPinyin: showsPinyin) { tile in
            _ = board.tap(tile)
        }
    }
    .padding()
}
