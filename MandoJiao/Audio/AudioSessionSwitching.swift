import Foundation

/// Hands the audio session to the microphone and back.
///
/// Foundation-only, like `MatchSoundPlaying`, so the speaking lesson's logic compiles and can be
/// driven where `AVAudioSession` does not exist. `ToneEngine` is the implementation.
@MainActor
protocol AudioSessionSwitching: AnyObject {
    func enterRecordingMode()
    /// Returns once the session is back to normal, so a sound played next is heard at
    /// the usual level.
    func exitRecordingMode() async
}
