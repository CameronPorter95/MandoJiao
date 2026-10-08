import CoreDI
import CoreUI
import DictionaryDI
import Foundation
import LibraryDI
import LibraryDomain
import LibraryUI
import PracticeDI
import PracticeDomain
import PracticeTestSupport
import PracticeUI
import ProgressDI
import ProgressDomain
import SwiftData
import SwiftUI

struct CLIDependencies: Dependencies {
    let modelContainer: ModelContainer
}

/// The app's tabs, in its order.
enum CLITab: String, CaseIterable {
    case home, library, dictionary
}

/// The CLI's composition root, as `ContentView` is the app's: the tabs, the lesson presented
/// over them, and what they say while a command runs.
final class Session {
    private let dependencies: CLIDependencies
    private var tabs: [CLITab: ScreenDriver] = [:]
    private(set) var selectedTab = CLITab.home
    /// Lessons, presented over every tab as the app's full-screen cover is.
    private var presented: [ScreenDriver] = []
    private var effectTasks: [String: Task<Void, Never>] = [:]
    /// The speaking lesson's, while one is open, for `say`.
    private var recogniser: ScriptedRecogniser?
    /// Effects and attempts since the last command, printed after it settles.
    private var notes: [String] = []

    init() throws {
        let store = try VocabularyRepositoryFactory.openStore(
            inMemory: true,
            hskWords: { (try? DictionaryRepositoryFactory.bundledHSKWords()) ?? [] }
        )
        dependencies = CLIDependencies(modelContainer: store)
        tabs = [.home: makeHome(), .library: makeLibrary(), .dictionary: makeDictionary()]
        for (tab, driver) in tabs { listen(to: driver, as: tab.rawValue) }
        try? tabs[selectedTab]?.send("appeared", nil)
    }

    /// From the open tab's screen down to the one in front, then any lesson over them.
    var chain: [ScreenDriver] {
        var chain: [ScreenDriver] = []
        var next = tabs[selectedTab]
        while let driver = next {
            chain.append(driver)
            next = driver.front()
        }
        return chain + presented
    }

    var top: ScreenDriver? { chain.last }

    func takeNotes() -> [String] {
        defer { notes.removeAll() }
        return notes
    }

    // MARK: - Commands

    func select(_ name: String) throws {
        guard let tab = CLITab(rawValue: name) else { throw CLIError.usage("tab \(CLITab.allCases.map(\.rawValue).joined(separator: "|"))") }
        // The lesson covers the tab bar, as the app's full-screen cover does.
        guard presented.isEmpty else { throw CLIError.usage("close the lesson first") }
        guard tab != selectedTab else { return }
        try? tabs[selectedTab]?.send("disappeared", nil)
        selectedTab = tab
        try? tabs[tab]?.send("appeared", nil)
    }

    func vocabulary() async -> Vocabulary {
        let stream = VocabularyRepositoryFactory.makeObserveVocabularyUseCase(dependencies: dependencies)()
        for await vocabulary in stream { return vocabulary }
        return .empty
    }

    /// Through the library tab, as tapping it would: a deck is pushed onto its stack, a
    /// top-level folder selected in its sidebar, and a folder inside another pushed.
    func open(_ kind: String, _ query: String) async throws {
        guard presented.isEmpty else { throw CLIError.usage("close the lesson first") }
        let vocabulary = await vocabulary()
        let page: String
        switch kind {
        case "deck":
            guard let deck = Self.find(query, in: vocabulary.decks, name: \.name, key: \.builtInKey) else { throw CLIError.notFound(kind, query) }
            page = #"{"_0":{"deck":{"_0":"\#(deck.id)"}}}"#
            try select(CLITab.library.rawValue)
            try tabs[.library]?.send("opened", Data(page.utf8))
        case "folder":
            guard let folder = Self.find(query, in: vocabulary.folders, name: \.name, key: \.builtInKey) else { throw CLIError.notFound(kind, query) }
            page = #"{"_0":{"folder":{"_0":"\#(folder.id)"}}}"#
            try select(CLITab.library.rawValue)
            try tabs[.library]?.send(folder.parentID == nil ? "selected" : "opened", Data(page.utf8))
        default:
            throw CLIError.usage("open deck|folder <name>")
        }
    }

    func say(_ answer: String) throws {
        guard let recogniser, presented.last?.name == "speaking" else { throw CLIError.notSpeaking }
        recogniser.enqueue(SpeechOutcome(best: answer))
        try presented.last?.send("startListeningTapped", nil)
    }

    /// Closes a lesson, or else pops the deepest stack in the open tab that has anything to pop.
    func back() throws {
        if !presented.isEmpty {
            dismiss()
            return
        }
        guard chain.reversed().contains(where: { $0.back() }) else { throw CLIError.nothingToGoBackFrom }
    }

    // MARK: - Tabs

