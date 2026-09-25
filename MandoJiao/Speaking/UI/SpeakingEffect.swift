import Foundation

enum SpeakingEffect: Equatable, Sendable {
    /// Every verdict gets one, including two identical wrong answers in a row.
    case haptic(SpeakingHaptic)
    case showError(SpeakingError)
    case close
}

enum SpeakingHaptic: Equatable, Sendable {
    case success
    case error
}
