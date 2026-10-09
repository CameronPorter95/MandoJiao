import CoreUI
import Foundation
import PracticeDomain

extension MixedLessonViewModel {
    /// Builds the driver for one exercise step, as the Route's `makeStep` builds its view. Never
    /// asked for a teach step, which the lesson shows itself.
    public typealias MakeStepDriver = (MixedStep, _ listensAtOnce: Bool, @escaping MixedLessonRoute.StepCompletion) -> ScreenDriver

    /// `step` puts each exercise step's driver in front of the lesson's, so `ls` shows it and
    /// commands reach it. Without it nothing is in front, as in the app, where the step's own
    /// Route offers its driver.
    public func driver(navigation: MixedLessonNavigation, step: MakeStepDriver? = nil) -> ScreenDriver {
        let children = ChildDrivers<String>()
        // Practising again starts the steps over at the same places, so a step is told apart by
        // which run of the lesson it is in too.
        var run = 0
        return ScreenDriver(
            name: "today's plan",
            actions: MixedLessonDriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: MixedLessonDriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .disappeared: self.send(.disappeared)
                case .continueTapped:
                    guard case .teach = self.state.lesson.step else { return }
                    self.send(.stepCompleted([]))
                case .practiseAgainTapped:
                    run += 1
                    self.send(.practiseAgainTapped)
                case .closeTapped: self.send(.closeTapped)
                case .quitConfirmed: self.send(.quitConfirmed)
                case .quitCancelled: self.send(.quitCancelled)
                }
            },
            effects: effects,
            follow: navigation.follow,
            front: {
                let lesson = self.state.lesson
                guard let step, let current = lesson.step, !current.isTeach else {
                    return children.front(of: []) { _ in preconditionFailure("an empty stack makes nothing") }
                }
                return children.front(of: ["\(run)-\(lesson.stepIndex)"]) { _ in
                    step(current, lesson.listensOnArrival) { answers, carriesOn in
                        self.send(.stepCompleted(answers, carriesOn: carriesOn))
                    }
                }
            },
            relay: children.relay,
            // A teach card whose example is still coming, so `ls` waits for the sentence.
            isBusy: { state in
                guard case .teach(let word) = state.lesson.step else { return false }
                return state.examplesPending.contains(word.id)
            }
        )
    }
}

/// The screen's actions. A teach step's Continue is `continueTapped`; an exercise step is
/// answered through its own driver, in front.
enum MixedLessonDriverAction: Decodable {
    case appeared
    case disappeared
    case continueTapped
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "continueTapped", "practiseAgainTapped", "closeTapped", "quitConfirmed", "quitCancelled",
    ]
}

extension MixedLessonState {
    var summary: String {
        guard let step = lesson.step else {
            let right = lesson.answers.filter(\.isCorrect).count
            return "today's plan  finished  right: \(right)/\(lesson.answers.count)"
        }
        var parts = ["today's plan", "step \(lesson.stepNumber)/\(lesson.steps.count)"]
        switch step {
        case .teach(let word):
            parts.append("teach: \(word.hanzi) \(word.pinyin) \(word.english)")
            if let example = examples[word.id] { parts.append("example: \(example.hanzi)") }
            parts.append("continueTapped to go on")
        case .match: parts.append("matching board")
        case .flashcard: parts.append("flash card")
        case .readAloud: parts.append("read aloud")
        }
        if isConfirmingQuit { parts.append("confirming quit") }
        return parts.joined(separator: "  ")
    }
}

extension MixedStep {
    var isTeach: Bool {
        if case .teach = self { return true }
        return false
    }
}
