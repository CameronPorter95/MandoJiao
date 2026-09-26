import CoreDI
import SettingsUI

/// The settings screen's only way out is back, which is the navigation stack's job.
public enum SettingsFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: SettingsInput) -> SettingsRoute {
        SettingsRoute(
            viewModel: SettingsViewModel(
                getSpeakingSettings: input.getSpeakingSettings,
                setStrictness: input.setStrictness,
                setSpeakingCardLimit: input.setSpeakingCardLimit,
                getMatchingSettings: input.getMatchingSettings,
                setShowsPinyin: input.setShowsPinyin,
                setMatchingRounds: input.setMatchingRounds
            )
        )
    }
}
