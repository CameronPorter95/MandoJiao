import Foundation
import SwiftData

/// A named subset of the library. A lesson is either drawn from every word in
/// the library or bound to one deck.
@Model
final class Deck {
    var name: String = ""
    var createdAt: Date = Date.now

    @Relationship(inverse: \VocabWord.decks)
    var words: [VocabWord] = []

    init(name: String, words: [VocabWord] = []) {
        self.name = name
        self.words = words
        self.createdAt = .now
    }

    var usableWordCount: Int { words.filter(\.isUsable).count }

    var canStartLesson: Bool { usableWordCount >= LessonBuilder.pairsPerExercise }
}
