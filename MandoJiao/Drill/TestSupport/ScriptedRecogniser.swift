import Foundation
import Observation

/// Returns canned transcripts in order. Used by previews and by the checks that drive a
/// lesson without a microphone.
@MainActor
@Observable
final class ScriptedRecogniser: SpeechRecognising {
    var availability: SpeechAvailability = .ready
    var partialText: String = ""

    private var outcomes: [SpeechOutcome]
    private var index = 0

    init(transcripts: [String]) {
        self.outcomes = transcripts.map { SpeechOutcome(best: $0) }
    }

    init(outcomes: [SpeechOutcome]) {
        self.outcomes = outcomes
    }

    func prepare() async -> SpeechAvailability { availability }

    func start(hints: [String]) async throws {
        partialText = ""
    }

    func stop() async -> SpeechOutcome {
        defer { index += 1 }
        let outcome = index < outcomes.count ? outcomes[index] : .empty
        partialText = outcome.best
        return outcome
    }

    func cancel() {
        partialText = ""
    }
}
