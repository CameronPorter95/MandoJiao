import CoreSound
import SpeakingData
import SpeakingDomain
import SpeakingUI
import SwiftUI
import VocabularyDomain

/// The only place that names the speaking lesson's concrete dependencies.
@MainActor
public struct SpeakingFactory {
    let recordResults: RecordLessonResultsUseCase
    let settings: GetSpeakingSettingsUseCase

    public init(recordResults: RecordLessonResultsUseCase) {
        self.recordResults = recordResults
        settings = GetSpeakingSettingsUseCase(repository: SpeakingSettingsRepositoryImpl())
    }

    public func makeRoute(request: LessonRequest, didClose: @escaping () -> Void) -> some View {
        let viewModel = SpeakingViewModel(
            request: request,
            recogniser: DictationRecogniser(),
            audioSession: ToneEngine.shared,
            sounds: ToneEngine.shared,
            getSettings: settings,
            recordResults: recordResults,
            logAttempt: SpeechLog.attempt
        )
        return SpeakingRoute(viewModel: viewModel, navigation: SpeakingNavigation(didClose: didClose))
    }
}
