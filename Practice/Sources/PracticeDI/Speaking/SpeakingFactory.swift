import CoreDI
import CoreSound
import LibraryDomain
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

    /// One word as a step of a longer lesson, handing its answer back once the card settles.
    /// `recogniser` is the lesson's, shared by every step that listens.
    static func makeStepRoute(
        dependencies: Dependencies,
        word: WordPair,
        recogniser: DictationRecogniser,
        onComplete: @escaping ([Answer]) -> Void
    ) -> SpeakingStepRoute {
        SpeakingStepRoute(viewModel: SpeakingViewModel(
            request: LessonRequest(title: "", pool: [word]),
            recogniser: recogniser,
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            completion: .step(onComplete),
            logAttempt: SpeechLog.attempt
        ))
    }
}
