import Foundation

nonisolated struct SetDeckMembershipUseCase: Sendable {
    let repository: any VocabularyRepository

    func callAsFunction(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws {
        try await repository.setMembership(deckID: deckID, wordID: wordID, isIncluded: isIncluded)
    }
}
