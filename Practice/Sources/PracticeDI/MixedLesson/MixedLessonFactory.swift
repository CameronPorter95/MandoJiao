import CoreDI
import CoreDomain
import CoreSound
import CoreUI
import DictionaryDomain
import LibraryDomain
import PracticeData
import PracticeDomain
import PracticeUI
import ProgressDomain
import SwiftUI

/// The only place that names the mixed lesson's concrete dependencies.
public enum MixedLessonFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: MixedLessonNavigation,
        input: MixedLessonInput
    ) -> MixedLessonRoute {
        // One for the whole lesson, so the speech model is prepared once however many words
        // are read aloud.
        let recogniser: any SpeechRecognising = input.speech?.recogniser ?? DictationRecogniser()
        return MixedLessonRoute(
            viewModel: makeViewModel(input: input, sounds: ToneEngine.shared, audioSession: ToneEngine.shared),
            navigation: navigation,
            makeStep: { step, listensAtOnce, onComplete in
                makeStep(step, dependencies: dependencies, recogniser: recogniser, listensAtOnce: listensAtOnce, onComplete: onComplete)
            }
        )
    }

    /// The lesson without its view, silent and never waiting on the clock, with each exercise
    /// step's driver in front of it. Words read aloud hear `speech`.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: MixedLessonNavigation,
        input: MixedLessonInput,
        speech: ScriptedSpeech,
        logAttempt: @escaping SpeakingViewModel.LogAttempt
    ) -> ScreenDriver {
        makeViewModel(input: input, sounds: SilentSounds(), audioSession: SilentAudioSession()).driver(
            navigation: navigation,
            step: { step, listensAtOnce, onComplete in
                makeStepDriver(
                    step, dependencies: dependencies, speech: speech, listensAtOnce: listensAtOnce,
                    logAttempt: logAttempt, onComplete: onComplete
                )
            }
        )
    }

    private static func makeViewModel(
        input: MixedLessonInput,
        sounds: any MatchSoundPlaying,
        audioSession: any AudioSessionSwitching
    ) -> MixedLessonViewModel {
        MixedLessonViewModel(
            lesson: MixedLesson(plan: input.plan),
            recordResults: input.recordResults,
            findExamples: input.findExamples,
            generateExample: input.generateExample,
            sounds: sounds,
            audioSession: audioSession
        )
    }

    /// Each exercise's own single-step route, from the same package.
    private static func makeStep(
        _ step: MixedStep,
        dependencies: Dependencies,
        recogniser: any SpeechRecognising,
        listensAtOnce: Bool,
        onComplete: @escaping MixedLessonRoute.StepCompletion
    ) -> AnyView {
        switch step {
        case .readAloud(let word):
            AnyView(SpeakingFactory.makeStepRoute(
                dependencies: dependencies, word: word, recogniser: recogniser,
                listensAtOnce: listensAtOnce, onComplete: onComplete
            ))
        case .match(let pairs):
            AnyView(MatchingFactory.makeStepRoute(dependencies: dependencies, pairs: pairs) { onComplete($0, false) })
        case .flashcard(let card):
            AnyView(FlashcardsFactory.makeStepRoute(card: card) { onComplete($0, false) })
        case .teach:
            // The mixed lesson shows a word itself; it never asks for this.
            AnyView(EmptyView())
        }
    }

    /// Each exercise's own single-step driver, as `makeStep` builds its route.
    static func makeStepDriver(
        _ step: MixedStep,
        dependencies: Dependencies,
        speech: ScriptedSpeech,
        listensAtOnce: Bool,
        logAttempt: @escaping SpeakingViewModel.LogAttempt,
        onComplete: @escaping MixedLessonRoute.StepCompletion
    ) -> ScreenDriver {
        switch step {
        case .readAloud(let word):
            SpeakingFactory.makeStepDriver(
                dependencies: dependencies, word: word, speech: speech, listensAtOnce: listensAtOnce,
                logAttempt: logAttempt, onComplete: onComplete
            )
        case .match(let pairs):
            MatchingFactory.makeStepDriver(dependencies: dependencies, pairs: pairs) { onComplete($0, false) }
        case .flashcard(let card):
            FlashcardsFactory.makeStepDriver(card: card) { onComplete($0, false) }
        case .teach:
            // The lesson's driver answers a teach step itself and never asks for one.
            preconditionFailure("a teach step has no driver of its own")
        }
    }
}

public struct MixedLessonInput {
    public let plan: TodayPlan
    /// Owned by the library, whose data this package cannot reach, so the app hands it in.
    public let recordResults: RecordLessonResultsUseCase
    /// The dictionary's example sentences, for the words the lesson teaches. Handed in for
    /// the same reason.
    public let findExamples: FindExamplesUseCase
    /// Writes one on the device for a word none of those use in its card's sense.
    public let generateExample: GenerateExampleUseCase
    /// Heard in place of the microphone, by every word read aloud, when set.
    public let speech: ScriptedSpeech?

    public init(
        plan: TodayPlan,
        recordResults: RecordLessonResultsUseCase,
        findExamples: FindExamplesUseCase,
        generateExample: GenerateExampleUseCase,
        speech: ScriptedSpeech? = nil
    ) {
        self.plan = plan
        self.recordResults = recordResults
        self.findExamples = findExamples
        self.generateExample = generateExample
        self.speech = speech
    }
}

public extension MixedLessonNavigation {
    /// Presented over the app. Closing it is the presenter's dismissal (N5).
    static func app(dismiss: @escaping () -> Void) -> Self {
        MixedLessonNavigation(didClose: dismiss)
    }
}