    private func makeHome() -> ScreenDriver {
        HomeFactory.makeDriver(
            dependencies: dependencies,
            navigation: .app(
                presentMatching: { [unowned self] _ in notes.append("· matching is not driven yet") },
                presentSpeaking: { [unowned self] in presentSpeaking($0) },
                presentFlashcards: { [unowned self] _ in notes.append("· flash cards are not driven yet") },
                presentTodayPlan: { [unowned self] _ in notes.append("· today's plan is not driven yet") }
            ),
            input: HomeInput(
                minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                quickPracticeRounds: { [dependencies] in
                    MatchingSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies)().rounds
                },
                observeVocabulary: VocabularyRepositoryFactory.makeObserveVocabularyUseCase(dependencies: dependencies),
                getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
                clearMistakes: VocabularyRepositoryFactory.makeClearMistakesUseCase(dependencies: dependencies),
                settings: { AnyView(EmptyView()) }
            )
        )
    }

    private func makeLibrary() -> ScreenDriver {
        LibraryFactory.makeDriver(
            dependencies: dependencies,
            navigation: .app(
                presentMatching: { [unowned self] _ in notes.append("· matching is not driven yet") },
                presentSpeaking: { [unowned self] in presentSpeaking($0) },
                presentFlashcards: { [unowned self] _ in notes.append("· flash cards are not driven yet") }
            ),
            input: LibraryInput(
                minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                // Its pages are views, which nothing here drives.
                dictionary: DictionaryAccess(
                    dictionary: DictionaryRepositoryFactory.makeDictionaryRepository(),
                    lexicon: DictionaryRepositoryFactory.makeLexiconRepository(),
                    hsk: DictionaryRepositoryFactory.makeHSKRepository(),
                    page: { _, _ in AnyView(EmptyView()) }
                )
            )
        )
    }

    private func makeDictionary() -> ScreenDriver {
        DictionaryTabFactory.makeDriver(
            dependencies: dependencies,
            input: DictionaryVocabulary(
                savedReadings: VocabularyRepositoryFactory.makeSavedReadingsRepository(dependencies: dependencies),
                editor: { _ in AnyView(EmptyView()) }
            )
        )
    }

    // MARK: - Lessons

    private func presentSpeaking(_ request: LessonRequest) {
        let recogniser = ScriptedRecogniser()
        self.recogniser = recogniser
        let driver = SpeakingFactory.makeDriver(
            dependencies: dependencies,
            navigation: SpeakingNavigation(didClose: { [unowned self] in dismiss() }),
            input: SpeakingInput(
                request: request,
                recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
            ),
            recogniser: recogniser,
            logAttempt: { [unowned self] attempt in
                notes.append("· heard \"\(attempt.outcome.best)\" for \(attempt.card.hanzi): \(attempt.wasCorrect ? "right" : "wrong")")
            }
        )
        presented.append(driver)
        listen(to: driver, as: "lesson")
        try? driver.send("appeared", nil)
    }

    private func dismiss() {
        guard let driver = presented.popLast() else { return }
        try? driver.send("disappeared", nil)
        effectTasks.removeValue(forKey: "lesson")?.cancel()
        recogniser = nil
    }

    /// Only the tabs and the lesson are listened to: what a screen pushed inside a tab leaves
    /// over reaches its tab's effects through the tab's `ChildDrivers`.
    private func listen(to driver: ScreenDriver, as key: String) {
        let effects = driver.effects()
        effectTasks[key] = Task { [unowned self] in
            for await effect in effects { notes.append("· \(effect)") }
        }
    }

    private static func find<Item>(_ query: String, in items: [Item], name: KeyPath<Item, String>, key: KeyPath<Item, String?>) -> Item? where Item: Identifiable, Item.ID == UUID {
        let lowered = query.lowercased()
        return items.first { $0[keyPath: name].lowercased() == lowered }
            ?? items.first { $0[keyPath: key] == query }
            ?? items.first { $0.id.uuidString.lowercased().hasPrefix(lowered) }
    }

    /// Until no screen is busy and the screens and notes stop changing, so a command's knock-on
    /// work lands before its result prints. Gives up after ten seconds.
    func settle() async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        var last = snapshot()
        var stableFor = 0
        while stableFor < 3 || chain.contains(where: { $0.isBusy() }), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            let now = snapshot()
            stableFor = now == last ? stableFor + 1 : 0
            last = now
        }
    }

    private func snapshot() -> String {
        chain.map { $0.dump() }.joined() + "\(notes.count)"
    }
}

enum CLIError: Error, CustomStringConvertible {
    case notFound(String, String)
    case notSpeaking
    case nothingToGoBackFrom
    case usage(String)

    var description: String {
        switch self {
        case .notFound(let kind, let query): "no \(kind) matches \"\(query)\""
        case .notSpeaking: "say needs a speaking lesson open"
        case .nothingToGoBackFrom: "nothing to go back from"
        case .usage(let text): text
        }
    }
}
