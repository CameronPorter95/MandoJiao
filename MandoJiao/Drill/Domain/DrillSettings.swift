import Foundation

nonisolated struct DrillSettings: Equatable, Sendable {
    static let defaultCardLimit = 20
    static let `default` = DrillSettings(strictness: .default, cardLimit: defaultCardLimit)

    var strictness: MatchStrictness
    var cardLimit: Int
}

/// Synchronous, because every setting is a local value read when a drill starts.
nonisolated protocol DrillSettingsRepository: Sendable {
    func settings() -> DrillSettings
}

nonisolated struct GetDrillSettingsUseCase: Sendable {
    let repository: any DrillSettingsRepository

    func callAsFunction() -> DrillSettings {
        repository.settings()
    }
}
