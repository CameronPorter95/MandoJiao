import CoreUI
import Foundation
import LibraryDomain

extension WordEditorViewModel {
    /// Meanings are moved and removed by their place, and a deck chosen by its name, built-in key
    /// or the start of its id, rather than spelled out as index sets and UUIDs. `dismiss` closes
    /// the sheet, which the presenter owns. A dictionary page opened from here is not driven.
    public func driver(dismiss: @escaping () -> Void) -> ScreenDriver {
        ScreenDriver(
            name: "word editor",
            actions: WordEditorDriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: WordEditorDriverAction) in
                if let action = action.editorAction(in: self.state) { self.send(action) }
            },
            effects: effects,
            follow: { $0.followed(dismiss: dismiss) },
            back: {
                self.send(.cancelTapped)
                return true
            },
            // A lookup is under way until one has come back for the Hanzi as typed.
            isBusy: { $0.isLoading || $0.lookup?.hanzi != $0.draft.trimmed.hanzi }
        )
    }
}

private enum WordEditorDriverAction: Decodable {
    case appeared
    case disappeared
    case hanziChanged(text: String)
    case pinyinChanged(text: String)
    case senseToggled(sense: String)
    case meaningAdded(text: String)
    case meaningEdited(at: Int, text: String)
    case meaningMoved(from: Int, to: Int)
    case meaningRemoved(at: Int)
    case sensesTapped
    case sensesDismissed
    case dictionaryTapped
    case dictionaryDismissed
    /// Null for no deck.
    case deckChosen(deck: String?)
    case deckSectionToggled(section: String)
    case saveTapped
    case learntToggled(isLearnt: Bool)
    case deleteTapped
    case cancelTapped

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "hanziChanged", "pinyinChanged", "senseToggled", "meaningAdded",
        "meaningEdited", "meaningMoved", "meaningRemoved", "sensesTapped", "sensesDismissed",
        "dictionaryTapped", "dictionaryDismissed", "deckChosen", "deckSectionToggled", "saveTapped",
        "learntToggled", "deleteTapped", "cancelTapped",
    ]

    /// Nil for a deck nothing matches, which leaves the choice as it was, and for a meaning's
    /// place past the end: moving from one traps, which the screen's own list never asks for.
    func editorAction(in state: WordEditorState) -> WordEditorAction? {
        switch self {
        case .appeared: .appeared
        case .disappeared: .disappeared
        case .hanziChanged(let text): .hanziChanged(text)
        case .pinyinChanged(let text): .pinyinChanged(text)
        case .senseToggled(let sense): .senseToggled(sense)
        case .meaningAdded(let text): .meaningAdded(text)
        case .meaningEdited(let index, let text): .meaningEdited(at: index, text: text)
        case .meaningMoved(let from, let to):
            state.meanings.indices.contains(from) && (0...state.meanings.count).contains(to)
                ? .meaningsMoved(from: IndexSet(integer: from), to: to) : nil
        case .meaningRemoved(let index):
            state.meanings.indices.contains(index) ? .meaningsRemoved(IndexSet(integer: index)) : nil
        case .sensesTapped: .sensesTapped
        case .sensesDismissed: .sensesDismissed
        case .dictionaryTapped: .dictionaryTapped
        case .dictionaryDismissed: .dictionaryDismissed
        case .deckChosen(nil): .deckChosen(nil)
        case .deckChosen(let query?): Self.deck(query, in: state.vocabulary).map { .deckChosen($0.id) }
        case .deckSectionToggled(let id): .deckSectionToggled(id)
        case .saveTapped: .saveTapped
        case .learntToggled(let isLearnt): .learntToggled(isLearnt)
        case .deleteTapped: .deleteTapped
        case .cancelTapped: .cancelTapped
        }
    }

    private static func deck(_ query: String, in vocabulary: Vocabulary) -> DeckSummary? {
        let lowered = query.lowercased()
        return vocabulary.decks.first { $0.name.lowercased() == lowered }
            ?? vocabulary.decks.first { $0.builtInKey == query }
            ?? vocabulary.decks.first { $0.id.uuidString.lowercased().hasPrefix(lowered) }
    }
}

extension WordEditorState {
    /// "word editor  new  hanzi: 你好  pinyin: nǐ hǎo (suggested)  meanings: 0. hello  deck: …"
    var summary: String {
        var parts = [
            "word editor",
            wordID == nil ? "new" : "edit",
            "hanzi: \(draft.hanzi)",
            "pinyin: \(submission.pinyin)\(pinyinSuggestion == nil ? "" : " (suggested)")",
            "meanings: \(meanings.enumerated().map { "\($0.offset). \($0.element)" }.joined(separator: ", "))\(meaningsAreSuggested ? " (suggested)" : "")",
        ]
        let senses = tickableEntries.flatMap(\.senses)
        if !senses.isEmpty { parts.append("senses: \(senses.prefix(12).joined(separator: "; "))") }
        if wordID == nil { parts.append("deck: \(chosenDeckTitle)") }
        if isLearnt { parts.append("learnt") }
        if isChoosingSenses { parts.append("choosing senses") }
        if dictionary != nil { parts.append("dictionary page open, not driven") }
        if isLoading { parts.append("loading") }
        parts.append(canSave ? "can save" : "cannot save yet")
        return parts.joined(separator: "  ")
    }
}
