import Foundation
import Observation
import SpeakingDomain

/// Returns canned transcripts in order. Used by previews and by the checks that drive a
/// lesson without a microphone.
@MainActor
@Observable
public final class ScriptedRecogniser: SpeechRecognising {
    public var availability: SpeechAvailability = .ready
    public var partialText: String = ""

    private var outcomes: [SpeechOutcome]
    private var index = 0

    public init(transcripts: [String]) {
        self.outcomes = transcripts.map { SpeechOutcome(best: $0) }
    }

    public init(outcomes: [SpeechOutcome]) {
        self.outcomes = outcomes
    }

    public func prepare() async -> SpeechAvailability { availability }

    public func start(hints: [String]) async throws {
        partialText = ""
    }

    public func stop() async -> SpeechOutcome {
        defer { index += 1 }
        let outcome = index < outcomes.count ? outcomes[index] : .empty
        partialText = outcome.best
        return outcome
    }

    public func cancel() {
        partialText = ""
    }
}
