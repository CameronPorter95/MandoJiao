import LibraryDomain
import SwiftUI

/// What the home screen needs from outside its package.
@MainActor
public struct HomeInput {
    /// The matching lesson's floor and round count, so this package need not know Practice.
    public let minimumMatchingWords: Int
    /// Asked on every appearance, so a change in settings shows on return.
    public let quickPracticeRounds: () -> Int
    /// The library's use cases, which only the app can build, since this package may not
    /// see the library's data.
    public let observeVocabulary: ObserveVocabularyUseCase
    public let getLessonSettings: GetLessonSettingsUseCase
    public let clearMistakes: ClearMistakesUseCase
    /// A screen seam: settings belongs to another package, so the app supplies it.
    public let settings: () -> AnyView

    public init(
        minimumMatchingWords: Int,
        quickPracticeRounds: @escaping () -> Int,
        observeVocabulary: ObserveVocabularyUseCase,
        getLessonSettings: GetLessonSettingsUseCase,
        clearMistakes: ClearMistakesUseCase,
        settings: @escaping () -> AnyView
    ) {
        self.minimumMatchingWords = minimumMatchingWords
        self.quickPracticeRounds = quickPracticeRounds
        self.observeVocabulary = observeVocabulary
        self.getLessonSettings = getLessonSettings
        self.clearMistakes = clearMistakes
        self.settings = settings
    }
}
