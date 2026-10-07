import Foundation

@MainActor
public struct MixedLessonNavigation {
    public var didClose: () -> Void

    public init(didClose: @escaping () -> Void) {
        self.didClose = didClose
    }
}
