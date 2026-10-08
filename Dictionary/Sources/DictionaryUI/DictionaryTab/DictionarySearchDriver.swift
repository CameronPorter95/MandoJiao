import CoreUI
import DictionaryDomain
import Foundation

extension DictionarySearchViewModel {
    /// A result is picked by its place in the list `ls` shows, rather than spelled out whole.
    /// A headword's page is not driven: it is pushed by the view, not through this screen.
    public func driver() -> ScreenDriver {
        ScreenDriver(
            name: "dictionary",
            actions: DriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: DriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .disappeared: self.send(.disappeared)
                case .queryChanged(let query): self.send(.queryChanged(query))
                case .editorDismissed: self.send(.editorDismissed)
                case .vocabularyTapped(let index):
                    guard case .found(let results) = self.state.results, results.indices.contains(index) else { return }
                    self.send(.vocabularyTapped(results[index]))
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 },
            isBusy: { $0.results == .searching }
        )
    }
}

private enum DriverAction: Decodable {
    case appeared
    case disappeared
    case queryChanged(query: String)
    case vocabularyTapped(result: Int)
    case editorDismissed

    static let names = ["appeared", "disappeared", "queryChanged", "vocabularyTapped", "editorDismissed"]
}

extension DictionarySearchState {
    var summary: String {
        var parts = ["dictionary", "query: \(query)"]
        switch results {
        case .none: parts.append("no search")
        case .searching: parts.append("searching")
        case .failed: parts.append("search failed")
        case .found(let found):
            let shown = found.prefix(10).enumerated().map { index, result in
                "\(index). \(result.entry.simplified) \(result.entry.pinyin) \(result.headline ?? result.entry.senses.first ?? "")"
            }
            parts.append("results: \(found.count)  \(shown.joined(separator: " | "))")
        }
        if editor != nil { parts.append("editing a reading") }
        return parts.joined(separator: "  ")
    }
}
