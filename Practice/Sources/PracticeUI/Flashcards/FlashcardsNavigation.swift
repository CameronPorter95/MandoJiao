import Foundation

@MainActor
public struct FlashcardsNavigation {
    public var didClose: () -> Void

    public init(didClose: @escaping () -> Void) {
        self.didClose = didClose
    }
}
