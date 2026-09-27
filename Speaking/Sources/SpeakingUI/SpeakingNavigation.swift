import Foundation

@MainActor
public struct SpeakingNavigation {
    public var didClose: () -> Void

    public init(didClose: @escaping () -> Void) {
        self.didClose = didClose
    }
}
