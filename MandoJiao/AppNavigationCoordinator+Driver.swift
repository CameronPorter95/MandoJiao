import CoreUI
import Foundation

extension AppNavigationCoordinator {
    /// The app's navigation for remote driving: the open tab, and closing the lesson over it.
    func driver() -> ScreenDriver {
        ScreenDriver(
            name: "app",
            actions: ["selectTab"],
            state: { (tab: self.selectedTab, lesson: self.presentedLesson.map(\.kind)) },
            summary: { "app  tab: \($0.tab.rawValue)  lesson: \($0.lesson ?? "none")" },
            send: { (action: AppAction) in
                switch action {
                case .selectTab(let tab): self.selectedTab = tab
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 },
            back: {
                guard self.presentedLesson != nil else { return false }
                self.dismissLesson()
                return true
            }
        )
    }
}

private enum AppAction: Decodable {
    case selectTab(tab: AppNavigationCoordinator.AppTab)
}

private extension AppNavigationCoordinator.PresentedLesson {
    var kind: String {
        switch self {
        case .matching: "matching"
        case .speaking: "speaking"
        case .flashcards: "flashcards"
        case .todayPlan: "today's plan"
        }
    }
}
