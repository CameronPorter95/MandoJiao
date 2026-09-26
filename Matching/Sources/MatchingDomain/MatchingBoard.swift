import Foundation
import VocabularyDomain

public enum TileSide: String, Hashable {
    case english
    case hanzi
}

public struct Tile: Identifiable, Hashable {
    public let pairID: UUID
    public let side: TileSide
    public let text: String

    public init(pairID: UUID, side: TileSide, text: String) {
        self.pairID = pairID
        self.side = side
        self.text = text
    }

    public var id: String { "\(side.rawValue)-\(pairID.uuidString)" }
}

public enum TapResult: Equatable {
    /// Nothing was selected, now this tile is.
    case selected
    /// The already-selected tile was tapped again.
    case deselected
    /// Selection moved to another tile on the same side.
    case switched
    /// `step` is 0-based: the first match of the board is step 0.
    /// `wasMissedEarlier` is true when this pair had already been guessed wrong
    /// on this board, so a clean solve can be told apart from a recovery.
    case matched(step: Int, boardComplete: Bool, wasMissedEarlier: Bool)
    /// Both tiles of a wrong guess. A miss implicates both words, since the
    /// two were confused for each other.
    case missed(tiles: [Tile])
    /// Tap landed on an already-matched tile.
    case ignored
}

/// One exercise: five pairs, two shuffled columns, no timers.
///
/// Resolution is immediate on the second tap, from either side, so matches can
/// be fired off back to back.
public struct MatchingBoard: Equatable {
    public let pairs: [WordPair]
    public let englishTiles: [Tile]
    public let hanziTiles: [Tile]

    public private(set) var matchedPairIDs: Set<UUID> = []
    public private(set) var selected: Tile?
    /// Tiles that were part of the most recent wrong guess, for the shake.
    /// Cleared on the next tap.
    public private(set) var missedTileIDs: Set<String> = []
    /// Every pair guessed wrong on this board, kept for the whole exercise.
    public private(set) var missedPairIDs: Set<UUID> = []

    public init(pairs: [WordPair]) {
        self.pairs = pairs
        self.englishTiles = pairs
            .map { Tile(pairID: $0.id, side: .english, text: $0.english) }
            .shuffled()
        self.hanziTiles = pairs
            .map { Tile(pairID: $0.id, side: .hanzi, text: $0.hanzi) }
            .shuffled()
    }

    public var isComplete: Bool { matchedPairIDs.count == pairs.count }

    public var matchedCount: Int { matchedPairIDs.count }

    public func isMatched(_ tile: Tile) -> Bool { matchedPairIDs.contains(tile.pairID) }

    public func isSelected(_ tile: Tile) -> Bool { selected?.id == tile.id }

    public func isMissed(_ tile: Tile) -> Bool { missedTileIDs.contains(tile.id) }

    public func pinyin(for tile: Tile) -> String? {
        pairs.first { $0.id == tile.pairID }?.pinyin
    }

    public mutating func tap(_ tile: Tile) -> TapResult {
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
            return .matched(
                step: matchedPairIDs.count - 1,
                boardComplete: isComplete,
                wasMissedEarlier: missedPairIDs.contains(tile.pairID)
            )
        }

        selected = nil
        missedTileIDs = [current.id, tile.id]
        missedPairIDs.insert(current.pairID)
        missedPairIDs.insert(tile.pairID)
        return .missed(tiles: [current, tile])
    }
}
