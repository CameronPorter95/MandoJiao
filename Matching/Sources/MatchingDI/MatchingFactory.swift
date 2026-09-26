import CoreDI
import CoreSound
import MatchingData
import MatchingDomain
import MatchingUI

/// The only place that names the matching lesson's concrete dependencies.
public enum MatchingFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: MatchingNavigation,
        input: MatchingInput
    ) -> MatchingRoute {
        let settings = MatchingSettingsRepositoryImpl()
        let viewModel = MatchingViewModel(
            request: input.request,
            sounds: ToneEngine.shared,
            getSettings: GetMatchingSettingsUseCase(repository: settings),
            setShowsPinyin: SetShowsPinyinUseCase(repository: settings),
            recordResults: input.recordResults
        )
        return MatchingRoute(viewModel: viewModel, navigation: navigation)
    }
}
