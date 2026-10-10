import CoreUI
import Foundation
import PracticeDomain

extension MatchingViewModel {
    /// A tile is named by its text, English or Hanzi, as it shows on the board.
    public func driver(navigation: MatchingNavigation) -> ScreenDriver {
        ScreenDriver(
            name: "matching",
            actions: MatchingDriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: MatchingDriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .tileTapped(let text):
                    guard let tile = self.state.lesson?.board.tile(named: text) else { return }
                    self.send(.tileTapped(tile))
                case .pinyinToggled: self.send(.pinyinToggled)
                case .practiseAgainTapped: self.send(.practiseAgainTapped)
                case .closeTapped: self.send(.closeTapped)
                case .quitConfirmed: self.send(.quitConfirmed)
                case .quitCancelled: self.send(.quitCancelled)
                }
            },
            effects: effects,
            follow: navigation.follow,
            // As the ✕ does, so a lesson with answers to keep asks before it quits.
            back: {
                self.send(.closeTapped)
                return true
            },
            answer: { right in
                guard let lesson = self.state.lesson, !lesson.isFinished, !self.state.isConfirmingQuit else {
                    throw ScreenDriverError.cannotAnswer("no board is waiting for an answer")
                }
                let taps = try lesson.board.guess(right: right)
                for tile in taps { self.send(.tileTapped(tile)) }
                return MatchingBoard.describe(taps, right: right)
            }
        )
    }
}

extension MatchingStepViewModel {
    /// One board in a longer lesson. Its tiles are named as the matching lesson's are.
    public func driver() -> ScreenDriver {
        ScreenDriver(
            name: "matching step",
            actions: MatchingStepDriverAction.names,
            state: { self.lesson },
            summary: { "matching step  \($0.board.summary)" },
            send: { (action: MatchingStepDriverAction) in
                switch action {
                case .appeared: self.appeared()
                case .disappeared: break
                case .tileTapped(let text):
                    guard let tile = self.lesson.board.tile(named: text) else { return }
                    _ = self.tap(tile)
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 },
            answer: { right in
                let taps = try self.lesson.board.guess(right: right)
                for tile in taps { _ = self.tap(tile) }
                return MatchingBoard.describe(taps, right: right)
            }
        )
    }
}

/// The screen's actions, with a tile by its text rather than the board's own `Tile`.
enum MatchingDriverAction: Decodable {
    case appeared
    case tileTapped(tile: String)
    case pinyinToggled
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "tileTapped", "pinyinToggled", "practiseAgainTapped", "closeTapped", "quitConfirmed", "quitCancelled",
    ]
}

enum MatchingStepDriverAction: Decodable {
    case appeared
    case disappeared
    case tileTapped(tile: String)

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = ["appeared", "disappeared", "tileTapped"]
}

extension MatchingState {
    var summary: String {
        guard let lesson else { return "matching  no lesson" }
        guard !lesson.isFinished else { return "matching  finished  misses: \(lesson.missCount)" }
        var parts = ["matching", "board \(lesson.exerciseNumber)/\(lesson.plan.exerciseCount)", lesson.board.summary]
        if isConfirmingQuit { parts.append("confirming quit") }
        return parts.joined(separator: "  ")
    }
}

extension MatchingBoard {
    /// Each side's tiles in the order shown, a matched one marked ✓, the last wrong guess's ✗
    /// as they shake, and the selected one *. Hanzi carry their pinyin whether or not the board
    /// shows it, so an answer can be worked out.
    var summary: String {
        func line(_ tiles: [Tile]) -> String {
            tiles.map { tile in
                var text = tile.text
                if tile.side == .hanzi, let pinyin = pinyin(for: tile), !pinyin.isEmpty { text += " \(pinyin)" }
                if isMatched(tile) { text += " ✓" }
                if missedTileIDs.contains(tile.id) { text += " ✗" }
                if isSelected(tile) { text = "*" + text }
                return text
            }.joined(separator: " | ")
        }
        var parts = ["matched \(matchedCount)/\(pairs.count)"]
        if !missedPairIDs.isEmpty { parts.append("missed: \(missedPairIDs.count)") }
        parts += ["english: \(line(englishTiles))", "hanzi: \(line(hanziTiles))"]
        return parts.joined(separator: "  ")
    }

    /// The taps that match one pair left, or that pair one pair's English with another's Hanzi,
    /// after a tap that clears any selection.
    func guess(right: Bool) throws -> [Tile] {
        let left = pairs.filter { !matchedPairIDs.contains($0.id) }
        guard let first = left.first else { throw ScreenDriverError.cannotAnswer("the board is matched") }
        guard right || left.count > 1 else { throw ScreenDriverError.cannotAnswer("one pair left, so no wrong match") }
        let hanziPair = right ? first : left[1]
        guard let english = englishTiles.first(where: { $0.pairID == first.id }),
              let hanzi = hanziTiles.first(where: { $0.pairID == hanziPair.id })
        else { throw ScreenDriverError.cannotAnswer("the board has no tiles for its pairs") }
        return (selected.map { [$0] } ?? []) + [english, hanzi]
    }

    /// The last two taps of a guess, as `answer` reports them.
    static func describe(_ taps: [Tile], right: Bool) -> String {
        "\(taps.suffix(2).map(\.text).joined(separator: " ↔ ")): \(right ? "matched" : "missed")"
    }

    /// The tile showing `text`, exactly or ignoring case.
    func tile(named text: String) -> Tile? {
        let tiles = englishTiles + hanziTiles
        return tiles.first { $0.text == text } ?? tiles.first { $0.text.lowercased() == text.lowercased() }
    }
}
