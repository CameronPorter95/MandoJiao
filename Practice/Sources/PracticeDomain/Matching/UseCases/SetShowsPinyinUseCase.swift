import Foundation

public nonisolated struct SetShowsPinyinUseCase: Sendable {
    public let repository: any MatchingSettingsRepository

    public init(repository: any MatchingSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ showsPinyin: Bool) {
        repository.setShowsPinyin(showsPinyin)
    }
}
