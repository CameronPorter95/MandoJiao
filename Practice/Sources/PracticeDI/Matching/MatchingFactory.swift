import CoreDI
import CoreDomain
import CoreSound
import CoreUI
import LibraryDomain
import PracticeUI

/// The only place that names the matching lesson's concrete dependencies.
public enum MatchingFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: MatchingNavigation,
        input: MatchingInput
    ) -> MatchingRoute {
        MatchingRoute(viewModel: makeViewModel(dependencies: dependencies, input: input, sounds: ToneEngine.shared), navigation: navigation)
    }

    /// The lesson without its view, silent and moving to the next board at once.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: MatchingNavigation,
        input: MatchingInput
    ) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, input: input, sounds: SilentSounds(), advanceDelay: .zero)
            .driver(navigation: navigation)
    }

    private static func makeViewModel(
        dependencies: Dependencies,
        input: MatchingInput,
        sounds: any MatchSoundPlaying,
        advanceDelay: Duration = MatchingViewModel.defaultAdvanceDelay
    ) -> MatchingViewModel {
        MatchingViewModel(
            request: input.request,
            sounds: sounds,
            getSettings: MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setShowsPinyin: MatchingSettingsFactory.makeSetShowsPinyinUseCase(dependencies: dependencies),
            recordResults: input.recordResults,
            advanceDelay: advanceDelay
        )
    }
}

public extension MatchingFactory {
    /// One board as a step of a longer lesson, handing its answers back once it is cleared.
    static func makeStepRoute(
        dependencies: Dependencies,
        pairs: [WordPair],
        onComplete: @escaping ([Answer]) -> Void
    ) -> MatchingStepRoute {
        MatchingStepRoute(viewModel: makeStepViewModel(dependencies: dependencies, pairs: pairs, sounds: ToneEngine.shared, onComplete: onComplete))
    }

    /// The board without its view, silent and handing its answers back at once.
    static func makeStepDriver(
        dependencies: Dependencies,
        pairs: [WordPair],
        onComplete: @escaping ([Answer]) -> Void
    ) -> ScreenDriver {
        makeStepViewModel(dependencies: dependencies, pairs: pairs, sounds: SilentSounds(), advanceDelay: .zero, onComplete: onComplete).driver()
    }

    private static func makeStepViewModel(
        dependencies: Dependencies,
        pairs: [WordPair],
        sounds: any MatchSoundPlaying,
        advanceDelay: Duration = MatchingViewModel.defaultAdvanceDelay,
        onComplete: @escaping ([Answer]) -> Void
    ) -> MatchingStepViewModel {
        let settings = MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)()
        return MatchingStepViewModel(
            pairs: pairs, showsPinyin: settings.showsPinyin, sounds: sounds, advanceDelay: advanceDelay, onComplete: onComplete
        )
    }
}
