import Foundation

/// Synchronous, because every setting is a local value read when a speaking lesson starts.
public nonisolated protocol SpeakingSettingsRepository: Sendable {
    func settings() -> SpeakingSettings
    func setStrictness(_ strictness: AnswerStrictness)
    func setCardLimit(_ cardLimit: Int)
}
