import SwiftUI

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
    let vocabulary: VocabularyFactory
    let speaking: SpeakingFactory

    @State private var activeLesson: LessonRoute?

    var body: some View {
        NavigationStack {
            vocabulary.makeHomeRoute(
                navigation: HomeNavigation(
                    didRequestMatching: { activeLesson = .matching($0) },
                    didRequestSpeaking: { activeLesson = .speaking($0) }
                ),
                settings: { AnyView(SettingsView()) }
            )
        }
        .fullScreenCover(item: $activeLesson) { route in
            switch route {
            case .matching(let request):
                MatchingLessonView(request: request, saveResults: recordMatchingResults) { activeLesson = nil }
            case .speaking(let request):
                speaking.makeRoute(request: request, navigation: SpeakingNavigation(didClose: { activeLesson = nil }))
            }
        }
    }

    /// The matching lesson has no view model yet to report a failure, so this logs it.
    private func recordMatchingResults(_ results: LessonResults) {
        let record = vocabulary.recordLessonResults
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
    let vocabulary = VocabularyFactory(
        container: try! VocabularyFactory.makeContainer(inMemory: true),
        minimumMatchingWords: 5,
        quickPracticeRounds: 10
    )
    ContentView(vocabulary: vocabulary, speaking: SpeakingFactory(recordResults: vocabulary.recordLessonResults))
}
