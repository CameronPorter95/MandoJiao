import Foundation
import VocabularyDomain

struct DictionaryPageState: Equatable {
    struct Reading: Equatable, Identifiable {
        let id: Int
        let entry: DictionaryEntry
        /// The reading the library word that opened the page has.
        let isLibraryReading: Bool
    }

    /// One character of a longer headword, with its preferred reading.
    struct Character: Equatable, Identifiable {
        let hanzi: String
        let pinyin: String
        let gloss: String

        var id: String { hanzi }
    }

    enum Content: Equatable {
        case loading
        case loaded(readings: [Reading], characters: [Character])
        case failed
    }

    let headword: DictionaryHeadword
    var content: Content = .loading

    /// Only when it differs, since for most characters it does not.
    var traditional: String? {
        guard case .loaded(let readings, _) = content,
              let traditional = readings.first?.entry.traditional,
              traditional != headword.hanzi
        else { return nil }
        return traditional
    }

    /// The library word's reading first, then as the dictionary orders them.
    static func readings(_ entries: [DictionaryEntry], libraryPinyin: String?) -> [Reading] {
        let key = libraryPinyin.map(Self.comparable)
        let isLibrary = { (entry: DictionaryEntry) in key != nil && Self.comparable(entry.pinyin) == key }
        let ordered = entries.filter(isLibrary) + entries.filter { !isLibrary($0) }
        return ordered.enumerated().map { Reading(id: $0.offset, entry: $0.element, isLibraryReading: isLibrary($0.element)) }
    }

    /// Walks a headword's pinyin a character at a time, so 行 in 银行 yínháng reads háng
    /// rather than its preferred xíng. From the first character whose readings do not
    /// match, such as the neutral tone in 谢谢 xièxie, every one takes its preferred reading.
    struct CharacterReadings {
        private var remaining: String?

        init(pinyin: String?) {
            remaining = pinyin.map(DictionaryPageState.comparable)
        }

        mutating func next(_ entries: [DictionaryEntry]) -> DictionaryEntry? {
            if let remaining,
               let entry = entries.first(where: { remaining.hasPrefix(DictionaryPageState.comparable($0.pinyin)) }) {
                self.remaining = String(remaining.dropFirst(DictionaryPageState.comparable(entry.pinyin).count))
                return entry
            }
            remaining = nil
            return entries.first
        }
    }

    /// Typed pinyin may be spaced or capitalised differently from the dictionary's.
    fileprivate static func comparable(_ pinyin: String) -> String {
        pinyin.lowercased().filter { !$0.isWhitespace }
    }
}

enum DictionaryPageAction: Equatable {
    case appeared
    case retryTapped
}
