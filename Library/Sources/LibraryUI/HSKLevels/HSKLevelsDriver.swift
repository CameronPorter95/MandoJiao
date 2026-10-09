import CoreUI
import Foundation

extension HSKLevelsViewModel {
    /// `dismiss` closes the sheet, which the presenter owns.
    public func driver(dismiss: @escaping () -> Void) -> ScreenDriver {
        ScreenDriver(
            name: "hsk levels",
            actions: HSKLevelsAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: { $0.followed(dismiss: dismiss) },
            back: {
                self.send(.doneTapped)
                return true
            },
            isBusy: { $0.words == nil || !$0.installing.isEmpty }
        )
    }
}

extension HSKLevelsAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = ["appeared", "disappeared", "installTapped", "doneTapped"]
}

extension HSKLevelsState {
    /// "hsk levels  level 1: HSK 1 added, 6 decks, 150 words | level 2: …", by the level
    /// `installTapped` takes.
    var summary: String {
        guard words != nil else { return "hsk levels  reading the list" }
        let shown = levels.map { level in
            let status = switch level.status {
            case .added: "added"
            case .notAdded: "not added"
            case .missing(let count): "\(count) decks missing"
            }
            let installing = installing.contains(level.level) ? ", installing" : ""
            return "level \(level.level): \(level.name) \(status)\(installing), \(level.deckCount) decks, \(level.wordCount) words"
        }
        return "hsk levels  \(shown.joined(separator: " | "))"
    }
}
