import CoreDI
import CoreSound
import FlashcardsUI

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
