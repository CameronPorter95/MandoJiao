import CoreDI
import CoreDomain
import CoreSound
import CoreUI
import LibraryDomain
import PracticeDomain
import PracticeUI

/// The only place that builds the flash card lesson.
public enum FlashcardsFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: FlashcardsNavigation,
        input: FlashcardsInput
    ) -> FlashcardsRoute {
        FlashcardsRoute(viewModel: makeViewModel(input: input, sounds: ToneEngine.shared), navigation: navigation)
    }

    /// The lesson without its view, silent.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: FlashcardsNavigation,
        input: FlashcardsInput
    ) -> ScreenDriver {
        makeViewModel(input: input, sounds: SilentSounds()).driver(navigation: navigation)
    }

    private static func makeViewModel(input: FlashcardsInput, sounds: any MatchSoundPlaying) -> FlashcardsViewModel {
        FlashcardsViewModel(request: input.request, recordResults: input.recordResults, sounds: sounds)
    }
}

public extension FlashcardsFactory {
    /// One card as a step of a longer lesson, handing its answer back on Continue.
    static func makeStepRoute(card: Flashcard, onComplete: @escaping ([Answer]) -> Void) -> FlashcardStepRoute {
        FlashcardStepRoute(viewModel: FlashcardStepViewModel(card: card, sounds: ToneEngine.shared, onComplete: onComplete))
    }

    /// The card without its view, silent.
    static func makeStepDriver(card: Flashcard, onComplete: @escaping ([Answer]) -> Void) -> ScreenDriver {
        FlashcardStepViewModel(card: card, sounds: SilentSounds(), onComplete: onComplete).driver()
    }
}
