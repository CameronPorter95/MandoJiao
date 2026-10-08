import CoreUI
import DictionaryDomain
import Foundation

extension DictionaryPageViewModel {
    /// A reading and a character are picked by their place in the lists `ls` shows. `open` pushes
    /// a character's page; without it, as where the stack is the view's own, none can be opened.
    public func driver(open: ((DictionaryHeadword) -> Void)?) -> ScreenDriver {
        ScreenDriver(
            name: "page",
            actions: open == nil ? DriverAction.names.filter { $0 != "characterOpened" } : DriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: DriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .disappeared: self.send(.disappeared)
                case .retryTapped: self.send(.retryTapped)
                case .editorDismissed: self.send(.editorDismissed)
                case .vocabularyTapped(let index):
                    guard let reading = self.state.reading(index) else { return }
                    self.send(.vocabularyTapped(reading.id))
                case .characterOpened(let index):
                    guard case .loaded(_, let characters) = self.state.content, characters.indices.contains(index) else { return }
                    let character = characters[index]
                    open?(DictionaryHeadword(hanzi: character.hanzi, pinyin: character.pinyin))
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 },
            isBusy: { $0.content == .loading }
        )
    }
}

private enum DriverAction: Decodable {
    case appeared
    case disappeared
    case retryTapped
    case vocabularyTapped(reading: Int)
    case editorDismissed
    case characterOpened(character: Int)

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = ["appeared", "disappeared", "retryTapped", "vocabularyTapped", "editorDismissed", "characterOpened"]
}

extension DictionaryPageState {
    var summary: String {
        var parts = ["page", headword.hanzi]
        switch content {
        case .loading:
            parts.append("loading")
        case .failed:
            parts.append("could not load")
        case .loaded(let readings, let characters):
            let shown = readings.map { reading in
                let saved = vocabulary(for: reading)?.isSaved == true ? " (saved)" : ""
                return "\(reading.id). \(reading.entry.pinyin) \(reading.entry.senses.prefix(3).joined(separator: ", "))\(saved)"
            }
            parts.append("readings: \(shown.joined(separator: " | "))")
            if !characters.isEmpty {
                let listed = characters.enumerated().map { "\($0.offset). \($0.element.hanzi) \($0.element.pinyin) \($0.element.gloss)" }
                parts.append("characters: \(listed.joined(separator: " | "))")
            }
        }
        if editor != nil { parts.append("editing a reading") }
        return parts.joined(separator: "  ")
    }
}
