import CoreDI
import CoreSound
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
        let recogniser = DictationRecogniser()
        return MixedLessonRoute(
            viewModel: MixedLessonViewModel(
                lesson: MixedLesson(plan: input.plan),
                recordResults: input.recordResults,
                findExamples: input.findExamples,
                generateExample: input.generateExample,
                sounds: ToneEngine.shared,
                audioSession: ToneEngine.shared
            ),
            navigation: navigation,
            makeStep: { step, listensAtOnce, onComplete in
                makeStep(step, dependencies: dependencies, recogniser: recogniser, listensAtOnce: listensAtOnce, onComplete: onComplete)
            }
        )
    }

    /// Each exercise's own single-step route, from the same package.
    private static func makeStep(
        _ step: MixedStep,
        dependencies: Dependencies,
        recogniser: DictationRecogniser,
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

    public init(
        plan: TodayPlan,
        recordResults: RecordLessonResultsUseCase,
        findExamples: FindExamplesUseCase,
        generateExample: GenerateExampleUseCase
    ) {
        self.plan = plan
        self.recordResults = recordResults
        self.findExamples = findExamples
        self.generateExample = generateExample
    }
}

public extension MixedLessonNavigation {
    /// Presented over the app. Closing it is the presenter's dismissal (N5).
    static func app(dismiss: @escaping () -> Void) -> Self {
        MixedLessonNavigation(didClose: dismiss)
    }
}
