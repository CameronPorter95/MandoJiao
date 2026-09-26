import CoreDI
import CoreSound
import MatchingUI

/// The only place that names the matching lesson's concrete dependencies.
public enum MatchingFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: MatchingNavigation,
        input: MatchingInput
    ) -> MatchingRoute {
        let viewModel = MatchingViewModel(
            request: input.request,
            sounds: ToneEngine.shared,
            getSettings: MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setShowsPinyin: MatchingSettingsFactory.makeSetShowsPinyinUseCase(dependencies: dependencies),
            recordResults: input.recordResults
        )
        return MatchingRoute(viewModel: viewModel, navigation: navigation)
    }
}
