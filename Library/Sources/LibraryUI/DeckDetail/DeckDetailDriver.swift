import CoreUI
import Foundation

extension DeckDetailViewModel {
    public func driver(navigation: DeckDetailNavigation) -> ScreenDriver {
        ScreenDriver(
            name: "deck",
            actions: DeckDetailAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow
        )
    }
}

extension DeckDetailAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "nameChanged", "searchChanged", "removeTapped",
        "addWordsTapped", "addWordsDismissed", "pickerSearchChanged", "wordToggled",
        "startLessonTapped", "moveTapped", "destinationChosen", "moveCancelled",
    ]
}

extension DeckDetailState {
    var summary: String {
        guard deck != nil else { return "deck  not found" }
        var parts = ["deck", title, "\(wordCount) words", "lesson words: \(selectedCount)"]
        if isAddingWords { parts.append("adding words") }
        if isChoosingDestination { parts.append("choosing destination") }
        return parts.joined(separator: "  ")
    }
}
