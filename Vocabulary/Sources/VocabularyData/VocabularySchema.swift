import CoreDomain
import CorePersistence
import Foundation
import VocabularyDomain
import SwiftData

typealias VocabWord = VocabularySchemaV4.VocabWord
typealias Deck = VocabularySchemaV4.Deck
typealias Folder = VocabularySchemaV4.Folder

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

/// Adds folders, and a key for decks and folders the app supplies.
nonisolated enum VocabularySchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] { [VocabWord.self, Deck.self, Folder.self] }

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

        init(english: String, hanzi: String, pinyin: String = "") {
            self.uuid = UUID()
            self.english = english
            self.hanzi = hanzi
            self.pinyin = pinyin
            self.createdAt = .now
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
}

/// Gives a word an ordered list of meanings.
nonisolated enum VocabularySchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] { [VocabWord.self, Deck.self, Folder.self] }

    @Model
    final class VocabWord {
        var uuid: UUID = UUID()
        var hanzi: String = ""
        var pinyin: String = ""
        /// The headline, kept equal to `meanings.first` so a store saved before meanings reads.
        var english: String = ""
        /// Empty in a store saved before meanings, where `english` is the only one.
        var meanings: [String] = []
        var createdAt: Date = Date.now
        var decks: [Deck] = []
        var missCount: Int = 0
        var lastMissedAt: Date?

        init(meanings: [String], hanzi: String, pinyin: String = "") {
            self.uuid = UUID()
            self.english = meanings.first ?? ""
            self.meanings = meanings
            self.hanzi = hanzi
            self.pinyin = pinyin
            self.createdAt = .now
        }

        convenience init(english: String, hanzi: String, pinyin: String = "") {
            self.init(meanings: english.isEmpty ? [] : [english], hanzi: hanzi, pinyin: pinyin)
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
}

nonisolated enum VocabularyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VocabularySchemaV1.self, VocabularySchemaV2.self, VocabularySchemaV3.self, VocabularySchemaV4.self]
    }
    static var stages: [MigrationStage] { [v1ToV2, v2ToV3, v3ToV4] }

    static let v3ToV4 = MigrationStage.lightweight(fromVersion: VocabularySchemaV3.self, toVersion: VocabularySchemaV4.self)

    static let v2ToV3 = MigrationStage.lightweight(fromVersion: VocabularySchemaV2.self, toVersion: VocabularySchemaV3.self)

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
