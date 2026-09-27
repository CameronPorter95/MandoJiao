import Foundation
import MatchingDomain

enum MatchingAction: Equatable {
    case appeared
    case tileTapped(Tile)
    case pinyinToggled
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}
