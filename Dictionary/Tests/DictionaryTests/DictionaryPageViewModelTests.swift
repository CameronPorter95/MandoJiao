import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import DictionaryTestSupport
@testable import DictionaryDomain
@testable import DictionaryUI

@Suite("Dictionary page")
@MainActor
struct DictionaryPageViewModelTests {
    private let dictionary = FakeDictionaryRepository()

    private func makePage(_ hanzi: String, pinyin: String? = nil, saved: FakeSavedReadingsRepository? = nil) -> DictionaryPageViewModel {
        DictionaryPageViewModel(
            headword: DictionaryHeadword(hanzi: hanzi, pinyin: pinyin),
            lookUpDictionary: LookUpDictionaryUseCase(repository: dictionary),
            observeSaved: saved.map { ObserveSavedReadingsUseCase(repository: $0) }
        )
    }

    private static let hang = SavedReading(id: UUID(), hanzi: "行", pinyin: "háng")

    private func loaded(_ page: DictionaryPageViewModel) async -> (readings: [DictionaryPageState.Reading], characters: [DictionaryPageState.Character])? {
        page.send(.appeared)
        guard await waitUntil({ page.state.content != .loading }),
              case .loaded(let readings, let characters) = page.state.content
        else { return nil }
        return (readings, characters)
    }

    @Test("every reading is shown, the preferred first, and a single character lists no characters")
    func readings() async throws {
        let page = try #require(await loaded(makePage("行")))
        #expect(page.readings.map(\.entry.pinyin) == ["xíng", "háng"])
        #expect(page.characters.isEmpty)
    }

    @Test("the reading asked for comes first however its pinyin is spaced")
    func readingFirst() async throws {
        let page = try #require(await loaded(makePage("行", pinyin: "Háng ")))
        #expect(page.readings.map(\.entry.pinyin) == ["háng", "xíng"])
    }

