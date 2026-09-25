import Foundation

public nonisolated struct SetDeckMembershipUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func callAsFunction(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws {
        try await repository.setMembership(deckID: deckID, wordID: wordID, isIncluded: isIncluded)
    }
}
