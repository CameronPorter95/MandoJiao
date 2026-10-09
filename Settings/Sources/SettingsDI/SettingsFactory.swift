import CoreDI
import CoreUI
import SettingsUI

/// The settings screen's only way out is back, which is the navigation stack's job.
public enum SettingsFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: SettingsInput) -> SettingsRoute {
        SettingsRoute(viewModel: makeViewModel(input: input))
    }

    /// Settings without its view.
    public static func makeDriver(dependencies: Dependencies, input: SettingsInput) -> ScreenDriver {
        makeViewModel(input: input).driver()
    }

    private static func makeViewModel(input: SettingsInput) -> SettingsViewModel {
        SettingsViewModel(
            getSpeakingSettings: input.getSpeakingSettings,
            setStrictness: input.setStrictness,
            setSpeakingCardLimit: input.setSpeakingCardLimit,
            getMatchingSettings: input.getMatchingSettings,
            setShowsPinyin: input.setShowsPinyin,
            setMatchingRounds: input.setMatchingRounds,
            getLessonSettings: input.getLessonSettings,
            setSkipsLearntWords: input.setSkipsLearntWords
        )
    }
}
