import Foundation

enum MatchingEffect: Equatable, Sendable {
    /// One per tap that changes the board, including two identical misses in a row.
    case haptic(MatchingHaptic)
    case showError(MatchingError)
    case close
}

enum MatchingHaptic: Equatable, Sendable {
    /// A board cleared.
    case success
    /// One pair matched, with more to go.
    case match
    case miss
    /// A tile picked up or swapped for another.
    case selection
}
