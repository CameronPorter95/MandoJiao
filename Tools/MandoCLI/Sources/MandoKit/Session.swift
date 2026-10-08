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
import SwiftData

struct CLIDependencies: Dependencies {
    let modelContainer: ModelContainer
}

/// The CLI's composition root: the store, the screens open over one another, and what they
/// say while a command runs.
final class Session {
    private let dependencies: CLIDependencies
    private var stack: [ScreenDriver] = []
    private var effectTasks: [Task<Void, Never>] = []
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
    }

    var top: ScreenDriver? { stack.last }

    func takeNotes() -> [String] {
        defer { notes.removeAll() }
        return notes
    }

    // MARK: - Commands

    func vocabulary() async -> Vocabulary {
        let stream = VocabularyRepositoryFactory.makeObserveVocabularyUseCase(dependencies: dependencies)()
        for await vocabulary in stream { return vocabulary }
        return .empty
    }

    func openDeck(_ query: String) async throws {
        let vocabulary = await vocabulary()
        guard let deck = Self.find(query, in: vocabulary.decks) else { throw CLIError.noDeck(query) }
        push(DeckDetailFactory.makeDriver(
            dependencies: dependencies,
            navigation: DeckDetailNavigation(
                didRequestMatching: { [unowned self] _ in notes.append("· matching is not driven yet") },
                didRequestFlashcards: { [unowned self] _ in notes.append("· flash cards are not driven yet") },
                didRequestSpeaking: { [unowned self] in presentSpeaking($0) }
            ),
            input: DeckDetailInput(
                deckID: deck.id,
                minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                vocabulary: vocabulary
            )
        ))
    }

    func say(_ answer: String) throws {
        guard let recogniser, top?.name == "speaking" else { throw CLIError.notSpeaking }
        recogniser.enqueue(SpeechOutcome(best: answer))
        try top?.send("startListeningTapped", nil)
    }

    func back() throws {
        guard !stack.isEmpty else { throw CLIError.nothingOpen }
        pop()
    }

    // MARK: - Screens

    private func presentSpeaking(_ request: LessonRequest) {
        let recogniser = ScriptedRecogniser()
        self.recogniser = recogniser
        push(SpeakingFactory.makeDriver(
            dependencies: dependencies,
            navigation: SpeakingNavigation(didClose: { [unowned self] in pop() }),
            input: SpeakingInput(
                request: request,
                recordResults: VocabularyRepositoryFactory.makeRecordLessonResultsUseCase(dependencies: dependencies)
            ),
            recogniser: recogniser,
            logAttempt: { [unowned self] attempt in
                notes.append("· heard \"\(attempt.outcome.best)\" for \(attempt.card.hanzi): \(attempt.wasCorrect ? "right" : "wrong")")
            }
        ))
    }

    private func push(_ driver: ScreenDriver) {
        stack.append(driver)
        let effects = driver.effects()
        effectTasks.append(Task { [unowned self] in
            for await effect in effects { notes.append("· \(effect)") }
        })
        try? driver.send("appeared", nil)
    }

    private func pop() {
        guard let driver = stack.popLast() else { return }
        try? driver.send("disappeared", nil)
        effectTasks.popLast()?.cancel()
        if driver.name == "speaking" { recogniser = nil }
    }

    /// By name, ignoring case, then by built-in key, then by the start of its id.
    private static func find(_ query: String, in decks: [DeckSummary]) -> DeckSummary? {
        let lowered = query.lowercased()
        return decks.first { $0.name.lowercased() == lowered }
            ?? decks.first { $0.builtInKey == query }
            ?? decks.first { $0.id.uuidString.lowercased().hasPrefix(lowered) }
    }

    /// Until the open screen and the stack stop changing, so a command's knock-on work lands
    /// before its result prints. Gives up after two seconds.
    func settle() async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        var last = snapshot()
        var stableFor = 0
        while stableFor < 3, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            let now = snapshot()
            stableFor = now == last ? stableFor + 1 : 0
            last = now
        }
    }

    private func snapshot() -> String {
        "\(stack.count) \(top?.dump() ?? "") \(notes.count)"
    }
}

enum CLIError: Error, CustomStringConvertible {
    case noDeck(String)
    case notSpeaking
    case nothingOpen
    case usage(String)

    var description: String {
        switch self {
        case .noDeck(let query): "no deck matches \"\(query)\""
        case .notSpeaking: "say needs a speaking lesson open"
        case .nothingOpen: "nothing is open"
        case .usage(let text): text
        }
    }
}
