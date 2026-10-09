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
            follow: navigation.follow
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
            follow: { $0 }
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
    /// Each side's tiles in the order shown, a matched one marked ✓ and the selected one *.
    /// Hanzi carry their pinyin whether or not the board shows it, so an answer can be worked out.
    var summary: String {
        func line(_ tiles: [Tile]) -> String {
            tiles.map { tile in
                var text = tile.text
                if tile.side == .hanzi, let pinyin = pinyin(for: tile), !pinyin.isEmpty { text += " \(pinyin)" }
                if isMatched(tile) { text += " ✓" }
                if isSelected(tile) { text = "*" + text }
                return text
            }.joined(separator: " | ")
        }
        return "matched \(matchedCount)/\(pairs.count)  english: \(line(englishTiles))  hanzi: \(line(hanziTiles))"
    }

    /// The tile showing `text`, exactly or ignoring case.
    func tile(named text: String) -> Tile? {
        let tiles = englishTiles + hanziTiles
        return tiles.first { $0.text == text } ?? tiles.first { $0.text.lowercased() == text.lowercased() }
    }
}
