import Foundation

enum TileSide: String, Hashable {
    case english
    case hanzi
}

struct Tile: Identifiable, Hashable {
    let pairID: UUID
    let side: TileSide
    let text: String

    var id: String { "\(side.rawValue)-\(pairID.uuidString)" }
}

enum TapResult: Equatable {
    /// Nothing was selected, now this tile is.
    case selected
    /// The already-selected tile was tapped again.
    case deselected
    /// Selection moved to another tile on the same side.
    case switched
    /// `step` is 0-based: the first match of the board is step 0.
    case matched(step: Int, boardComplete: Bool)
    case missed(tileIDs: [String])
    /// Tap landed on an already-matched tile.
    case ignored
}

/// One exercise: five pairs, two shuffled columns, no timers.
///
/// Resolution is immediate on the second tap, from either side, so matches can
/// be fired off back to back.
struct MatchBoard {
    let pairs: [WordPair]
    let englishTiles: [Tile]
    let hanziTiles: [Tile]

    private(set) var matchedPairIDs: Set<UUID> = []
    private(set) var selected: Tile?
    /// Tiles that were part of the most recent wrong guess, for the shake.
    private(set) var missedTileIDs: Set<String> = []

    init(pairs: [WordPair]) {
        self.pairs = pairs
        self.englishTiles = pairs
            .map { Tile(pairID: $0.id, side: .english, text: $0.english) }
            .shuffled()
        self.hanziTiles = pairs
            .map { Tile(pairID: $0.id, side: .hanzi, text: $0.hanzi) }
            .shuffled()
    }

    var isComplete: Bool { matchedPairIDs.count == pairs.count }

    var matchedCount: Int { matchedPairIDs.count }

    func isMatched(_ tile: Tile) -> Bool { matchedPairIDs.contains(tile.pairID) }

    func isSelected(_ tile: Tile) -> Bool { selected?.id == tile.id }

    func isMissed(_ tile: Tile) -> Bool { missedTileIDs.contains(tile.id) }

    func pinyin(for tile: Tile) -> String? {
        pairs.first { $0.id == tile.pairID }?.pinyin
    }

    mutating func tap(_ tile: Tile) -> TapResult {
        guard !isMatched(tile) else { return .ignored }
        missedTileIDs = []

        guard let current = selected else {
            selected = tile
            return .selected
        }

        if current.id == tile.id {
            selected = nil
            return .deselected
        }

        if current.side == tile.side {
            selected = tile
            return .switched
        }

        if current.pairID == tile.pairID {
            matchedPairIDs.insert(tile.pairID)
            selected = nil
            return .matched(step: matchedPairIDs.count - 1, boardComplete: isComplete)
        }

        selected = nil
        missedTileIDs = [current.id, tile.id]
        return .missed(tileIDs: [current.id, tile.id])
    }
}
