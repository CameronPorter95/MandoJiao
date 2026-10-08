import CoreUI
import Foundation

extension HomeViewModel {
    public func driver(navigation: HomeNavigation) -> ScreenDriver {
        ScreenDriver(
            name: "home",
            actions: HomeAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow
        )
    }
}

extension HomeAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "quickPracticeTapped", "todayPlanTapped", "continueTapped",
        "chooseSourceTapped", "sourceChosen", "sourceChoiceDismissed", "practiseMistakesTapped",
        "clearMistakesTapped", "clearMistakesConfirmed", "clearMistakesCancelled",
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
