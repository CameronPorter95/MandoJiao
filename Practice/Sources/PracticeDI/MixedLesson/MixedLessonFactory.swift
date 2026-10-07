import CoreDI
import CoreSound
import PracticeDomain
import PracticeUI
import ProgressDomain
import SwiftUI
import VocabularyDomain

/// The only place that names the mixed lesson's concrete dependencies.
public enum MixedLessonFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: MixedLessonNavigation,
        input: MixedLessonInput
    ) -> MixedLessonRoute {
        MixedLessonRoute(
            viewModel: MixedLessonViewModel(
                lesson: MixedLesson(plan: input.plan),
                recordResults: input.recordResults,
                sounds: ToneEngine.shared
            ),
            navigation: navigation,
            makeStep: { step, onComplete in makeStep(step, dependencies: dependencies, onComplete: onComplete) }
        )
    }

    /// Each exercise's own single-step route, from the same package.
    private static func makeStep(_ step: MixedStep, dependencies: Dependencies, onComplete: @escaping ([Answer]) -> Void) -> AnyView {
        switch step {
        case .match(let pairs):
            AnyView(MatchingFactory.makeStepRoute(dependencies: dependencies, pairs: pairs, onComplete: onComplete))
        case .flashcard(let card):
            AnyView(FlashcardsFactory.makeStepRoute(card: card, onComplete: onComplete))
        case .teach:
            // The mixed lesson shows a word itself; it never asks for this.
            AnyView(EmptyView())
        }
    }
}

public struct MixedLessonInput {
    public let plan: TodayPlan
    /// Owned by Vocabulary, which this package cannot reach, so the app hands it in.
    public let recordResults: RecordLessonResultsUseCase

    public init(plan: TodayPlan, recordResults: RecordLessonResultsUseCase) {
        self.plan = plan
        self.recordResults = recordResults
    }
}

public extension MixedLessonNavigation {
    /// Presented over the app. Closing it is the presenter's dismissal (N5).
    static func app(dismiss: @escaping () -> Void) -> Self {
        MixedLessonNavigation(didClose: dismiss)
    }
}
