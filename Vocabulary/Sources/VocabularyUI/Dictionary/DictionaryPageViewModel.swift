import CoreDomain
import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class DictionaryPageViewModel {
    private(set) var state: DictionaryPageState

    private let lookUpDictionary: LookUpDictionaryUseCase
    private var loading: Task<Void, Never>?

    public init(headword: DictionaryHeadword, lookUpDictionary: LookUpDictionaryUseCase) {
        state = DictionaryPageState(headword: headword)
        self.lookUpDictionary = lookUpDictionary
    }

    func send(_ action: DictionaryPageAction) {
        switch action {
        case .appeared:
            guard loading == nil, state.content == .loading else { return }
            load()

        case .retryTapped:
            state.content = .loading
            load()
        }
    }

    private func load() {
        loading?.cancel()
        let headword = state.headword
        loading = Task { [lookUpDictionary] in
            do {
                let entries = try await lookUpDictionary(hanzi: headword.hanzi)
                let readings = DictionaryPageState.readings(entries, first: headword.pinyin)
                var characters: [DictionaryPageState.Character] = []
                let hanzi = headword.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
                if hanzi.count > 1 {
                    var readingOf = DictionaryPageState.CharacterReadings(pinyin: readings.first?.entry.pinyin ?? headword.pinyin)
                    for character in hanzi {
                        let entry = readingOf.next(try await lookUpDictionary(hanzi: String(character)))
                        guard let entry, !characters.contains(where: { $0.hanzi == String(character) }) else { continue }
                        characters.append(DictionaryPageState.Character(
                            hanzi: String(character),
                            pinyin: entry.pinyin,
                            gloss: entry.senses.first.map { Gloss.plain($0) } ?? ""
                        ))
                    }
                }
                state.content = .loaded(readings: readings, characters: characters)
            } catch is CancellationError {
                // Closed or retried, not a failure.
            } catch {
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                VocabularyError.lookUpDictionaryFailed(domainError).log()
                state.content = .failed
            }
        }
    }
}
