import CoreDomain
import CorePersistence
import Foundation
import VocabularyDomain
import SwiftData

@ModelActor
actor VocabularyLocalSourceImpl: VocabularyLocalSource {
    func snapshot() throws -> Vocabulary {
        try storeWork { try vocabulary() }
    }

    func saveWord(id: UUID?, draft: WordDraft) throws {
        try storeWork {
            if let id {
                guard let word = try word(id: id) else { return }
                word.english = draft.english
                word.hanzi = draft.hanzi
                word.pinyin = draft.pinyin
            } else {
                modelContext.insert(VocabWord(english: draft.english, hanzi: draft.hanzi, pinyin: draft.pinyin))
            }
            try modelContext.save()
        }
    }

    func deleteWords(ids: [UUID]) throws {
        try storeWork {
            let ids = Set(ids)
            for word in try modelContext.fetch(FetchDescriptor<VocabWord>()) where ids.contains(word.uuid) {
                modelContext.delete(word)
            }
            try modelContext.save()
        }
    }

    func createDeck(name: String, folderID: UUID?) throws {
        try storeWork {
            var folder: Folder?
            if let folderID {
                guard let found = try self.folder(id: folderID) else { return }
                folder = found
            }
            modelContext.insert(Deck(name: name, folder: folder))
            try modelContext.save()
        }
    }

    func renameDeck(id: UUID, name: String) throws {
        try storeWork {
            guard let deck = try deck(id: id) else { return }
            deck.name = name
            try modelContext.save()
        }
    }

    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) throws {
        try storeWork {
            guard let deck = try deck(id: deckID), let word = try word(id: wordID) else { return }
            let index = deck.words.firstIndex { $0.uuid == wordID }
            switch (isIncluded, index) {
            case (true, nil): deck.words.append(word)
            case (false, let index?): deck.words.remove(at: index)
            default: return
            }
            try modelContext.save()
        }
    }

    func moveDeck(id: UUID, toFolder folderID: UUID?) throws {
        try storeWork {
            guard try vocabulary().canMoveDeck(id, into: folderID), let deck = try deck(id: id) else { return }
            deck.folder = try folderID.flatMap { try folder(id: $0) }
            try modelContext.save()
        }
    }

    func deleteDeck(id: UUID) throws {
        try storeWork {
            guard let deck = try deck(id: id) else { return }
            modelContext.delete(deck)
            try modelContext.save()
        }
    }

    func createFolder(name: String, parentID: UUID?) throws {
        try storeWork {
            var parent: Folder?
            if let parentID {
                guard let found = try folder(id: parentID) else { return }
                parent = found
            }
            modelContext.insert(Folder(name: name, parent: parent))
            try modelContext.save()
        }
    }

    func renameFolder(id: UUID, name: String) throws {
        try storeWork {
            guard let folder = try folder(id: id) else { return }
            folder.name = name
            try modelContext.save()
        }
    }

    func moveFolder(id: UUID, toParent parentID: UUID?) throws {
        try storeWork {
            guard try vocabulary().canMoveFolder(id, into: parentID), let folder = try folder(id: id) else { return }
            folder.parent = try parentID.flatMap { try self.folder(id: $0) }
            try modelContext.save()
        }
    }

    /// Everything beneath goes by the relationships' cascade.
    func deleteFolder(id: UUID) throws {
        try storeWork {
            guard let folder = try folder(id: id) else { return }
            modelContext.delete(folder)
            try modelContext.save()
        }
    }

    func recordResults(_ results: LessonResults) throws {
        try storeWork {
            var changed = false
            for word in try modelContext.fetch(FetchDescriptor<VocabWord>()) {
                switch MistakeUpdate.applying(results, to: word.uuid, missCount: word.missCount) {
                case .missed(let missCount):
                    word.missCount = missCount
                    word.lastMissedAt = .now
                    changed = true
                case .earnedBack(let missCount):
                    word.missCount = missCount
                    changed = true
                case nil:
                    break
                }
            }
            if changed { try modelContext.save() }
        }
    }

    func clearMistakes() throws {
        try storeWork {
            let predicate = #Predicate<VocabWord> { $0.missCount > 0 }
            for word in try modelContext.fetch(FetchDescriptor(predicate: predicate)) {
                word.missCount = 0
                word.lastMissedAt = nil
            }
            try modelContext.save()
        }
    }

    // MARK: - Helpers

    private func vocabulary() throws -> Vocabulary {
        let words = try modelContext.fetch(FetchDescriptor<VocabWord>(sortBy: [SortDescriptor(\.createdAt)]))
        let decks = try modelContext.fetch(FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.createdAt)]))
        let folders = try modelContext.fetch(FetchDescriptor<Folder>(sortBy: [SortDescriptor(\.createdAt)]))
        return Vocabulary(words: words.map(\.domainWord), decks: decks.map(\.summary), folders: folders.map(\.summary))
    }

    private func word(id: UUID) throws -> VocabWord? {
        try modelContext.fetch(FetchDescriptor<VocabWord>(predicate: #Predicate { $0.uuid == id })).first
    }

    private func deck(id: UUID) throws -> Deck? {
        try modelContext.fetch(FetchDescriptor<Deck>(predicate: #Predicate { $0.uuid == id })).first
    }

    private func folder(id: UUID) throws -> Folder? {
        try modelContext.fetch(FetchDescriptor<Folder>(predicate: #Predicate { $0.uuid == id })).first
    }

    /// Wraps every store failure so the repository can tell it from anything else.
    private func storeWork<T>(_ work: () throws -> T) throws -> T {
        do {
            return try work()
        } catch {
            modelContext.rollback()
            throw LocalStoreError(error)
        }
    }
}

extension VocabWord {
    nonisolated var domainWord: Word {
        Word(
            id: uuid,
            english: english,
            hanzi: hanzi,
            pinyin: pinyin,
            missCount: missCount,
            lastMissedAt: lastMissedAt,
            createdAt: createdAt
        )
    }
}

extension Deck {
    nonisolated var summary: DeckSummary {
        DeckSummary(
            id: uuid,
            name: name,
            createdAt: createdAt,
            wordIDs: words.map(\.uuid),
            folderID: folder?.uuid,
            builtInKey: builtInKey
        )
    }
}

extension Folder {
    nonisolated var summary: FolderSummary {
        FolderSummary(id: uuid, name: name, createdAt: createdAt, parentID: parent?.uuid, builtInKey: builtInKey)
    }
}
