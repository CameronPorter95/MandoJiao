import CoreUI
import Foundation
import PracticeDomain

extension SettingsViewModel {
    /// Strictness is named as the screen shows it, Strict to Generous, not as it is stored.
    public func driver() -> ScreenDriver {
        ScreenDriver(
            name: "settings",
            actions: DriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: DriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .strictnessChanged(let strictness): self.send(.strictnessChanged(strictness.value))
                case .showsPinyinChanged(let showsPinyin): self.send(.showsPinyinChanged(showsPinyin))
                case .matchingRoundsChanged(let rounds): self.send(.matchingRoundsChanged(rounds))
                case .speakingCardLimitChanged(let cardLimit): self.send(.speakingCardLimitChanged(cardLimit))
                case .skipsLearntWordsChanged(let skips): self.send(.skipsLearntWordsChanged(skips))
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 }
        )
    }
}

private enum DriverAction: Decodable {
    case appeared
    case strictnessChanged(strictness: Strictness)
    case showsPinyinChanged(showsPinyin: Bool)
    case matchingRoundsChanged(rounds: Int)
    case speakingCardLimitChanged(cardLimit: Int)
    case skipsLearntWordsChanged(skips: Bool)

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "strictnessChanged", "showsPinyinChanged", "matchingRoundsChanged",
        "speakingCardLimitChanged", "skipsLearntWordsChanged",
    ]
}

/// A strictness by the title the screen shows, in any case.
private struct Strictness: Decodable {
    let value: AnswerStrictness

    init(from decoder: Decoder) throws {
        let title = try decoder.singleValueContainer().decode(String.self)
        guard let value = AnswerStrictness.allCases.first(where: { $0.title.lowercased() == title.lowercased() }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "no strictness \(title)"))
        }
        self.value = value
    }
}

extension SettingsState {
    var summary: String {
        let titles = AnswerStrictness.allCases.map(\.title).joined(separator: ", ")
        return [
            "settings",
            "strictness: \(strictness.title) (\(titles))",
            "speaking cards: \(speakingCardLimit)",
            "matching rounds: \(matchingRounds)",
            "pinyin: \(showsPinyin ? "on" : "off")",
            "skip learnt words: \(skipsLearntWords ? "on" : "off")",
        ].joined(separator: "  ")
    }
}
