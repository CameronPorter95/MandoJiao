import CoreUI
import Foundation

extension AppNavigationCoordinator {
    /// The app's navigation for remote driving: the open tab.
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
            // No back of its own: a lesson's own screen closes it as its ✕ does, asking first
            // when it has answers to keep.
            follow: { $0 },
            open: { kind, name in
                guard kind == "tab" else { throw ScreenDriverError.cannotOpen(kind) }
                guard let tab = AppTab(rawValue: name) else {
                    throw ScreenDriverError.notOneOf("tab", name, AppTab.allCases.map(\.rawValue))
                }
                self.selectedTab = tab
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
