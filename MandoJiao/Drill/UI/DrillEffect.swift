import Foundation

enum DrillEffect: Equatable, Sendable {
    /// Every verdict gets one, including two identical wrong answers in a row.
    case haptic(DrillHaptic)
    case showError(DrillError)
    case close
}

enum DrillHaptic: Equatable, Sendable {
    case success
    case error
}
