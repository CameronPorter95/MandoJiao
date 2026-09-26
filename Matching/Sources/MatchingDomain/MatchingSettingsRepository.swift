import Foundation

/// Synchronous, because every setting is a local value.
public nonisolated protocol MatchingSettingsRepository: Sendable {
    func settings() -> MatchingSettings
    func setShowsPinyin(_ showsPinyin: Bool)
}
