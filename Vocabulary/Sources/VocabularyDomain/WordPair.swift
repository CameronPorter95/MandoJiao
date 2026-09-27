import Foundation

/// A single translation pair, detached from storage.
///
/// Lessons are built from these rather than from `VocabWord` so the game logic
/// never touches SwiftData once an exercise is underway.
public nonisolated struct WordPair: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let english: String
    public let hanzi: String
    public let pinyin: String

    public init(id: UUID = UUID(), english: String, hanzi: String, pinyin: String = "") {
        self.id = id
        self.english = english
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}
