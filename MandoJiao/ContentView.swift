import CoreDI
import DictionaryDI
import DictionaryDomain
import PracticeDI
import PracticeDomain
import SettingsDI
import SwiftUI
import VocabularyDI
import VocabularyDomain
import VocabularyUI

/// The app's root: the home, vocabulary and dictionary tabs, and the lessons presented over all three.
struct ContentView: View {
    let dependencies: Dependencies

    @State private var coordinator = AppNavigationCoordinator()

    var body: some View {
        let navigation = AppNavigation.main(coordinator: coordinator)

        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeFactory.makeRoute(
                        dependencies: dependencies,
                        navigation: navigation.vocabulary,
                        input: HomeInput(
                            minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                            quickPracticeRounds: { [dependencies] in
                                MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)().rounds
                            },
                            settings: { [dependencies] in AnyView(settings(dependencies: dependencies)) }
                        )
                    )
                }
            }
            Tab("Vocabulary", systemImage: "books.vertical") {
                LibraryFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.vocabulary,
                    input: LibraryInput(
                        minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                        dictionary: dictionaryAccess(dependencies: dependencies)
                    )
                )
            }
            Tab("Dictionary", systemImage: "character.book.closed") {
                DictionaryTabFactory.makeRoute(dependencies: dependencies, input: dictionaryVocabulary(dependencies: dependencies))
            }
        }
        .fullScreenCover(item: $coordinator.presentedLesson) { lesson in
            switch lesson {
            case .matching(let request):
                MatchingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.matching,
                    input: MatchingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            case .speaking(let request):
                SpeakingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.speaking,
                    input: SpeakingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            case .flashcards(let request):
                FlashcardsFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.flashcards,
                    input: FlashcardsInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            case .todayPlan(let plan):
                MixedLessonFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.mixedLesson,
                    input: MixedLessonInput(
                        plan: plan,
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
            setMatchingRounds: MatchingSettingsFactory.makeSetRoundsUseCase(dependencies: dependencies),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setSkipsLearntWords: LessonSettingsFactory.makeSetSkipsLearntWordsUseCase(dependencies: dependencies)
        )
    )
}

/// What the library uses of the dictionary: its data, and its page over the library's own
/// screens. Adding from that page opens the library's editor.
@MainActor
private func dictionaryAccess(dependencies: Dependencies) -> DictionaryAccess {
    DictionaryAccess(
        dictionary: DictionaryRepositoryFactory.makeDictionaryRepository(),
        lexicon: DictionaryRepositoryFactory.makeLexiconRepository(),
        hsk: DictionaryRepositoryFactory.makeHSKRepository(),
        page: { headword, addsToVocabulary in
            AnyView(DictionaryFactory.makeRoute(
                dependencies: dependencies,
                input: DictionaryInput(
                    headword: headword,
                    vocabulary: addsToVocabulary ? dictionaryVocabulary(dependencies: dependencies) : nil
                )
            ))
        }
    )
}

/// What the dictionary uses of the library: which readings are saved, and the editor that
/// adds one or opens it.
@MainActor
private func dictionaryVocabulary(dependencies: Dependencies) -> DictionaryVocabulary {
    DictionaryVocabulary(
        savedReadings: VocabularyRepositoryFactory.makeSavedReadingsRepository(dependencies: dependencies),
        editor: { edit in
            AnyView(WordEditorFactory.makeRoute(
                dependencies: dependencies,
                input: WordEditorInput(target: WordEditorTarget(edit), dictionary: dictionaryAccess(dependencies: dependencies))
            ))
        }
    )
}

#Preview {
    let store = try! VocabularyRepositoryFactory.openStore(inMemory: true, hskWords: { (try? DictionaryRepositoryFactory.bundledHSKWords()) ?? [] })
    ContentView(dependencies: LiveDependencies(modelContainer: store))
}
