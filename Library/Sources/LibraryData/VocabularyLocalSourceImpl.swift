import CoreDomain
import CorePersistence
import Foundation
import LibraryDomain
import SwiftData

@ModelActor
actor VocabularyLocalSourceImpl: VocabularyLocalSource {
    func snapshot() throws -> Vocabulary {
        try storeWork { try vocabulary() }
    }

    func saveWord(id: UUID?, draft: WordDraft, deckID: UUID?) throws {
        try storeWork {
            if let id {
                guard let word = try word(id: id) else { return }
                word.meanings = draft.meanings
                word.hanzi = draft.hanzi
                word.pinyin = draft.pinyin
            } else {
                let word = VocabWord(meanings: draft.meanings, hanzi: draft.hanzi, pinyin: draft.pinyin)
                modelContext.insert(word)
                if let deckID, let deck = try deck(id: deckID) {
                    deck.words.append(word)
                    deck.editedAt = .now
                }
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

    func createDeck(name: String, folderID: UUID) throws {
        try storeWork {
            guard let folder = try self.folder(id: folderID) else { return }
            modelContext.insert(Deck(name: name, folder: folder, position: try vocabulary().decks(in: folderID).count))
            try modelContext.save()
        }
    }

    func renameDeck(id: UUID, name: String) throws {
        try storeWork {
            guard let deck = try deck(id: id) else { return }
            deck.name = name
            deck.editedAt = .now
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
            deck.editedAt = .now
            try modelContext.save()
        }
    }

    func moveDeck(id: UUID, toFolder folderID: UUID?, at index: Int?) throws {
        try storeWork {
            let vocabulary = try vocabulary()
            guard vocabulary.canMoveDeck(id, into: folderID), let deck = try deck(id: id) else { return }
            deck.folder = try folderID.flatMap { try folder(id: $0) }
            let decks = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<Deck>()).map { ($0.uuid, $0) })
            for (position, sibling) in vocabulary.movingDeck(id, into: folderID, at: index).decks(in: folderID).enumerated() {
                decks[sibling.id]?.position = position
            }
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
            modelContext.insert(Folder(name: name, parent: parent, position: try vocabulary().folders(in: parentID).count))
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

    func moveFolder(id: UUID, toParent parentID: UUID?, at index: Int?) throws {
        try storeWork {
            let vocabulary = try vocabulary()
            guard vocabulary.canMoveFolder(id, into: parentID), let folder = try folder(id: id) else { return }
            folder.parent = try parentID.flatMap { try self.folder(id: $0) }
            let folders = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<Folder>()).map { ($0.uuid, $0) })
            for (position, sibling) in vocabulary.movingFolder(id, into: parentID, at: index).folders(in: parentID).enumerated() {
                folders[sibling.id]?.position = position
            }
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

    func install(_ plan: BuiltInPlan) throws {
        try storeWork { try BuiltInInstaller.install(plan, in: modelContext) }
    }

    /// Every answer is kept with its word, all at the time the lesson is recorded, which is
    /// as fine as strength over days needs. An answer to a word since deleted is dropped.
    /// The deck or folder the lesson came from is marked practised then too.
    func recordResults(_ results: LessonResults) throws {
        try storeWork {
            var changed = false
            let answeredAt = Date.now
            switch results.source {
            case .deck(let id):
                if let deck = try deck(id: id) {
                    deck.lastPractisedAt = answeredAt
                    changed = true
                }
            case .folder(let id):
                if let folder = try folder(id: id) {
                    folder.lastPractisedAt = answeredAt
                    changed = true
                }
            case nil:
                break
            }
            let answers = Dictionary(grouping: results.answers, by: \.wordID)
            for word in try modelContext.fetch(FetchDescriptor<VocabWord>()) {
                for answer in answers[word.uuid] ?? [] {
                    modelContext.insert(AnswerRecord(answer, word: word, at: answeredAt))
                    word.memory = word.memory.answered(answer, at: answeredAt)
                    changed = true
                }
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

    func setLearnt(wordID: UUID, isLearnt: Bool) throws {
        try storeWork {
            guard let word = try word(id: wordID), word.memory.isLearnt != isLearnt else { return }
            word.memory = isLearnt ? word.memory.markedLearnt(at: .now) : word.memory.unmarkedLearnt()
            try modelContext.save()
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
        let decks = try modelContext.fetch(FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.position), SortDescriptor(\.createdAt)]))
        let folders = try modelContext.fetch(FetchDescriptor<Folder>(sortBy: [SortDescriptor(\.position), SortDescriptor(\.createdAt)]))
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
            meanings: meanings,
            hanzi: hanzi,
            pinyin: pinyin,
            missCount: missCount,
            lastMissedAt: lastMissedAt,
            createdAt: createdAt,
            memory: memory
        )
    }
}

extension Deck {
    nonisolated var summary: DeckSummary {
        DeckSummary(
            id: uuid,
            name: name,
            createdAt: createdAt,
            editedAt: editedAt,
            wordIDs: words.map(\.uuid),
            folderID: folder?.uuid,
            builtInKey: builtInKey,
            lastPractisedAt: lastPractisedAt
        )
    }
}

extension Folder {
    nonisolated var summary: FolderSummary {
        FolderSummary(
            id: uuid, name: name, createdAt: createdAt, parentID: parent?.uuid,
            builtInKey: builtInKey, lastPractisedAt: lastPractisedAt
        )
    }
}
