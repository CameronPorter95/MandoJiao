import CoreDI
import CoreSound
import LibraryDomain
import PracticeUI

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

public extension MatchingFactory {
    /// One board as a step of a longer lesson, handing its answers back once it is cleared.
    static func makeStepRoute(
        dependencies: Dependencies,
        pairs: [WordPair],
        onComplete: @escaping ([Answer]) -> Void
    ) -> MatchingStepRoute {
        let settings = MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)()
        return MatchingStepRoute(viewModel: MatchingStepViewModel(
            pairs: pairs, showsPinyin: settings.showsPinyin, sounds: ToneEngine.shared, onComplete: onComplete
        ))
    }
}
