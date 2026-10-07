import DictionaryDomain
import Foundation

/// Whether a dictionary reading is already a saved word, for the page and the search list.
enum ReadingInVocabulary: Equatable {
    case absent
    case saved(SavedReading)

    /// Nil while the saved words are not known, or where there is no way into the
    /// vocabulary.
    init?(_ entry: DictionaryEntry, in saved: [SavedReading]?) {
        guard let saved else { return nil }
        self = saved.first { entry.isReading(hanzi: $0.hanzi, pinyin: $0.pinyin) }.map(Self.saved) ?? .absent
    }

    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }

    /// Opens the saved word, or adds the reading.
    func edit(for entry: DictionaryEntry) -> ReadingEdit {
        switch self {
        case .saved(let saved): .open(saved)
        case .absent: .add(entry)
        }
    }
}
