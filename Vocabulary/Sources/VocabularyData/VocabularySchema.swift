import CoreDomain
import CorePersistence
import Foundation
import VocabularyDomain
import SwiftData

typealias VocabWord = VocabularySchemaV2.VocabWord
typealias Deck = VocabularySchemaV2.Deck

/// The store as shipped before versioning. Must match it exactly, attribute for
/// attribute, or an existing store will not open.
nonisolated enum VocabularySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [VocabWord.self, Deck.self] }

    @Model
    final class VocabWord {
        var uuid: UUID = UUID()
        var english: String = ""
        var hanzi: String = ""
        var pinyin: String = ""
        var createdAt: Date = Date.now
        var decks: [Deck] = []
        var missCount: Int = 0
        var lastMissedAt: Date?

        init() {}
    }

    @Model
    final class Deck {
        var name: String = ""
        var createdAt: Date = Date.now

        @Relationship(inverse: \VocabWord.decks)
        var words: [VocabWord] = []

        init() {}
    }
}

/// Adds `Deck.uuid`, so a deck has an identity that can leave the data layer.
nonisolated enum VocabularySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [VocabWord.self, Deck.self] }

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
    }

    /// A named subset of the library. A lesson is either drawn from every word in
    /// the library or bound to one deck.
    @Model
    final class Deck {
        var uuid: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date.now

        @Relationship(inverse: \VocabWord.decks)
        var words: [VocabWord] = []

        init(name: String, words: [VocabWord] = []) {
            self.uuid = UUID()
            self.name = name
            self.words = words
            self.createdAt = .now
        }
    }
}

nonisolated enum VocabularyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [VocabularySchemaV1.self, VocabularySchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    /// Lightweight migration would give every existing deck the same default `uuid`, so
    /// each one is given its own afterwards.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: VocabularySchemaV1.self,
        toVersion: VocabularySchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            for deck in try context.fetch(FetchDescriptor<VocabularySchemaV2.Deck>()) {
                deck.uuid = UUID()
            }
            try context.save()
        }
    )
}
