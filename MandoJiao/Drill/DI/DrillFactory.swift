import Foundation

/// The only place that names the drill's concrete dependencies.
@MainActor
struct DrillFactory {
    let recordResults: RecordLessonResultsUseCase
    let settings: GetDrillSettingsUseCase

    init(recordResults: RecordLessonResultsUseCase, settingsRepository: any DrillSettingsRepository = DrillSettingsRepositoryImpl()) {
        self.recordResults = recordResults
        settings = GetDrillSettingsUseCase(repository: settingsRepository)
    }

    func makeRoute(request: LessonRequest, navigation: DrillNavigation) -> DrillRoute {
        let viewModel = DrillViewModel(
            request: request,
            recogniser: DictationRecogniser(),
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: settings,
            recordResults: recordResults
        )
        return DrillRoute(viewModel: viewModel, navigation: navigation)
    }
}
