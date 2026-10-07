import CoreDomain
import CorePersistence
import Foundation
import LibraryDomain

/// The store is the source of truth here, not a cache of one, so there is one source
/// and no staleness to manage.
actor VocabularyRepositoryImpl: VocabularyRepository {
    private let localSource: any VocabularyLocalSource
    private var subscribers: [UUID: AsyncStream<Vocabulary>.Continuation] = [:]

    init(localSource: any VocabularyLocalSource) {
        self.localSource = localSource
    }

    nonisolated func vocabulary() -> AsyncStream<Vocabulary> {
        let (stream, continuation) = AsyncStream<Vocabulary>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id) }
        }
        Task { await subscribe(id, continuation) }
        return stream
    }

    func saveWord(id: UUID?, draft: WordDraft, deckID: UUID?) async throws {
        try await write { try await $0.saveWord(id: id, draft: draft, deckID: deckID) }
    }

    func deleteWords(ids: [UUID]) async throws {
        try await write { try await $0.deleteWords(ids: ids) }
    }

    func createDeck(name: String, folderID: UUID) async throws {
        try await write { try await $0.createDeck(name: name, folderID: folderID) }
    }

    func renameDeck(id: UUID, name: String) async throws {
        try await write { try await $0.renameDeck(id: id, name: name) }
    }

    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws {
        try await write { try await $0.setMembership(deckID: deckID, wordID: wordID, isIncluded: isIncluded) }
    }

    func moveDeck(id: UUID, toFolder folderID: UUID?, at index: Int?) async throws {
        try await write { try await $0.moveDeck(id: id, toFolder: folderID, at: index) }
    }

    func deleteDeck(id: UUID) async throws {
        try await write { try await $0.deleteDeck(id: id) }
    }

    func createFolder(name: String, parentID: UUID?) async throws {
        try await write { try await $0.createFolder(name: name, parentID: parentID) }
    }

    func renameFolder(id: UUID, name: String) async throws {
        try await write { try await $0.renameFolder(id: id, name: name) }
    }

    func moveFolder(id: UUID, toParent parentID: UUID?, at index: Int?) async throws {
        try await write { try await $0.moveFolder(id: id, toParent: parentID, at: index) }
    }

    func deleteFolder(id: UUID) async throws {
        try await write { try await $0.deleteFolder(id: id) }
    }

    func install(_ plan: BuiltInPlan) async throws {
        try await write { try await $0.install(plan) }
    }

    func recordResults(_ results: LessonResults) async throws {
        try await write { try await $0.recordResults(results) }
    }

    func setLearnt(wordID: UUID, isLearnt: Bool) async throws {
        try await write { try await $0.setLearnt(wordID: wordID, isLearnt: isLearnt) }
    }

    func clearMistakes() async throws {
        try await write { try await $0.clearMistakes() }
    }

    // MARK: - Helpers

    private func write(_ work: (any VocabularyLocalSource) async throws -> Void) async throws {
        do {
            try await work(localSource)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LocalStoreError {
            throw VocabularyDomainError.persistence(model: error.model)
        } catch {
            throw VocabularyDomainError.unexpected(model: DomainErrorModel(error))
        }
        await publish()
    }

    private func subscribe(_ id: UUID, _ continuation: AsyncStream<Vocabulary>.Continuation) async {
        subscribers[id] = continuation
        if let snapshot = try? await localSource.snapshot() {
            continuation.yield(snapshot)
        }
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }

    /// A failed read leaves subscribers on their last snapshot until the next write.
    private func publish() async {
        guard !subscribers.isEmpty, let snapshot = try? await localSource.snapshot() else { return }
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }
}
