import Foundation

/// A single translation pair, detached from storage.
///
/// Lessons are built from these rather than from `VocabWord` so the game logic
/// never touches SwiftData once an exercise is underway.
struct WordPair: Identifiable, Hashable {
    let id: UUID
    let english: String
    let hanzi: String
    let pinyin: String

    init(id: UUID = UUID(), english: String, hanzi: String, pinyin: String = "") {
        self.id = id
        self.english = english
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}
