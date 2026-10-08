import Foundation

@MainActor
public struct MatchingNavigation {
    public var didClose: () -> Void

    public init(didClose: @escaping () -> Void) {
        self.didClose = didClose
    }

    /// Carries out an effect that leaves the screen, and returns any other for the presenter.
    func follow(_ effect: MatchingEffect) -> MatchingEffect? {
        guard effect == .close else { return effect }
        didClose()
        return nil
    }
}
