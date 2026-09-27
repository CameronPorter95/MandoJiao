import Foundation

@MainActor
public protocol MatchSoundPlaying {
    /// Gets the engine ready ahead of the first sound. Activation is not instant, and
    /// priming it when a lesson opens means the first match does not wait for it.
    func prepare()
    /// `step` is 0-based; the last step of a board gets the top note.
    func playMatch(step: Int, of total: Int)
    func playMiss()
    func playLessonComplete()
}

/// Used by previews and by anything that should stay silent.
@MainActor
public struct SilentSounds: MatchSoundPlaying {
    public init() {}
    public func prepare() {}
    public func playMatch(step: Int, of total: Int) {}
    public func playMiss() {}
    public func playLessonComplete() {}
}