    @Test("a longer headword lists each character once with its preferred reading, skipping unknown ones")
    func characters() async throws {
        let page = try #require(await loaded(makePage("银行银?")))
        #expect(page.readings.isEmpty)
        #expect(page.characters == [
            .init(hanzi: "银", pinyin: "yín", gloss: "silver"),
            .init(hanzi: "行", pinyin: "xíng", gloss: "to walk"),
        ])
    }

    @Test("a character takes the reading the headword gives it, not its preferred one")
    func characterReadings() async throws {
        let yinhang = FakeDictionaryRepository.entry("银行", "yínháng", preferred: true, "bank")
        let fake = FakeDictionaryRepository(FakeDictionaryRepository.words.filter { $0.simplified != "银行" } + [yinhang])
        let page = DictionaryPageViewModel(
            headword: DictionaryHeadword(hanzi: "银行"),
            lookUpDictionary: LookUpDictionaryUseCase(repository: fake),
            observeSaved: nil
        )
        let loaded = try #require(await loaded(page))
        #expect(loaded.characters.map(\.pinyin) == ["yín", "háng"])
        #expect(loaded.characters.last?.gloss == "row, line")
    }

    @Test("once a character's reading does not match, the rest take their preferred readings")
    func unmatchedReading() {
        var readings = DictionaryPageState.CharacterReadings(pinyin: "yínxíng")
        let xing = FakeDictionaryRepository.words.filter { $0.simplified == "行" }
        let he = FakeDictionaryRepository.words.filter { $0.simplified == "喝" }
        #expect(readings.next(he)?.pinyin == "hē")
        #expect(readings.next(xing.reversed())?.pinyin == "háng")
    }

    @Test("a failed lookup shows as failed, and trying again loads")
    func failure() async throws {
        await dictionary.failLookups()
        let page = makePage("喝")
        page.send(.appeared)
        #expect(await waitUntil { page.state.content == .failed })

        await dictionary.failLookups(with: nil)
        page.send(.retryTapped)
        #expect(await waitUntil {
            if case .loaded(let readings, _) = page.state.content { return readings.count == 2 }
            return false
        })
    }

    @Test("appearing again does not look it up again")
    func loadsOnce() async throws {
        let page = makePage("喝")
        _ = try #require(await loaded(page))
        page.send(.appeared)
        await settle()
        #expect(await dictionary.lookups == ["喝"])
    }

    @Test("a saved reading opens its word, and one not saved is added")
    func vocabulary() async throws {
        let repository = FakeSavedReadingsRepository([SavedReading(id: UUID(), hanzi: "喝", pinyin: "hē"), Self.hang])
        let page = makePage("行", saved: repository)
        let readings = try #require(await loaded(page)).readings
        #expect(await waitUntil { page.state.saved != nil })
        #expect(readings.map { page.state.vocabulary(for: $0) } == [.absent, .saved(Self.hang)])

        page.send(.vocabularyTapped(readings[0].id))
        #expect(page.state.editor == .add(readings[0].entry))
        page.send(.editorDismissed)
        #expect(page.state.editor == nil)

        page.send(.vocabularyTapped(readings[1].id))
        #expect(page.state.editor == .open(Self.hang))
    }

    @Test("a reading shows as saved as soon as the editor saves it, until the page is left")
    func vocabularyLive() async throws {
        let repository = FakeSavedReadingsRepository()
        let page = makePage("行", saved: repository)
        let readings = try #require(await loaded(page)).readings
        #expect(await waitUntil { page.state.saved != nil })
        #expect(page.state.vocabulary(for: readings[0]) == .absent)

        await repository.save(hanzi: "行", pinyin: "xing2")
        #expect(await waitUntil {
            if case .saved = page.state.vocabulary(for: readings[0]) { return true }
            return false
        })

        page.send(.disappeared)
        await repository.replace([])
        await settle()
        #expect(page.state.vocabulary(for: readings[0]) != .absent)
    }

    @Test("a reading with no senses can still be added")
    func vocabularyWithoutSenses() async throws {
        let fake = FakeDictionaryRepository([FakeDictionaryRepository.entry("于", "Yú", preferred: true)])
        let page = DictionaryPageViewModel(
            headword: DictionaryHeadword(hanzi: "于"),
            lookUpDictionary: LookUpDictionaryUseCase(repository: fake),
            observeSaved: ObserveSavedReadingsUseCase(repository: FakeSavedReadingsRepository())
        )
        let readings = try #require(await loaded(page)).readings
        #expect(await waitUntil { page.state.saved != nil })
        page.send(.vocabularyTapped(readings[0].id))
        #expect(page.state.editor == .add(readings[0].entry))
    }

    @Test("without the vocabulary, as in the word editor's dictionary, no reading can be added or opened")
    func noVocabulary() async throws {
        let page = makePage("行")
        let readings = try #require(await loaded(page)).readings
        #expect(readings.allSatisfy { page.state.vocabulary(for: $0) == nil })
        page.send(.vocabularyTapped(readings[0].id))
        #expect(page.state.editor == nil)
    }

    @Test("driven, the page lists each reading with whether it is saved, and opens one by its place")
    func drivenReadings() async throws {
        let page = makePage("行", saved: FakeSavedReadingsRepository([Self.hang]))
        let driver = page.driver(open: nil)
        try driver.send("appeared", nil)
        #expect(await waitUntil { !driver.isBusy() && page.state.saved != nil })

        let summary = driver.summary()
        #expect(summary == "page  行  readings: 0. xíng to walk, okay | 1. háng row, line, profession (saved)")

        try driver.send("vocabularyTapped", Data(#"{"reading":1}"#.utf8))
        #expect(page.state.editor == .open(Self.hang))
        try driver.send("editorDismissed", nil)
        #expect(page.state.editor == nil)
    }

    @Test("driven, a reading's editor is in front while open, and back closes it")
    func drivenEditor() async throws {
        let page = makePage("行", saved: FakeSavedReadingsRepository([Self.hang]))
        let driver = page.driver(open: nil, editor: { edit, _ in editorProbe(edit) })
        try driver.send("appeared", nil)
        #expect(await waitUntil { !driver.isBusy() && page.state.saved != nil })
        #expect(driver.front() == nil)

        try driver.send("vocabularyTapped", Data(#"{"reading":1}"#.utf8))
        #expect(driver.front()?.name == "word editor \(ReadingEdit.open(Self.hang).id)")

        #expect(driver.back())
        #expect(page.state.editor == nil)
        #expect(driver.front() == nil)
        #expect(!driver.back())
    }

    @Test("driven, a character's page is opened through the stack the page is on, and only where there is one")
    func drivenCharacters() async throws {
        var opened: [DictionaryHeadword] = []
        let page = makePage("银行")
        let driver = page.driver(open: { opened.append($0) })
        try driver.send("appeared", nil)
        #expect(await waitUntil { !driver.isBusy() })
        // 行 as 银行 reads it, háng, not its preferred xíng.
        #expect(driver.summary().hasSuffix("characters: 0. 银 yín silver | 1. 行 háng row, line"))

        try driver.send("characterOpened", Data(#"{"character":1}"#.utf8))
        #expect(opened == [DictionaryHeadword(hanzi: "行", pinyin: "háng")])

        let stackless = makePage("银行").driver(open: nil)
        #expect(throws: ScreenDriverError.unknownAction("characterOpened")) {
            try stackless.send("characterOpened", Data(#"{"character":1}"#.utf8))
        }
    }

    @Test("driven by name, every listed action is accepted")
    func driverAcceptsEveryAction() {
        let arguments = ["vocabularyTapped": #"{"reading":0}"#, "characterOpened": #"{"character":0}"#]
        let driver = makePage("银行").driver(open: { _ in })
        for name in driver.actions {
            #expect(throws: Never.self) { try driver.send(name, arguments[name].map { Data($0.utf8) }) }
        }
    }
}

/// A stand-in for the library's word editor, which the dictionary cannot see.
@MainActor
private func editorProbe(_ edit: ReadingEdit) -> ScreenDriver {
    ScreenDriver(
        name: "word editor \(edit.id)", actions: [], state: { 0 }, summary: { _ in "" },
        send: { (_: Int) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
    )
}
