import CoreUI
import Foundation
import LibraryDomain

extension WordLibraryViewModel {
    /// A word is picked by its place in the list the summary shows, rather than by its id.
    /// Sorting goes through `layout`, which the library owns, as the screen's sort menu does.
    /// `editor` builds the editor sheet over the results, given how to close it; without it, as
    /// in the app, nothing is in front. A dictionary page opened from here is not driven.
    public func driver(
        layout: WordListLayout,
        editor: ((WordEditorTarget, _ dismissed: @escaping () -> Void) -> ScreenDriver)? = nil
    ) -> ScreenDriver {
        let children = ChildDrivers<String>()
        return ScreenDriver(
            name: "results",
            actions: WordLibraryDriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: WordLibraryDriverAction) in
                if case .sortChanged(let sort) = action { layout.setSort(sort) }
                if let action = action.libraryAction(in: self.state) { self.send(action) }
            },
            effects: effects,
            follow: { $0 },
            front: {
                guard let editor else { return nil }
                return children.front(of: self.state.editor.map { [$0.id] } ?? []) { _ in
                    editor(self.state.editor ?? .new(WordDraft(meanings: [], hanzi: ""))) { self.send(.editorDismissed) }
                }
            },
            back: {
                guard self.state.dictionary != nil else { return false }
                self.send(.dictionaryDismissed)
                return true
            },
            relay: children.relay
        )
    }
}

private enum WordLibraryDriverAction: Decodable {
    case appeared
    case disappeared
    case searchChanged(text: String)
    case sortChanged(sort: WordSort)
    case editTapped(word: Int)
    case editorDismissed
    case dictionaryTapped(word: Int)
    case dictionaryDismissed
    case deleteTapped(word: Int)
    case learntToggled(word: Int)

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "searchChanged", "sortChanged", "editTapped", "editorDismissed",
        "dictionaryTapped", "dictionaryDismissed", "deleteTapped", "learntToggled",
    ]

    /// Nil for a place past the end of the list.
    func libraryAction(in state: WordLibraryState) -> WordLibraryAction? {
        let words = state.words
        func id(_ index: Int) -> UUID? { words.indices.contains(index) ? words[index].id : nil }
        return switch self {
        case .appeared: .appeared
        case .disappeared: .disappeared
        case .searchChanged(let text): .searchChanged(text)
        case .sortChanged(let sort): .sortChanged(sort)
        case .editTapped(let index): id(index).map { .editTapped($0) }
        case .editorDismissed: .editorDismissed
        case .dictionaryTapped(let index): id(index).map { .dictionaryTapped($0) }
        case .dictionaryDismissed: .dictionaryDismissed
        case .deleteTapped(let index): id(index).map { .deleteTapped([$0]) }
        case .learntToggled(let index): id(index).map { .learntToggled($0) }
        }
    }
}

extension WordLibraryState {
    /// "results  2 of 296  0. 你好 nǐ hǎo hello | 1. …", the first ten by the place the actions take.
    var summary: String {
        let shown = words.prefix(10).enumerated().map { index, word in
            "\(index). \(word.hanzi) \(word.pinyin) \(word.english)\(word.isLearnt ? " (learnt)" : "")"
        }
        var parts = ["results", count]
        if !shown.isEmpty { parts.append(shown.joined(separator: " | ")) }
        if editor != nil { parts.append("editing a word") }
        if dictionary != nil { parts.append("dictionary page open, not driven") }
        return parts.joined(separator: "  ")
    }
}
