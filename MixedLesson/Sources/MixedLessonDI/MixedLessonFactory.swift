import CoreDI
import CoreSound
import MixedLessonDomain
import MixedLessonUI
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
            makeStep: input.makeStep
        )
    }
}

public struct MixedLessonInput {
    public let plan: TodayPlan
    /// Owned by Vocabulary, which this package cannot reach, so the app hands it in.
    public let recordResults: RecordLessonResultsUseCase
    /// A matching board or flash card step. Those belong to other packages, so the app builds
    /// them, calling back with the step's answers.
    public let makeStep: (MixedStep, @escaping ([Answer]) -> Void) -> AnyView

    public init(
        plan: TodayPlan,
        recordResults: RecordLessonResultsUseCase,
        makeStep: @escaping (MixedStep, @escaping ([Answer]) -> Void) -> AnyView
    ) {
        self.plan = plan
        self.recordResults = recordResults
        self.makeStep = makeStep
    }
}

public extension MixedLessonNavigation {
    /// Presented over the app. Closing it is the presenter's dismissal (N5).
    static func app(dismiss: @escaping () -> Void) -> Self {
        MixedLessonNavigation(didClose: dismiss)
    }
}
