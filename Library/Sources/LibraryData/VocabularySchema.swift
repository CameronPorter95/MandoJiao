import CoreDomain
import CorePersistence
import Foundation
import LibraryDomain
import SwiftData

typealias VocabWord = VocabularySchemaV1.VocabWord
typealias Deck = VocabularySchemaV1.Deck
typealias Folder = VocabularySchemaV1.Folder
typealias AnswerRecord = VocabularySchemaV1.AnswerRecord

/// The store's one shape. Until the app is released, a change is made here: with no migration
/// plan SwiftData infers it where it can, and where it cannot the app is reinstalled, since
/// there is no one else's data to migrate. Versions and a plan come back before the first
/// release.
nonisolated enum VocabularySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [VocabWord.self, Deck.self, Folder.self, AnswerRecord.self] }

    @Model
    final class VocabWord {
        /// Stable identity used by lessons and views. `persistentModelID` is not a `UUID`,
        /// and `WordPair` wants one, so the model carries its own.
        var uuid: UUID = UUID()
        var hanzi: String = ""
        var pinyin: String = ""
        /// In the learner's order, the headline first.
        var meanings: [String] = []
        var createdAt: Date = Date.now
        var decks: [Deck] = []

        /// Outstanding mistakes. Goes up when the word is part of a wrong guess and back
        /// down when a later lesson solves it without missing it, so a word leaves the
        /// mistakes list once it has been earned back.
        var missCount: Int = 0
        var lastMissedAt: Date?

        /// `WordMemory`, kept up to date as each lesson is recorded rather than replayed from
        /// the answers on every read.
        var stability: Double = 0
        var lastAnsweredAt: Date?
        var learntAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \AnswerRecord.word)
        var answers: [AnswerRecord] = []

        init(meanings: [String], hanzi: String, pinyin: String = "") {
            self.uuid = UUID()
            self.meanings = meanings
            self.hanzi = hanzi
            self.pinyin = pinyin
            self.createdAt = .now
        }

        convenience init(english: String, hanzi: String, pinyin: String = "") {
            self.init(meanings: english.isEmpty ? [] : [english], hanzi: hanzi, pinyin: pinyin)
        }

        var memory: WordMemory {
            get { WordMemory(stability: stability, lastAnsweredAt: lastAnsweredAt, learntAt: learntAt) }
            set {
                stability = newValue.stability
                lastAnsweredAt = newValue.lastAnsweredAt
                learntAt = newValue.learntAt
            }
        }
    }

    @Model
    final class Deck {
        var uuid: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date.now
        /// Renamed, or a word added or taken away.
        var editedAt: Date = Date.now
        var builtInKey: String?
        /// Order among its siblings.
        var position: Int = 0
        /// When a lesson from it last had anything answered.
        var lastPractisedAt: Date?

        @Relationship(inverse: \VocabWord.decks)
        var words: [VocabWord] = []

        var folder: Folder?

        init(name: String, words: [VocabWord] = [], folder: Folder? = nil, position: Int = 0) {
            self.uuid = UUID()
            self.name = name
            self.words = words
            self.folder = folder
            self.position = position
            self.createdAt = .now
        }
    }

    @Model
    final class Folder {
        var uuid: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date.now
        var builtInKey: String?
        /// Order among its siblings.
        var position: Int = 0
        /// When a lesson from it last had anything answered.
        var lastPractisedAt: Date?

        var parent: Folder?
        @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
        var folders: [Folder] = []
        @Relationship(deleteRule: .cascade, inverse: \Deck.folder)
        var decks: [Deck] = []

        init(name: String, parent: Folder? = nil, position: Int = 0) {
            self.uuid = UUID()
            self.name = name
            self.parent = parent
            self.position = position
            self.createdAt = .now
        }
    }

    /// One `Answer`, kept with its word and gone with it.
    @Model
    final class AnswerRecord {
        var word: VocabWord?
        /// `Answer.Exercise`'s raw value.
        var exercise: String = ""
        /// `Answer.Direction`'s raw value, nil where both sides showed.
        var direction: String?
        var isCorrect: Bool = false
        var wrongAttempts: Int = 0
        var answeredAt: Date = Date.now

        /// Nil if its exercise is not one this build knows.
        var answer: Answer? {
            guard let word, let exercise = Answer.Exercise(rawValue: exercise) else { return nil }
            return Answer(
                wordID: word.uuid, exercise: exercise, direction: direction.flatMap(Answer.Direction.init(rawValue:)),
                isCorrect: isCorrect, wrongAttempts: wrongAttempts
            )
        }

        init(_ answer: Answer, word: VocabWord, at answeredAt: Date) {
            self.word = word
            self.exercise = answer.exercise.rawValue
            self.direction = answer.direction?.rawValue
            self.isCorrect = answer.isCorrect
            self.wrongAttempts = answer.wrongAttempts
            self.answeredAt = answeredAt
        }
    }
}
