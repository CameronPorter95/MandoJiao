import Foundation
import PracticeDomain

/// What the microphone is doing.
///
/// `arming` exists because opening the microphone is not instant, and a button that says
/// it is listening before capture has started invites people to speak into nothing. The
/// first syllable then goes missing and comes back as a grunt.
enum MicState: Equatable {
    case idle
    case arming
    case listening
}

/// Everything the speaking lesson screen renders.
struct SpeakingState: Equatable {
    /// Nil when the request held no words that can be drilled.
    var lesson: SpeakingLesson?
    var mic: MicState = .idle
    var partialText = ""
    var availability: SpeechAvailability = .notPrepared
    var prefersTyping = false
    var isConfirmingQuit = false

    /// Typing is either chosen or forced by the microphone being unavailable.
    var isTyping: Bool { prefersTyping || !availability.canListen }

    var availabilityNotice: String? {
        switch availability {
        case .ready:
            return nil
        case .notPrepared:
            return "Getting the microphone ready…"
        case .needsPermission:
            return "Microphone access is off, so type your answers. Turn it on in Settings to speak them."
        case .downloadingModel(let progress):
            return "Downloading the Mandarin speech model, \(Int(progress * 100))%. You can type in the meantime."
        case .unsupported(let reason):
            return "\(reason) Type your answers instead."
        }
    }

    /// Closing before anything is answered, or after the end, needs no confirmation.
    var canCloseWithoutConfirming: Bool {
        guard let lesson else { return true }
        return lesson.isFinished || lesson.progress == 0
    }
}
