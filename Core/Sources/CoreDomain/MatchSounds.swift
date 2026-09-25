import Foundation

@MainActor
public protocol MatchSoundPlaying {
    /// `step` is 0-based; the last step of a board gets the top note.
    func playMatch(step: Int, of total: Int)
    func playMiss()
    func playLessonComplete()
}

/// Used by previews and by anything that should stay silent.
@MainActor
public struct SilentSounds: MatchSoundPlaying {
    public init() {}
    public func playMatch(step: Int, of total: Int) {}
    public func playMiss() {}
    public func playLessonComplete() {}
}

/// Where the exercises get their sound from.
///
/// This indirection keeps the protocol in a file that imports Foundation only, so the
/// exercise logic compiles and can be checked without `AVAudioSession`, which does not
/// exist off iOS. The app points this at `ToneEngine` at launch.
@MainActor
public enum MatchSounds {
    public static var shared: MatchSoundPlaying = SilentSounds()
}
