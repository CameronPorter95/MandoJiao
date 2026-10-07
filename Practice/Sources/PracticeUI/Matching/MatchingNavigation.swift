import Foundation

@MainActor
public struct MatchingNavigation {
    public var didClose: () -> Void

    public init(didClose: @escaping () -> Void) {
        self.didClose = didClose
    }
}
