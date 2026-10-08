import CoreUI
import Foundation

extension HomeViewModel {
    /// `destination` builds what is pushed over home, such as settings; without it home has
    /// nothing in front of it, as in the app, where the views hold the stack.
    public func driver(
        navigation: HomeNavigation,
        destination: ((HomeDestination) -> ScreenDriver)? = nil
    ) -> ScreenDriver {
        let children = ChildDrivers<HomeDestination>()
        return ScreenDriver(
            name: "home",
            actions: HomeAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow,
            front: {
                guard let destination else { return nil }
                return children.front(of: self.state.destination.map { [$0] } ?? [], make: destination)
            },
            back: {
                guard self.state.destination != nil else { return false }
                self.send(.destinationDismissed)
                return true
            },
            relay: children.relay
        )
    }
}

extension HomeAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "quickPracticeTapped", "todayPlanTapped", "continueTapped",
        "chooseSourceTapped", "sourceChosen", "sourceChoiceDismissed", "practiseMistakesTapped",
        "clearMistakesTapped", "clearMistakesConfirmed", "clearMistakesCancelled",
        "opened", "destinationDismissed",
    ]
}

extension HomeState {
    var summary: String {
        var parts = [
            "home",
            "quick practice: \(usableWordCount) words",
            "today: \(todayPlan == nil ? "nothing planned" : "a plan")",
            "continue: \(currentName.map { "\($0), \(currentWordCount) words" } ?? "nothing")",
            "mistakes: \(mistakeWords.count)",
        ]
        if isChoosingSource {
            let decks = sourceSections.flatMap(\.decks).map { "\($0.deck.name) \($0.id.uuidString.prefix(8))" }
            parts.append("choosing from: \(decks.joined(separator: ", "))")
        }
        if isConfirmingClear { parts.append("confirming clear") }
        return parts.joined(separator: "  ")
    }
}
