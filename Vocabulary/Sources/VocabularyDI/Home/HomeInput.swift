import SwiftUI

/// What the home screen needs from outside its package.
@MainActor
public struct HomeInput {
    /// The matching lesson's floor and round count, so this package need not know Matching.
    public let minimumMatchingWords: Int
    /// Asked on every appearance, so a change in settings shows on return.
    public let quickPracticeRounds: () -> Int
    /// A screen seam: settings belongs to another package, so the app supplies it.
    public let settings: () -> AnyView

    public init(minimumMatchingWords: Int, quickPracticeRounds: @escaping () -> Int, settings: @escaping () -> AnyView) {
        self.minimumMatchingWords = minimumMatchingWords
        self.quickPracticeRounds = quickPracticeRounds
        self.settings = settings
    }
}
