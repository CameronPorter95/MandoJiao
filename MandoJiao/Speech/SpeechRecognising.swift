import Foundation

/// Why the microphone path is or is not usable right now.
enum SpeechAvailability: Equatable {
    case notPrepared
    case ready
    /// Microphone or speech recognition permission was refused.
    case needsPermission
    case downloadingModel(progress: Double)
    /// No recogniser for this locale, no microphone, or the model could not install.
    case unsupported(reason: String)

    var canListen: Bool { self == .ready }
}

/// What one utterance produced.
///
/// The recogniser offers runner-up transcriptions alongside its best guess. Grading only
/// the best guess throws that away, and on isolated words the right answer is often
/// sitting in second place.
struct SpeechOutcome: Equatable {
    let best: String
    let alternatives: [String]

    init(best: String, alternatives: [String] = []) {
        self.best = best
        self.alternatives = alternatives
    }

    static let empty = SpeechOutcome(best: "")
}

/// The microphone side of a speech card, kept behind a protocol for two reasons: the
/// exercise logic stays testable without audio hardware, and `SFSpeechRecognizer` can be
/// dropped in later if the newer framework disappoints on device.
///
/// This file imports Foundation only, so anything depending on it still compiles where
/// the Speech framework does not.
@MainActor
protocol SpeechRecognising: AnyObject {
    var availability: SpeechAvailability { get }
    /// Updated live while listening, for on-screen feedback.
    var partialText: String { get }

    func prepare() async -> SpeechAvailability
    /// `hints` biases recognition toward the word being asked for.
    func start(hints: [String]) async throws
    /// Stops listening and returns what was heard.
    func stop() async -> SpeechOutcome
    func cancel()
}

/// Returns canned transcripts in order. Used by previews and by the checks that drive a
/// lesson without a microphone.
@MainActor
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
