import CoreDI
import CoreDomain
import CoreSound
import CoreUI
import LibraryDomain
import PracticeData
import PracticeDomain
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
            recogniser: input.speech?.recogniser ?? DictationRecogniser() as any SpeechRecognising,
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            recordResults: input.recordResults,
            logAttempt: SpeechLog.attempt
        )
        return SpeakingRoute(viewModel: viewModel, navigation: navigation)
    }

    /// The lesson without its view, silent and never waiting on the clock. It hears `speech`,
    /// which has the whole answer as a listen starts, so the listen can end at once.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: SpeakingNavigation,
        input: SpeakingInput,
        speech: ScriptedSpeech,
        logAttempt: @escaping SpeakingViewModel.LogAttempt
    ) -> ScreenDriver {
        SpeakingViewModel(
            request: input.request,
            recogniser: speech.recogniser,
            audioSession: SilentAudioSession(),
            sounds: SilentSounds(),
            getSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            recordResults: input.recordResults,
            logAttempt: logAttempt,
            advanceDelay: .zero,
            waitForEnd: Endpointing.endAtOnce
        ).driver(navigation: navigation)
    }

    /// One word as a step of a longer lesson, handing its answer back once the card settles.
    /// `recogniser` is the lesson's, shared by every step that listens. `listensAtOnce`
    /// carries on from a right answer in the step before, as the speaking lesson does.
    static func makeStepRoute(
        dependencies: Dependencies,
        word: WordPair,
        recogniser: DictationRecogniser,
        listensAtOnce: Bool,
        onComplete: @escaping (_ answers: [Answer], _ carriesOn: Bool) -> Void
    ) -> SpeakingStepRoute {
        SpeakingStepRoute(viewModel: SpeakingViewModel(
            request: LessonRequest(title: "", pool: [word]),
            recogniser: recogniser,
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            completion: .step(onComplete),
            logAttempt: SpeechLog.attempt,
            listensAtOnce: listensAtOnce
        ))
    }
}
