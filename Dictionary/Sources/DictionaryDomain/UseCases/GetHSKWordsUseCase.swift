import Foundation

public nonisolated struct GetHSKWordsUseCase: Sendable {
    public let hsk: any HSKRepository

    public init(hsk: any HSKRepository) {
        self.hsk = hsk
    }

    public func callAsFunction() async throws -> [HSKWord] {
        try await hsk.words()
    }
}
