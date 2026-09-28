import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyUI

@Suite("Dictionary page")
@MainActor
struct DictionaryPageViewModelTests {
    private let dictionary = FakeDictionaryRepository()

    private func makePage(_ hanzi: String, pinyin: String? = nil) -> DictionaryPageViewModel {
        DictionaryPageViewModel(
            headword: DictionaryHeadword(hanzi: hanzi, pinyin: pinyin),
            lookUpDictionary: LookUpDictionaryUseCase(repository: dictionary)
        )
    }

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
            lookUpDictionary: LookUpDictionaryUseCase(repository: fake)
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
}
