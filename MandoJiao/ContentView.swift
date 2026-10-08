import CoreDI
import CoreUI
import DictionaryDI
import DictionaryDomain
import LibraryDI
import LibraryDomain
import LibraryUI
import PracticeDI
import PracticeDomain
import PracticeUI
import ProgressDI
import SettingsDI
import SwiftUI

/// The app's root: the home, vocabulary and dictionary tabs, and the lessons presented over all three.
struct ContentView: View {
    let dependencies: Dependencies
    /// Set only when launched for remote driving.
    let screenRegistry: ScreenRegistry?
    /// Set only when launched to hear scripted speech in place of the microphone.
    let scriptedSpeech: ScriptedSpeech?

    @State private var coordinator = AppNavigationCoordinator()

    var body: some View {
        let navigation = AppNavigation.main(coordinator: coordinator)

        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    HomeFactory.makeRoute(
                        dependencies: dependencies,
                        navigation: navigation.progress,
                        input: HomeInput(
                            minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                            quickPracticeRounds: { [dependencies] in
                                MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)().rounds
                            },
                            observeVocabulary: VocabularyRepositoryFactory.makeObserveVocabularyUseCase(dependencies: dependencies),
                            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
                            clearMistakes: VocabularyRepositoryFactory.makeClearMistakesUseCase(dependencies: dependencies),
                            settings: { [dependencies] in AnyView(settings(dependencies: dependencies)) }
                        )
                    )
                }
            }
            Tab("Vocabulary", systemImage: "books.vertical", value: .vocabulary) {
                LibraryFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.library,
                    input: LibraryInput(
                        minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                        dictionary: dictionaryAccess(dependencies: dependencies)
                    )
                )
            }
            Tab("Dictionary", systemImage: "character.book.closed", value: .dictionary) {
                DictionaryTabFactory.makeRoute(dependencies: dependencies, input: dictionaryVocabulary(dependencies: dependencies))
            }
        }
        .fullScreenCover(item: $coordinator.presentedLesson) { lesson in
            switch lesson {
            case .matching(let request):
                MatchingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.practice.matching,
                    input: MatchingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            case .speaking(let request):
                SpeakingFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.practice.speaking,
                    input: SpeakingInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies),
                        speech: scriptedSpeech
                    )
                )
            case .flashcards(let request):
                FlashcardsFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.practice.flashcards,
                    input: FlashcardsInput(
                        request: request,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            case .todayPlan(let plan):
                MixedLessonFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.practice.mixedLesson,
                    input: MixedLessonInput(
                        plan: plan,
                        recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
                    )
                )
            }
        }
        // Outside the cover, so a lesson's screens get the registry too.
        .environment(\.screenRegistry, screenRegistry)
        .onAppear { screenRegistry?.app = coordinator.driver() }
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
    ContentView(dependencies: LiveDependencies(modelContainer: store), screenRegistry: nil, scriptedSpeech: nil)
}
