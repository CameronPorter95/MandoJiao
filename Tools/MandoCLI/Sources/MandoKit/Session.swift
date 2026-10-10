import AppComposition
import CoreDI
import CoreUI
import DictionaryDI
import Foundation
import LibraryDI
import LibraryDomain
import LibraryUI
import PracticeDI
import PracticeDomain
import PracticeUI
import ProgressDI
import ProgressDomain
import SettingsDI
import SwiftData

struct CLIDependencies: Dependencies {
    let modelContainer: ModelContainer
}

/// The app's tabs, in its order.
enum CLITab: String, CaseIterable {
    case home, vocabulary, dictionary
}

/// The CLI's composition root, as `ContentView` is the app's: the tabs, the lesson presented
/// over them, and what they say while a command runs.
final class Session: Backend {
    private let dependencies: CLIDependencies
    private var tabs: [CLITab: ScreenDriver] = [:]
    private(set) var selectedTab = CLITab.home
    /// Lessons, presented over every tab as the app's full-screen cover is.
    private var presented: [ScreenDriver] = []
    private var effectTasks: [String: Task<Void, Never>] = [:]
    /// The speaking lesson's, while one is open, for `say`.
    private var speech: ScriptedSpeech?
    /// Effects and attempts since the last command, printed after it settles.
    private var notes: [String] = []

    /// Over an in-memory store seeded as the app seeds a new one, or over a copy of `store`, so
    /// the original, a simulator's say, is never written to.
    init(store: URL? = nil) throws {
        let hskWords = { (try? DictionaryRepositoryFactory.bundledHSKWords()) ?? [] }
        let container = try store.map { try VocabularyRepositoryFactory.openStore(at: Self.copy($0), hskWords: hskWords) }
            ?? VocabularyRepositoryFactory.openStore(inMemory: true, hskWords: hskWords)
        dependencies = CLIDependencies(modelContainer: container)
        tabs = [.home: makeHome(), .vocabulary: makeLibrary(), .dictionary: makeDictionary()]
        for (tab, driver) in tabs { listen(to: driver, as: tab.rawValue) }
        try? tabs[selectedTab]?.send("appeared", nil)
    }

