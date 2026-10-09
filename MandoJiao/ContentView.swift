import AppComposition
import CoreDI
import CoreUI
import DictionaryDI
import LibraryDI
import PracticeDI
import PracticeUI
import ProgressDI
import SwiftUI

/// The app's root: the home, vocabulary and dictionary tabs, and the lessons presented over all three.
/// Each screen's input comes from `AppComposer`, which mando shares; how screens are shown is here.
struct ContentView: View {
    let dependencies: Dependencies
    /// Set only when launched for remote driving.
    let screenRegistry: ScreenRegistry?
    /// Set only when launched to hear scripted speech in place of the microphone.
    let scriptedSpeech: ScriptedSpeech?

    @State private var coordinator = AppNavigationCoordinator()

    var body: some View {
        let navigation = AppNavigation.main(coordinator: coordinator)
        let composer = AppComposer(dependencies: dependencies, speech: scriptedSpeech)

        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    HomeFactory.makeRoute(dependencies: dependencies, navigation: navigation.progress, input: composer.homeInput)
                }
            }
            Tab("Vocabulary", systemImage: "books.vertical", value: .vocabulary) {
                LibraryFactory.makeRoute(dependencies: dependencies, navigation: navigation.library, input: composer.libraryInput)
            }
            Tab("Dictionary", systemImage: "character.book.closed", value: .dictionary) {
                DictionaryTabFactory.makeRoute(dependencies: dependencies, input: composer.dictionaryVocabulary)
            }
        }
        .fullScreenCover(item: $coordinator.presentedLesson) { lesson in
            switch lesson {
            case .matching(let request):
                MatchingFactory.makeRoute(
                    dependencies: dependencies, navigation: navigation.practice.matching, input: composer.matchingInput(request)
                )
            case .speaking(let request):
                SpeakingFactory.makeRoute(
                    dependencies: dependencies, navigation: navigation.practice.speaking, input: composer.speakingInput(request)
                )
            case .flashcards(let request):
                FlashcardsFactory.makeRoute(
                    dependencies: dependencies, navigation: navigation.practice.flashcards, input: composer.flashcardsInput(request)
                )
            case .todayPlan(let plan):
                MixedLessonFactory.makeRoute(
                    dependencies: dependencies, navigation: navigation.practice.mixedLesson, input: composer.todayPlanInput(plan)
                )
            }
        }
        // Outside the cover, so a lesson's screens get the registry too.
        .environment(\.screenRegistry, screenRegistry)
        .onAppear { screenRegistry?.app = coordinator.driver() }
    }
}

#Preview {
    let store = try! VocabularyRepositoryFactory.openStore(inMemory: true, hskWords: { (try? DictionaryRepositoryFactory.bundledHSKWords()) ?? [] })
    ContentView(dependencies: LiveDependencies(modelContainer: store), screenRegistry: nil, scriptedSpeech: nil)
}
