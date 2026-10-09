import CoreDI
import CoreUI
import DictionaryDI
import DictionaryDomain
import LibraryDI
import LibraryDomain
import LibraryUI
import PracticeDI
import PracticeDomain
import ProgressDI
import ProgressDomain
import SettingsDI
import SwiftUI

/// Every screen's input, built once, for the app's views and for mando's drivers alike, so the
/// two cannot drift: an input the app gains, mando gains with it. How a screen is shown, the
/// app's tabs and full-screen cover or mando's stack, stays with each.
///
/// Inputs carry both seams where a screen's neighbour is another package's: a view for the app
/// and a driver for running headlessly.
@MainActor
public struct AppComposer {
    public let dependencies: Dependencies
    /// Heard by speaking lessons and today's plan in place of the microphone, when set.
    public let speech: ScriptedSpeech?

    public init(dependencies: Dependencies, speech: ScriptedSpeech?) {
        self.dependencies = dependencies
        self.speech = speech
    }

    // MARK: - Tabs

    public var homeInput: HomeInput {
        HomeInput(
            minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
            quickPracticeRounds: { [dependencies] in
                MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)().rounds
            },
            observeVocabulary: VocabularyRepositoryFactory.makeObserveVocabularyUseCase(dependencies: dependencies),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            clearMistakes: VocabularyRepositoryFactory.makeClearMistakesUseCase(dependencies: dependencies),
            settings: { [self] in AnyView(SettingsFactory.makeRoute(dependencies: dependencies, input: settingsInput)) }
        )
    }

    public var libraryInput: LibraryInput {
        LibraryInput(minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise, dictionary: dictionaryAccess)
    }

    // MARK: - Pushed from home

    /// The settings screen edits what the speaking and matching lessons own, so each hands over
    /// its use cases.
    public var settingsInput: SettingsInput {
        SettingsInput(
            getSpeakingSettings: SpeakingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setStrictness: SpeakingSettingsFactory.makeSetStrictnessUseCase(dependencies: dependencies),
            setSpeakingCardLimit: SpeakingSettingsFactory.makeSetCardLimitUseCase(dependencies: dependencies),
            getMatchingSettings: MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setShowsPinyin: MatchingSettingsFactory.makeSetShowsPinyinUseCase(dependencies: dependencies),
            setMatchingRounds: MatchingSettingsFactory.makeSetRoundsUseCase(dependencies: dependencies),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            setSkipsLearntWords: LessonSettingsFactory.makeSetSkipsLearntWordsUseCase(dependencies: dependencies)
        )
    }

    // MARK: - Between the library and the dictionary

    /// What the library uses of the dictionary: its data, and its page over the library's own
    /// screens. Adding from that page opens the library's editor.
    public var dictionaryAccess: DictionaryAccess {
        DictionaryAccess(
            dictionary: DictionaryRepositoryFactory.makeDictionaryRepository(),
            lexicon: DictionaryRepositoryFactory.makeLexiconRepository(),
            hsk: DictionaryRepositoryFactory.makeHSKRepository(),
            page: { [self] headword, addsToVocabulary in
                AnyView(DictionaryFactory.makeRoute(dependencies: dependencies, input: pageInput(headword, addsToVocabulary)))
            },
            pageDriver: { [self] headword, addsToVocabulary in
                DictionaryFactory.makeDriver(dependencies: dependencies, input: pageInput(headword, addsToVocabulary))
            }
        )
    }

    /// What the dictionary uses of the library: which readings are saved, and the editor that
    /// adds one or opens it.
    public var dictionaryVocabulary: DictionaryVocabulary {
        DictionaryVocabulary(
            savedReadings: VocabularyRepositoryFactory.makeSavedReadingsRepository(dependencies: dependencies),
            editor: { [self] edit in
                AnyView(WordEditorFactory.makeRoute(
                    dependencies: dependencies,
                    input: WordEditorInput(target: WordEditorTarget(edit), dictionary: dictionaryAccess)
                ))
            }
        )
    }

    private func pageInput(_ headword: DictionaryHeadword, _ addsToVocabulary: Bool) -> DictionaryInput {
        DictionaryInput(headword: headword, vocabulary: addsToVocabulary ? dictionaryVocabulary : nil)
    }

    // MARK: - Lessons

    public func matchingInput(_ request: LessonRequest) -> MatchingInput {
        MatchingInput(request: request, recordResults: recordResults)
    }

    public func flashcardsInput(_ request: LessonRequest) -> FlashcardsInput {
        FlashcardsInput(request: request, recordResults: recordResults)
    }

    public func speakingInput(_ request: LessonRequest) -> SpeakingInput {
        SpeakingInput(request: request, recordResults: recordResults, speech: speech)
    }

    public func todayPlanInput(_ plan: TodayPlan) -> MixedLessonInput {
        MixedLessonInput(
            plan: plan,
            recordResults: recordResults,
            findExamples: FindExamplesUseCase(repository: DictionaryRepositoryFactory.makeExampleRepository()),
            generateExample: GenerateExampleUseCase(generator: DictionaryRepositoryFactory.makeExampleGenerator()),
            speech: speech
        )
    }

    public var recordResults: RecordLessonResultsUseCase {
        VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
    }
}
