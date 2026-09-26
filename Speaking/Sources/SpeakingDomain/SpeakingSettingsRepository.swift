import Foundation

/// Synchronous, because every setting is a local value read when a speaking lesson starts.
public nonisolated protocol SpeakingSettingsRepository: Sendable {
    func settings() -> SpeakingSettings
}
