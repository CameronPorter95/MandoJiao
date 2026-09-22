import Foundation
import SwiftData

@Model
final class VocabWord {
    /// Stable identity used by lessons and views. `persistentModelID` is not a
    /// `UUID`, and `WordPair` wants one, so the model carries its own.
    var uuid: UUID = UUID()
    var english: String = ""
    var hanzi: String = ""
    var pinyin: String = ""
    var createdAt: Date = Date.now
    var decks: [Deck] = []

    /// Outstanding mistakes. Goes up when the word is part of a wrong guess and
    /// back down when a later lesson solves it without missing it, so a word
    /// leaves the mistakes list once it has been earned back.
    var missCount: Int = 0
    var lastMissedAt: Date?

    init(english: String, hanzi: String, pinyin: String = "") {
        self.uuid = UUID()
        self.english = english
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.createdAt = .now
    }

    var pair: WordPair {
        WordPair(id: uuid, english: english, hanzi: hanzi, pinyin: pinyin)
    }

    var isUsable: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Array where Element == VocabWord {
    var pairs: [WordPair] { filter(\.isUsable).map(\.pair) }
}
