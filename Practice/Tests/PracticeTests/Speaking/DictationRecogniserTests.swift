import AVFoundation
import Testing
@testable import PracticeData

/// `AnalyzerInput(buffer:)` traps on a buffer in a format the analyser cannot use, which crashed
/// the app on the simulator when no analyser format was offered. Only a buffer in its format, or
/// one converted to it, may reach it.
@Suite("Dictation's microphone buffers")
nonisolated struct DictationRecogniserTests {
    private let microphone = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    private let analyser = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    private func buffer(_ format: AVAudioFormat) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800)!
        buffer.frameLength = 4_800
        return buffer
    }

    @Test("with no analyser format, nothing is handed on")
    func noFormat() {
        #expect(DictationRecogniser.analyzerBuffer(buffer(microphone), using: nil, to: nil) == nil)
    }

    @Test("a buffer already in the analyser's format is handed on as it is")
    func sameFormat() {
        let same = buffer(analyser)
        #expect(DictationRecogniser.analyzerBuffer(same, using: nil, to: analyser) === same)
    }

    @Test("another format is converted, and dropped when there is nothing to convert it with")
    func otherFormat() {
        let converter = AVAudioConverter(from: microphone, to: analyser)
        let converted = DictationRecogniser.analyzerBuffer(buffer(microphone), using: converter, to: analyser)
        #expect(converted?.format == analyser)
        #expect((converted?.frameLength ?? 0) > 0)

        #expect(DictationRecogniser.analyzerBuffer(buffer(microphone), using: nil, to: analyser) == nil)
    }
}
