import Foundation

/// Why the microphone path is or is not usable right now.
public enum SpeechAvailability: Equatable {
    case notPrepared
    case ready
    /// Microphone or speech recognition permission was refused.
    case needsPermission
    case downloadingModel(progress: Double)
    /// No recogniser for this locale, no microphone, or the model could not install.
    case unsupported(reason: String)

    public var canListen: Bool { self == .ready }
}

/// What one utterance produced.
///
/// The recogniser offers runner-up transcriptions alongside its best guess. Grading only
/// the best guess throws that away, and on isolated words the right answer is often
/// sitting in second place.
public struct SpeechOutcome: Equatable {
    public let best: String
    public let alternatives: [String]

    public init(best: String, alternatives: [String] = []) {
        self.best = best
        self.alternatives = alternatives
    }

    public static let empty = SpeechOutcome(best: "")
}

/// The microphone side of a speech card, kept behind a protocol for two reasons: the
/// exercise logic stays testable without audio hardware, and `SFSpeechRecognizer` can be
/// dropped in later if the newer framework disappoints on device.
///
/// This file imports Foundation only, so anything depending on it still compiles where
/// the Speech framework does not.
///
/// `Observable` because `SpeakingViewModel` mirrors `availability` and `partialText` into its
/// state through observation tracking. A recogniser that is not observable would leave
/// the screen showing stale values.
@MainActor
public protocol SpeechRecognising: AnyObject, Observable {
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
