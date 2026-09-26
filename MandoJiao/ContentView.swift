import CoreDI
import MatchingDI
import MatchingDomain
import MatchingUI
import SettingsDI
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
                    quickPracticeRounds: { [dependencies] in
                        MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)().rounds
                    },
                    settings: { [dependencies] in AnyView(settings(dependencies: dependencies)) }
                )
            )
        }
        .fullScreenCover(item: $activeLesson) { route in
            switch route {
            case .matching(let request):
                MatchingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: MatchingNavigation(didClose: { activeLesson = nil }),
                    input: MatchingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
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
}

/// The settings screen edits what the speaking and matching lessons own, so each hands
/// over its use cases.
@MainActor
private func settings(dependencies: Dependencies) -> some View {
    SettingsFactory.makeRoute(
        dependencies: dependencies,
        input: SettingsInput(
            getSpeakingSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setStrictness: SpeakingSettingsFactory.makeSetStrictnessUseCase(dependencies: dependencies),
            setSpeakingCardLimit: SpeakingSettingsFactory.makeSetCardLimitUseCase(dependencies: dependencies),
            getMatchingSettings: MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setShowsPinyin: MatchingSettingsFactory.makeSetShowsPinyinUseCase(dependencies: dependencies),
            setMatchingRounds: MatchingSettingsFactory.makeSetRoundsUseCase(dependencies: dependencies)
        )
    )
}

#Preview {
    ContentView(dependencies: LiveDependencies(modelContainer: try! VocabularyRepositoryFactory.openStore(inMemory: true)))
}
