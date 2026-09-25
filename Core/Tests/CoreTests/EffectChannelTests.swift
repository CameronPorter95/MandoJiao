import Foundation
import Testing
import CoreTestSupport
@testable import CoreUI

@Suite("Effect channel")
@MainActor
struct EffectChannelTests {
    @Test("an effect sent with nobody listening waits for the next listener")
    func buffersWithoutAListener() async {
        let channel = EffectChannel<Int>()
        channel.send(1)

        let log = EffectLog(channel.stream())

        #expect(await log.equals([1]))
    }

    @Test("a listener that went away does not swallow later effects")
    func survivesADisappearance() async {
        // What happens to a Route's .task when another screen is pushed over it.
        let channel = EffectChannel<Int>()
        let first = Task { for await _ in channel.stream() {} }
        await settle()
        first.cancel()
        await settle()

        channel.send(2)
        let log = EffectLog(channel.stream())

        #expect(await log.equals([2]))
    }

    @Test("a new listener replaces the old one")
    func oneListener() async {
        let channel = EffectChannel<Int>()
        let old = EffectLog(channel.stream())
        let new = EffectLog(channel.stream())

        channel.send(3)

        #expect(await new.equals([3]))
        #expect(old.effects.isEmpty)
    }
}
