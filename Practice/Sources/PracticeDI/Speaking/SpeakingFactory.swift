import CoreDI
import CoreSound
import PracticeData
import PracticeUI

/// The only place that names the speaking lesson's concrete dependencies.
public enum SpeakingFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: SpeakingNavigation,
        input: SpeakingInput
    ) -> SpeakingRoute {
        let viewModel = SpeakingViewModel(
            request: input.request,
            recogniser: DictationRecogniser(),
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            recordResults: input.recordResults,
            logAttempt: SpeechLog.attempt
        )
        return SpeakingRoute(viewModel: viewModel, navigation: navigation)
    }
}
