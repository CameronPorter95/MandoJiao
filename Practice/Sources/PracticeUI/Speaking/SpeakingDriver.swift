import CoreUI
import Foundation

extension SpeakingViewModel {
    public func driver(navigation: SpeakingNavigation) -> ScreenDriver {
        ScreenDriver(
            name: "speaking",
            actions: SpeakingAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow
        )
    }
}

extension SpeakingAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "sceneLeftForeground",
        "startListeningTapped", "stopListeningTapped", "typedAnswerSubmitted", "typingToggled",
        "continueTapped", "practiseAgainTapped", "closeTapped", "quitConfirmed", "quitCancelled",
    ]
}

extension SpeakingState {
    var summary: String {
        guard let lesson else { return "speaking  no lesson" }
        guard !lesson.isFinished else { return "speaking  finished  failed attempts: \(lesson.failedAttempts)" }
        var parts = [
            "speaking",
            "card \(lesson.cardNumber)/\(lesson.plan.cardCount)",
            lesson.card.hanzi,
            lesson.card.pinyin,
            "mic: \(mic)",
            "\(lesson.phase)",
        ]
        if isTyping { parts.append("typing") }
        if availability != .ready { parts.append("availability: \(availability)") }
        if isConfirmingQuit { parts.append("confirming quit") }
        return parts.joined(separator: "  ")
    }
}