    /// Copies a store with the write-ahead log and index beside it, which can hold writes the
    /// store file has not taken in yet, into a folder of its own. A directory is taken to be the
    /// app's data container, as `xcrun simctl get_app_container … data` prints it.
    static func copy(_ source: URL) throws -> URL {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        var file = source
        if manager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue {
            file = source.appendingPathComponent("Library/Application Support/default.store")
        }
        guard manager.fileExists(atPath: file.path) else { throw CLIError.usage("no store at \(file.path)") }

        let folder = manager.temporaryDirectory.appendingPathComponent("mando-\(UUID().uuidString)")
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(file.lastPathComponent)
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: file.path + suffix)
            guard manager.fileExists(atPath: from.path) else { continue }
            try manager.copyItem(at: from, to: URL(fileURLWithPath: copy.path + suffix))
        }
        return copy
    }

    /// From the open tab's screen down to the one in front, then any lesson over them and the
    /// step in front of it.
    var chain: [ScreenDriver] {
        var chain: [ScreenDriver] = []
        for root in [tabs[selectedTab]] + presented.map(Optional.some) {
            var next = root
            while let driver = next {
                chain.append(driver)
                next = driver.front()
            }
        }
        return chain
    }

    var top: ScreenDriver? { chain.last }

    func list() async -> [String] {
        guard let top else { return [] }
        return chain.map { $0.summary() } + ["actions: \(top.actions.joined(separator: ", "))"]
    }

    func send(_ action: String, _ arguments: String?) throws {
        guard let top else { throw CLIError.usage("nothing is open") }
        try top.send(action, arguments.map { Data($0.utf8) })
    }

    func state() throws -> [String] {
        guard let top else { throw CLIError.usage("nothing is open") }
        return top.dump().split(separator: "\n").map(String.init)
    }

    func takeNotes() -> [String] {
        defer { notes.removeAll() }
        return notes
    }

    // MARK: - Commands

    func select(_ name: String) throws {
        guard let tab = CLITab(rawValue: name) else {
            throw ScreenDriverError.notOneOf("tab", name, CLITab.allCases.map(\.rawValue))
        }
        // The lesson covers the tab bar, as the app's full-screen cover does.
        guard presented.isEmpty else { throw CLIError.usage("close the lesson first") }
        guard tab != selectedTab else { return }
        try? tabs[selectedTab]?.send("disappeared", nil)
        selectedTab = tab
        try? tabs[tab]?.send("appeared", nil)
    }

    /// Through the vocabulary tab, which finds it by name as tapping its row would.
    func open(_ kind: String, _ query: String) async throws {
        guard presented.isEmpty else { throw CLIError.usage("close the lesson first") }
        try select(CLITab.vocabulary.rawValue)
        await settle()
        try tabs[.vocabulary]?.open(kind, query)
    }

    /// To a speaking lesson, or a word read aloud as a step of today's plan.
    func say(_ answer: String) throws {
        guard let speech, let top, top.name == "speaking" else { throw CLIError.notSpeaking }
        speech.enqueue(answer)
        try top.send("startListeningTapped", nil)
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

    /// Every screen's input, as the app's are: mando shows them its own way, and nothing else.
    /// Each lesson's scripted speech is its own, handed to its driver rather than its input.
    private var composer: AppComposer {
        AppComposer(dependencies: dependencies, speech: nil)
    }

    private func makeHome() -> ScreenDriver {
        HomeFactory.makeDriver(
            dependencies: dependencies,
            navigation: .app(
                presentMatching: { [unowned self] in presentMatching($0) },
                presentSpeaking: { [unowned self] in presentSpeaking($0) },
                presentFlashcards: { [unowned self] in presentFlashcards($0) },
                presentTodayPlan: { [unowned self] in presentTodayPlan($0) }
            ),
            input: composer.homeInput,
            settings: { [unowned self] in SettingsFactory.makeDriver(dependencies: dependencies, input: composer.settingsInput) }
        )
    }

    private func makeLibrary() -> ScreenDriver {
        LibraryFactory.makeDriver(
            dependencies: dependencies,
            navigation: .app(
                presentMatching: { [unowned self] in presentMatching($0) },
                presentSpeaking: { [unowned self] in presentSpeaking($0) },
                presentFlashcards: { [unowned self] in presentFlashcards($0) }
            ),
            input: composer.libraryInput
        )
    }

    private func makeDictionary() -> ScreenDriver {
        DictionaryTabFactory.makeDriver(dependencies: dependencies, input: composer.dictionaryVocabulary)
    }

    // MARK: - Lessons

    /// Every lesson closes the same way: its presenter dismisses it.
    private var lessonNavigation: PracticeNavigation {
        .app(dismiss: { [unowned self] in dismiss() })
    }

    private func presentMatching(_ request: LessonRequest) {
        present(MatchingFactory.makeDriver(
            dependencies: dependencies, navigation: lessonNavigation.matching, input: composer.matchingInput(request)
        ))
    }

    private func presentFlashcards(_ request: LessonRequest) {
        present(FlashcardsFactory.makeDriver(
            dependencies: dependencies, navigation: lessonNavigation.flashcards, input: composer.flashcardsInput(request)
        ))
    }

    private func presentSpeaking(_ request: LessonRequest) {
        let speech = ScriptedSpeech()
        present(SpeakingFactory.makeDriver(
            dependencies: dependencies,
            navigation: lessonNavigation.speaking,
            input: composer.speakingInput(request),
            speech: speech,
            logAttempt: logAttempt
        ), speech: speech)
    }

    /// Its read-aloud steps hear the same scripted speech a speaking lesson does.
    private func presentTodayPlan(_ plan: TodayPlan) {
        let speech = ScriptedSpeech()
        present(MixedLessonFactory.makeDriver(
            dependencies: dependencies,
            navigation: lessonNavigation.mixedLesson,
            input: composer.todayPlanInput(plan),
            speech: speech,
            logAttempt: logAttempt
        ), speech: speech)
    }

    private var logAttempt: SpeakingViewModel.LogAttempt {
        { [unowned self] attempt in
            notes.append("· heard \"\(attempt.outcome.best)\" for \(attempt.card.hanzi): \(attempt.wasCorrect ? "right" : "wrong")")
        }
    }

    private func present(_ driver: ScreenDriver, speech: ScriptedSpeech? = nil) {
        self.speech = speech
        presented.append(driver)
        listen(to: driver, as: "lesson")
        try? driver.send("appeared", nil)
    }

    private func dismiss() {
        guard let driver = presented.popLast() else { return }
        try? driver.send("disappeared", nil)
        effectTasks.removeValue(forKey: "lesson")?.cancel()
        speech = nil
    }

    /// Only the tabs and the lesson are listened to: what a screen pushed inside a tab leaves
    /// over reaches its tab's effects through the tab's `ChildDrivers`.
    private func listen(to driver: ScreenDriver, as key: String) {
        let effects = driver.effects()
        effectTasks[key] = Task { [unowned self] in
            for await effect in effects { notes.append("· \(effect)") }
        }
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
    case notSpeaking
    case nothingToGoBackFrom
    case usage(String)

    var description: String {
        switch self {
        case .notSpeaking: "say needs a speaking lesson open"
        case .nothingToGoBackFrom: "nothing to go back from"
        case .usage(let text): text
        }
    }
}
