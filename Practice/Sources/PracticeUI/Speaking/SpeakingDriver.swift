import CoreUI
import Foundation

extension SpeakingViewModel {
    /// A step of a longer lesson has no way out of its own, so `back` passes it by.
    public func driver(navigation: SpeakingNavigation, isStep: Bool = false) -> ScreenDriver {
        ScreenDriver(
            name: "speaking",
            actions: SpeakingAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow,
            // As the ✕ does, so a lesson with answers to keep asks before it quits.
            back: {
                guard !isStep else { return false }
                self.send(.closeTapped)
                return true
            },
            // Heard something and not graded yet: the listen ends only as endpointing settles.
            // A listen that has heard nothing, as after a right answer, may wait for a word.
            isBusy: { state in
                state.mic == .arming || (state.mic == .listening && !state.partialText.isEmpty)
            },
            answer: answerCard
        )
    }
}

extension SpeakingViewModel {
    /// Typed rather than spoken, so it needs no scripted speech. A listen under way stops
    /// without answering first, as leaving the app does.
    func answerCard(right: Bool) throws -> String {
        guard let lesson = state.lesson, !lesson.isFinished, !lesson.phase.isSettled, !state.isConfirmingQuit else {
            throw ScreenDriverError.cannotAnswer("no card is waiting for an answer")
        }
        send(.sceneLeftForeground)
        let given = right ? lesson.card.pinyin : "zzz"
        send(.typedAnswerSubmitted(answer: given))
        let phase = state.lesson?.phase
        if phase?.isSettled == true { send(.continueTapped) }
        return "\(lesson.card.hanzi): typed \(given), \(phase.map { "\($0)" } ?? "")"
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
