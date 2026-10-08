import Foundation
import Observation
import PracticeDomain

/// Hears queued answers in order, each as its listen starts, for driving a lesson without a
/// microphone: headlessly, and in the app launched with -scripted-speech.
///
/// A listen with nothing queued hears nothing until an answer is queued during it, as speech into
/// an open microphone would be, so the listen a lesson opens by itself after a right answer hears
/// the next answer rather than ending empty and taking it.
@MainActor
@Observable
public final class ScriptedRecogniser: SpeechRecognising {
    public var availability: SpeechAvailability = .ready
    public var partialText: String = ""

    private var queued: [SpeechOutcome]
    private var isListening = false

    public init(transcripts: [String] = []) {
        self.queued = transcripts.map { SpeechOutcome(best: $0) }
    }

    public init(outcomes: [SpeechOutcome]) {
        self.queued = outcomes
    }

    public func enqueue(_ outcome: SpeechOutcome) {
        queued.append(outcome)
        if isListening, partialText.isEmpty { partialText = outcome.best }
    }

    public func prepare() async -> SpeechAvailability { availability }

    public func start(hints: [String]) async throws {
        isListening = true
        partialText = queued.first?.best ?? ""
    }

    public func stop() async -> SpeechOutcome {
        isListening = false
        guard !queued.isEmpty else { return .empty }
        let outcome = queued.removeFirst()
        partialText = outcome.best
        return outcome
    }

    /// Drops what is queued too: a lesson cancels as it closes, and the app keeps one of these
    /// for every lesson, so an answer left over would be heard on another lesson's card.
    public func cancel() {
        isListening = false
        partialText = ""
        queued.removeAll()
    }
}
