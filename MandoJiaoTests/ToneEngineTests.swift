import Testing
@testable import MandoJiao

@Suite("Success tone pitch")
struct ToneEngineTests {
    @Test("the pitch climbs with every match and tops out on the octave")
    func climbAcrossABoard() {
        let steps = (0..<5).map { ToneEngine.semitones(forStep: $0, of: 5) }

        #expect(steps == [0, 2, 4, 5, 12])
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("a lesson of any length ends on the octave and never descends", arguments: [2, 3, 7, 8, 12, 20])
    func climbsForAnyLength(total: Int) {
        let steps = (0..<total).map { ToneEngine.semitones(forStep: $0, of: total) }

        #expect(steps.last == 12, "the final step should land on the octave: \(steps)")
        #expect(
            zip(steps, steps.dropFirst()).allSatisfy { $0 <= $1 },
            "the climb should never go backwards: \(steps)"
        )
    }

    @Test("a long drill keeps climbing instead of sitting on the octave")
    func longDrillDoesNotPlateauEarly() {
        // The scale has eight notes and a drill runs to twenty cards. Indexing the scale
        // by card number would put every card from the eighth onward on the same octave,
        // so the pitch would stop meaning anything well before the end.
        let steps = (0..<20).map { ToneEngine.semitones(forStep: $0, of: 20) }

        #expect(steps[8] < 12, "the ninth card of twenty should not already be at the top")
        #expect(steps[14] < 12, "the fifteenth card of twenty should not already be at the top")
        #expect(Set(steps).count >= 6, "a long drill should use most of the scale: \(steps)")
    }

    @Test("a single-card drill plays the base note")
    func singleCard() {
        #expect(ToneEngine.semitones(forStep: 0, of: 1) == 0)
    }

    @Test("tones are raised while the microphone session is in force")
    func recordingBoost() {
        // A speech drill runs .playAndRecord in .measurement mode, which turns off output
        // processing and makes the same buffer noticeably quieter than in a matching
        // lesson. Without this the two exercises are not equally loud.
        let match = 0.34
        #expect(ToneEngine.outputGain(match, recording: false) == match)
        #expect(ToneEngine.outputGain(match, recording: true) > match)
    }

    @Test(
        "the boost never pushes a tone into clipping",
        arguments: [0.26, 0.34, 0.5, 0.8, 1.0]
    )
    func gainIsClamped(base: Double) {
        // The waveform peaks at about the gain it is given, so anything over 1 turns into
        // a buzz instead of getting louder.
        #expect(ToneEngine.outputGain(base, recording: true) <= 1)
        #expect(ToneEngine.outputGain(base, recording: false) <= 1)
    }

    @Test("out of range steps stay inside the scale")
    func clampsOutOfRange() {
        #expect(ToneEngine.semitones(forStep: -5, of: 5) == 0)
        #expect(ToneEngine.semitones(forStep: 99, of: 5) == 12)
    }
}
