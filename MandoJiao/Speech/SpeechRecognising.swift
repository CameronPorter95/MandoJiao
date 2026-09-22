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
    /// Stops listening and returns the final transcript.
    func stop() async -> String
    func cancel()
}

/// Returns canned transcripts in order. Used by previews and by the checks that drive a
/// lesson without a microphone.
@MainActor
final class ScriptedRecogniser: SpeechRecognising {
    var availability: SpeechAvailability = .ready
    var partialText: String = ""

    private var transcripts: [String]
    private var index = 0

    init(transcripts: [String]) {
        self.transcripts = transcripts
    }

    func prepare() async -> SpeechAvailability { availability }

    func start(hints: [String]) async throws {
        partialText = ""
    }

    func stop() async -> String {
        defer { index += 1 }
        let transcript = index < transcripts.count ? transcripts[index] : ""
        partialText = transcript
        return transcript
    }

    func cancel() {
        partialText = ""
    }
}
