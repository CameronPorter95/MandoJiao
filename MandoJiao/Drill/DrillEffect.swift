import Foundation

enum DrillEffect: Equatable {
    /// Every verdict gets one, including two identical wrong answers in a row.
    case haptic(DrillHaptic)
    case close
}

enum DrillHaptic: Equatable {
    case success
    case error
}
