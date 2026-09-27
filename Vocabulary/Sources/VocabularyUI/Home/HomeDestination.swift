import Foundation

/// Screens pushed onto the home stack.
public enum HomeDestination: Hashable {
    case library
    case deck(UUID)
    case folder(UUID)
    case settings
}
