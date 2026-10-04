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
    private let observeVocabulary: ObserveVocabularyUseCase?
    private var loading: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    /// Without `observeVocabulary` the page offers no way into the vocabulary.
    public init(
        headword: DictionaryHeadword,
        lookUpDictionary: LookUpDictionaryUseCase,
        observeVocabulary: ObserveVocabularyUseCase?
    ) {
        state = DictionaryPageState(headword: headword)
        self.lookUpDictionary = lookUpDictionary
        self.observeVocabulary = observeVocabulary
    }

    func send(_ action: DictionaryPageAction) {
        switch action {
        case .appeared:
            observe()
            guard loading == nil, state.content == .loading else { return }
            load()

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .retryTapped:
            state.content = .loading
            load()

        case .vocabularyTapped(let id):
            guard let reading = state.reading(id), let vocabulary = state.vocabulary(for: reading) else { return }
            state.editor = vocabulary.editor(for: reading.entry)

        case .editorDismissed:
            state.editor = nil
        }
    }

    /// Live, so a reading shows as saved as soon as the editor saves it.
    private func observe() {
        guard let observeVocabulary, observation == nil else { return }
        let stream = observeVocabulary()
        observation = Task { [weak self] in
            for await vocabulary in stream {
                self?.state.words = vocabulary.words
            }
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
