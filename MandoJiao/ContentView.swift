import CoreDI
import CoreDomain
import SpeakingDI
import SpeakingUI
import SwiftUI
import VocabularyDI
import VocabularyDomain
import VocabularyUI

/// Which exercise a lesson opens into.
enum LessonRoute: Identifiable, Hashable {
    case matching(LessonRequest)
    case speaking(LessonRequest)

    var id: UUID {
        switch self {
        case .matching(let request), .speaking(let request): return request.id
        }
    }
}

/// The app's root: the home stack, and the lessons presented over it.
struct ContentView: View {
    let dependencies: Dependencies

    @State private var activeLesson: LessonRoute?

    var body: some View {
        NavigationStack {
            HomeFactory.makeRoute(
                dependencies: dependencies,
                navigation: HomeNavigation(
                    didRequestMatching: { activeLesson = .matching($0) },
                    didRequestSpeaking: { activeLesson = .speaking($0) }
                ),
                input: HomeInput(
                    minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                    quickPracticeRounds: MatchingPlanBuilder.exercisesPerLesson,
                    settings: { AnyView(SettingsView()) }
                )
            )
        }
        .fullScreenCover(item: $activeLesson) { route in
            switch route {
            case .matching(let request):
                MatchingLessonView(request: request, saveResults: recordMatchingResults) { activeLesson = nil }
            case .speaking(let request):
                SpeakingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: SpeakingNavigation(didClose: { activeLesson = nil }),
                    input: SpeakingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            }
        }
    }

    /// The matching lesson has no view model yet to report a failure, so this logs it.
    private func recordMatchingResults(_ results: LessonResults) {
        let record = VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
        Task {
            do {
                try await record(results)
            } catch is CancellationError {
                // Cancelled, not a failure.
            } catch {
                let model = (error as? VocabularyDomainError)?.model ?? DomainErrorModel(error)
                ErrorLog.record(model, context: "recordMatchingResults")
            }
        }
    }
}

#Preview {
    ContentView(dependencies: LiveDependencies(modelContainer: try! VocabularyRepositoryFactory.openStore(inMemory: true)))
}
