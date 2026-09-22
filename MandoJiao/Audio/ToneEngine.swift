import AVFoundation
import Foundation

@MainActor
protocol MatchSoundPlaying {
    /// `step` is 0-based; the last step of a board gets the top note.
    func playMatch(step: Int, of total: Int)
    func playMiss()
    func playLessonComplete()
}

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
    private var didStart = false
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    /// C5, then a major-ish scale climbing to the octave.
    private static let baseFrequency = 523.25
    private static let scale = [0, 2, 4, 5, 7, 9, 11, 12]
    private static let playerCount = 6

    private init() {}

    // MARK: - Sounds

    func playMatch(step: Int, of total: Int) {
        let semitones: Int
        if total > 1 && step >= total - 1 {
            semitones = 12
        } else {
            semitones = Self.scale[min(max(step, 0), Self.scale.count - 1)]
        }
        play(semitones: semitones, duration: 0.16, gain: 0.34)
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

    // MARK: - Engine

    private func play(semitones: Int, duration: Double, gain: Double) {
        start()
        guard didStart, !players.isEmpty else { return }

        let frequency = Self.baseFrequency * pow(2, Double(semitones) / 12)
        guard let buffer = buffer(frequency: frequency, duration: duration, gain: gain) else {
            return
        }

        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private func start() {
        guard !didStart else { return }

        // Ambient so practising never interrupts whatever is already playing,
        // and stays quiet when the ringer switch is off.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        for _ in 0..<Self.playerCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }

        do {
            try engine.start()
            players.forEach { $0.play() }
            didStart = true
        } catch {
            players.forEach { engine.detach($0) }
            players = []
            didStart = false
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

/// Used by previews and by anything that should stay silent.
@MainActor
struct SilentSounds: MatchSoundPlaying {
    func playMatch(step: Int, of total: Int) {}
    func playMiss() {}
    func playLessonComplete() {}
}
