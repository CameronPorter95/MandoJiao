import SwiftData

/// The only place that names the drill's concrete dependencies.
enum DrillFactory {
    static func makeRoute(
        request: LessonRequest,
        context: ModelContext,
        navigation: DrillNavigation
    ) -> DrillRoute {
        let viewModel = DrillViewModel(
            request: request,
            recogniser: DictationRecogniser(),
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            strictness: Preferences.strictness,
            cardLimit: Preferences.drillCardLimit,
            recordResults: { misses, cleanSolves in
                MistakeLog.apply(misses: misses, cleanSolves: cleanSolves, in: context)
            }
        )
        return DrillRoute(viewModel: viewModel, navigation: navigation)
    }
}
