import CoreUI
import DictionaryDomain
import Foundation

extension DictionarySearchViewModel {
    /// A result is picked by its place in the list `ls` shows, rather than spelled out whole.
    /// `page` builds a headword's page, handed the way to push a character's; without it the
    /// search has nothing in front of it, as in the app, where the views hold the stack.
    public func driver(
        page: ((DictionaryHeadword, _ open: @escaping (DictionaryHeadword) -> Void) -> ScreenDriver)? = nil
    ) -> ScreenDriver {
        let children = ChildDrivers<PushedPage>()
        return ScreenDriver(
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
                    guard let result = self.state.result(index) else { return }
                    self.send(.vocabularyTapped(result))
                case .opened(let index):
                    guard let result = self.state.result(index) else { return }
                    self.send(.opened(DictionaryHeadword(hanzi: result.entry.simplified, pinyin: result.entry.pinyin)))
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 },
            front: {
                guard let page else { return nil }
                let stack = self.state.path.enumerated().map { PushedPage(place: $0.offset, headword: $0.element) }
                return children.front(of: stack) { pushed in
                    page(pushed.headword) { self.send(.opened($0)) }
                }
            },
            back: {
                guard !self.state.path.isEmpty else { return false }
                self.send(.pathChanged(Array(self.state.path.dropLast())))
                return true
            },
            relay: children.relay,
            isBusy: { $0.results == .searching }
        )
    }
}

/// The same headword can be pushed twice, so a page is told apart by its place too.
private struct PushedPage: Hashable {
    let place: Int
    let headword: DictionaryHeadword
}

private enum DriverAction: Decodable {
    case appeared
    case disappeared
    case queryChanged(query: String)
    case vocabularyTapped(result: Int)
    case editorDismissed
    case opened(result: Int)

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = ["appeared", "disappeared", "queryChanged", "vocabularyTapped", "editorDismissed", "opened"]
}

extension DictionarySearchState {
    func result(_ index: Int) -> DictionarySearchResult? {
        guard case .found(let results) = results, results.indices.contains(index) else { return nil }
        return results[index]
    }

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
