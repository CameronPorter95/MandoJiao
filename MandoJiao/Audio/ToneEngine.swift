import AVFoundation
import Foundation

/// Synthesised tones, so the pitch can climb with each match instead of playing
/// one canned sound file.
///
/// A small pool of player nodes lets tones overlap, which matters when matches
/// are fired off in quick succession: queueing them on one node would make the
/// audio lag behind the taps.
@MainActor
final class ToneEngine: MatchSoundPlaying {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var isEngineRunning = false
    private var isConfiguring = false
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var isRecordingMode = false
    /// A sound asked for before the engine was ready, played once it is.
    private var pendingTone: (semitones: Int, duration: Double, gain: Double)?

    /// C5, then a major-ish scale climbing to the octave.
    ///
    /// Nonisolated because `semitones(forStep:of:)` is pure and callable from anywhere,
    /// including the tests.
    private nonisolated static let baseFrequency = 523.25
    private nonisolated static let scale = [0, 2, 4, 5, 7, 9, 11, 12]
    private nonisolated static let playerCount = 6

    private init() {}

    // MARK: - Sounds

    func playMatch(step: Int, of total: Int) {
        play(semitones: Self.semitones(forStep: step, of: total), duration: 0.16, gain: 0.34)
    }

    /// The note a step lands on: up the scale, with the last one topping out on the
    /// octave so finishing is audible.
    ///
    /// Split out from `playMatch` so the climb can be asserted without audio hardware.
    ///
    /// A board is five matches and fits the scale directly. A speech drill runs to
    /// twenty cards, and indexing the scale by step would sit on the octave from the
    /// eighth card onward, which stops the pitch telling you anything, so a long lesson
    /// spreads the scale across its whole length instead. With more cards than notes the
    /// climb repeats a note here and there; it never descends.
    nonisolated static func semitones(forStep step: Int, of total: Int) -> Int {
        guard total > 1 else { return scale[0] }

        let clamped = min(max(step, 0), total - 1)
        if clamped == total - 1 { return 12 }

        if total <= scale.count {
            return scale[clamped]
        }

        let position = Double(clamped) / Double(total - 1)
        let index = Int(position * Double(scale.count - 1))
        return scale[min(index, scale.count - 2)]
    }

    func playMiss() {
        // Two low notes a semitone apart, which reads as "nope" without being harsh.
        play(semitones: -17, duration: 0.11, gain: 0.26)
        play(semitones: -18, duration: 0.15, gain: 0.26)
    }

    func playLessonComplete() {
        let arpeggio = [0, 4, 7, 12, 16]
        for (index, semitones) in arpeggio.enumerated() {
            let delay = Double(index) * 0.09
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(semitones: semitones, duration: 0.22, gain: 0.3)
            }
        }
    }

    // MARK: - Sharing the session with the microphone

    /// Switches the audio session over so a recogniser can record.
    ///
    /// `.defaultToSpeaker` is not optional here: under `.playAndRecord` the output
    /// otherwise goes to the earpiece, which makes the feedback tones nearly inaudible
    /// while a card is listening.
    func enterRecordingMode() {
        guard !isRecordingMode else { return }
        isRecordingMode = true
        reconfigure()
    }

    /// Awaitable, so a caller can be sure the session is back to normal before playing
    /// something that needs to be heard at the usual level.
    func exitRecordingMode() async {
        guard isRecordingMode else { return }
        isRecordingMode = false
        isConfiguring = true
        await Self.applySessionConfiguration(recording: false)
        isConfiguring = false
        rebuildEngine()
        flushPendingTone()
    }

    /// Gets the session and engine ready ahead of the first sound.
    ///
    /// Worth calling when a lesson opens: activation is not instant, and priming it
    /// early means the first match does not have to wait for it.
    func prepare() {
        guard !isEngineRunning, !isConfiguring else { return }
        reconfigure()
    }

    private func reconfigure() {
        isConfiguring = true
        let recording = isRecordingMode

        Task {
            await Self.applySessionConfiguration(recording: recording)
            isConfiguring = false
            // A category change tears the engine's graph down, so the node pool is
            // rebuilt rather than reused.
            rebuildEngine()
            flushPendingTone()
        }
    }

    /// Deliberately off the main actor.
    ///
    /// `setActive` can block long enough to stall the UI, and AVAudioSession logs a
    /// runtime warning when it is called on the main thread. The async
    /// `activate(options:completionHandler:)` that the warning suggests is iOS 27, above
    /// this app's deployment target, so the work is moved off the main thread directly.
    private nonisolated static func applySessionConfiguration(recording: Bool) async {
        await Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            if recording {
                // Measurement mode stays. It is what leaves the recogniser's input
                // unprocessed, and recognition accuracy is worth more than the volume of
                // a feedback tone. Its cost to output level is handled by shifting the
                // tones up rather than by weakening the input.
                try? session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            } else {
                // Ambient so practising never interrupts whatever is already playing,
                // and stays quiet when the ringer switch is off.
                try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            }
            try? session.setActive(true)
        }.value
    }

    // MARK: - Engine

    private func play(semitones: Int, duration: Double, gain: Double) {
        guard isEngineRunning, !players.isEmpty else {
            // Setting the session up is asynchronous now, so a sound asked for before it
            // is ready is held rather than dropped. Only the latest is kept: a backlog of
            // stale tones firing at once would be worse than silence.
            pendingTone = (semitones, duration, gain)
            prepare()
            return
        }

        emit(semitones: semitones, duration: duration, gain: gain)
    }

    private func emit(semitones: Int, duration: Double, gain: Double) {
        let frequency = Self.baseFrequency * pow(2, Double(semitones) / 12)
        guard let buffer = buffer(frequency: frequency, duration: duration, gain: gain) else {
            return
        }

        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private func flushPendingTone() {
        guard let tone = pendingTone, isEngineRunning, !players.isEmpty else { return }
        pendingTone = nil
        emit(semitones: tone.semitones, duration: tone.duration, gain: tone.gain)
    }

    private func rebuildEngine() {
        if isEngineRunning {
            engine.stop()
            players.forEach { engine.detach($0) }
            players = []
            isEngineRunning = false
        }

        for _ in 0..<Self.playerCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }

        do {
            try engine.start()
            players.forEach { $0.play() }
            isEngineRunning = true
        } catch {
            players.forEach { engine.detach($0) }
            players = []
            isEngineRunning = false
        }
    }

    /// Sine plus a quiet second harmonic, with a short attack and a long decay
    /// so consecutive tones do not click.
    private func buffer(frequency: Double, duration: Double, gain: Double) -> AVAudioPCMBuffer? {
        let key = "\(Int(frequency.rounded()))-\(Int(duration * 1000))-\(Int(gain * 100))"
        if let cached = buffers[key] { return cached }

        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let frames = Int(frameCount)
        let attackFrames = max(1.0, 0.006 * sampleRate)
        let releaseFrames = Double(frames) * 0.7

        for frame in 0..<frames {
            let time = Double(frame) / sampleRate
            var envelope = 1.0
            if Double(frame) < attackFrames {
                envelope = Double(frame) / attackFrames
            }
            let remaining = Double(frames - frame)
            if remaining < releaseFrames {
                envelope *= remaining / releaseFrames
            }
            let wave = sin(2 * .pi * frequency * time) * 0.82
                + sin(4 * .pi * frequency * time) * 0.18
            samples[frame] = Float(wave * envelope * gain)
        }

        buffers[key] = buffer
        return buffer
    }
}
