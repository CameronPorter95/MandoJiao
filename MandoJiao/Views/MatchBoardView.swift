import SwiftUI

struct MatchBoardView: View {
    let board: MatchBoard
    let onTap: (Tile) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(board.englishTiles)
            column(board.hanziTiles)
        }
    }

    private func column(_ tiles: [Tile]) -> some View {
        VStack(spacing: 12) {
            ForEach(tiles) { tile in
                WordTileView(
                    tile: tile,
                    pinyin: board.pinyin(for: tile),
                    isSelected: board.isSelected(tile),
                    isMatched: board.isMatched(tile),
                    isMissed: board.isMissed(tile)
                ) {
                    onTap(tile)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var board = MatchBoard(pairs: Array(SampleVocabulary.previewPairs.shuffled().prefix(5)))

    MatchBoardView(board: board) { tile in
        _ = board.tap(tile)
    }
    .padding()
}
