import CoreUI
import Foundation
import LibraryDomain
import PracticeDomain

extension FlashcardsViewModel {
    /// An option is picked by its place in the list `ls` shows, rather than by its word's id.
    public func driver(navigation: FlashcardsNavigation) -> ScreenDriver {
        ScreenDriver(
            name: "flashcards",
            actions: FlashcardsDriverAction.names,
            state: { self.state },
            summary: \.summary,
            send: { (action: FlashcardsDriverAction) in
                switch action {
                case .appeared: self.send(.appeared)
                case .typedAnswerSubmitted(let answer): self.send(.typedAnswerSubmitted(answer))
                case .optionPicked(let index):
                    guard let option = self.state.lesson?.card.option(at: index) else { return }
                    self.send(.optionPicked(option.id))
                case .dontKnowTapped: self.send(.dontKnowTapped)
                case .continueTapped: self.send(.continueTapped)
                case .practiseAgainTapped: self.send(.practiseAgainTapped)
                case .closeTapped: self.send(.closeTapped)
                case .quitConfirmed: self.send(.quitConfirmed)
                case .quitCancelled: self.send(.quitCancelled)
                }
            },
            effects: effects,
            follow: navigation.follow,
            // As the ✕ does, so a lesson with answers to keep asks before it quits.
            back: {
                self.send(.closeTapped)
                return true
            }
        )
    }
}

extension FlashcardStepViewModel {
    /// One card in a longer lesson, answered as the flash card lesson's are.
    public func driver() -> ScreenDriver {
        ScreenDriver(
            name: "flashcard step",
            actions: FlashcardStepDriverAction.names,
            state: { self.lesson },
            summary: { "flashcard step  \($0.summary)" },
            send: { (action: FlashcardStepDriverAction) in
                switch action {
                case .appeared: self.appeared()
                case .disappeared: break
                case .typedAnswerSubmitted(let answer): _ = self.submit(typed: answer)
                case .optionPicked(let index):
                    guard let option = self.lesson.card.option(at: index) else { return }
                    _ = self.pick(option.id)
                case .dontKnowTapped: self.dontKnow()
                case .continueTapped: self.finish()
                }
            },
            effects: { AsyncStream<Never> { $0.finish() } },
            follow: { $0 }
        )
    }
}

/// The screen's actions, with an option by its place rather than its word's id.
enum FlashcardsDriverAction: Decodable {
    case appeared
    case typedAnswerSubmitted(answer: String)
    case optionPicked(option: Int)
    case dontKnowTapped
    case continueTapped
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "typedAnswerSubmitted", "optionPicked", "dontKnowTapped", "continueTapped",
        "practiseAgainTapped", "closeTapped", "quitConfirmed", "quitCancelled",
    ]
}

enum FlashcardStepDriverAction: Decodable {
    case appeared
    case disappeared
    case typedAnswerSubmitted(answer: String)
    case optionPicked(option: Int)
    case dontKnowTapped
    case continueTapped

    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = ["appeared", "disappeared", "typedAnswerSubmitted", "optionPicked", "dontKnowTapped", "continueTapped"]
}

extension FlashcardsState {
    var summary: String {
        guard let lesson else { return "flashcards  no lesson" }
        guard !lesson.isFinished else { return "flashcards  finished  wrong: \(lesson.wrongCount)" }
        var parts = ["flashcards", "card \(lesson.cardNumber)/\(lesson.plan.cardCount)", lesson.summary]
        if isConfirmingQuit { parts.append("confirming quit") }
        return parts.joined(separator: "  ")
    }
}

extension FlashcardLesson {
    /// What the card shows and how it is answered, then the verdict once there is one.
    var summary: String {
        let card = card
        let shown = card.showsChinese ? "\(card.word.hanzi) \(card.word.pinyin)" : card.word.english
        let wanted = card.showsChinese ? "English" : "Hanzi"
        let answering: String
        switch card.format {
        case .typed:
            answering = "type the \(wanted)"
        case .picked(let options):
            let named = options.enumerated().map { "\($0.offset). \(card.showsChinese ? $0.element.english : $0.element.hanzi)" }
            answering = "pick the \(wanted): \(named.joined(separator: " | "))"
        }
        switch phase {
        case .answering:
            return "\(shown)  \(answering)"
        case .answered(let isCorrect, let given):
            let answer = card.showsChinese ? card.word.english : card.word.hanzi
            return "\(shown)  \(isCorrect ? "right" : "wrong")  given: \(given.isEmpty ? "nothing" : given)  answer: \(answer)"
        }
    }
}

extension Flashcard {
    func option(at index: Int) -> WordPair? {
        guard case .picked(let options) = format, options.indices.contains(index) else { return nil }
        return options[index]
    }
}
