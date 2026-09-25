import Foundation

/// The only place that names the speaking lesson's concrete dependencies.
@MainActor
struct SpeakingFactory {
    let recordResults: RecordLessonResultsUseCase
    let settings: GetSpeakingSettingsUseCase

    init(recordResults: RecordLessonResultsUseCase, settingsRepository: any SpeakingSettingsRepository = SpeakingSettingsRepositoryImpl()) {
        self.recordResults = recordResults
        settings = GetSpeakingSettingsUseCase(repository: settingsRepository)
    }

    func makeRoute(request: LessonRequest, navigation: SpeakingNavigation) -> SpeakingRoute {
        let viewModel = SpeakingViewModel(
            request: request,
            recogniser: DictationRecogniser(),
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: settings,
            recordResults: recordResults
        )
        return SpeakingRoute(viewModel: viewModel, navigation: navigation)
    }
}
