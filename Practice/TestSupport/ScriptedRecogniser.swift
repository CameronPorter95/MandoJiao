import Foundation
import Observation
import PracticeDomain

/// Hears queued answers in order, each as its listen starts, for driving a lesson without a
/// microphone.
///
/// A listen with nothing queued hears nothing and takes nothing, so the listen a lesson starts
/// by itself after a right answer cannot eat an answer meant for a later tap.
@MainActor
@Observable
public final class ScriptedRecogniser: SpeechRecognising {
    public var availability: SpeechAvailability = .ready
    public var partialText: String = ""

    private var queued: [SpeechOutcome]

    public init(transcripts: [String] = []) {
        self.queued = transcripts.map { SpeechOutcome(best: $0) }
    }

    public init(outcomes: [SpeechOutcome]) {
        self.queued = outcomes
    }

    public func enqueue(_ outcome: SpeechOutcome) {
        queued.append(outcome)
    }

    public func prepare() async -> SpeechAvailability { availability }

    public func start(hints: [String]) async throws {
        partialText = queued.first?.best ?? ""
    }

    public func stop() async -> SpeechOutcome {
        guard !queued.isEmpty else { return .empty }
        let outcome = queued.removeFirst()
        partialText = outcome.best
        return outcome
    }

    public func cancel() {
        partialText = ""
    }
}
