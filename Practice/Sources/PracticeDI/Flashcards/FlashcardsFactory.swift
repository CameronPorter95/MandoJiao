import CoreDI
import CoreSound
import PracticeDomain
import VocabularyDomain
import PracticeUI

/// The only place that builds the flash card lesson.
public enum FlashcardsFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: FlashcardsNavigation,
        input: FlashcardsInput
    ) -> FlashcardsRoute {
        FlashcardsRoute(
            viewModel: FlashcardsViewModel(request: input.request, recordResults: input.recordResults, sounds: ToneEngine.shared),
            navigation: navigation
        )
    }
}

public extension FlashcardsFactory {
    /// One card as a step of a longer lesson, handing its answer back on Continue.
    static func makeStepRoute(card: Flashcard, onComplete: @escaping ([Answer]) -> Void) -> FlashcardStepRoute {
        FlashcardStepRoute(viewModel: FlashcardStepViewModel(card: card, sounds: ToneEngine.shared, onComplete: onComplete))
    }
}
