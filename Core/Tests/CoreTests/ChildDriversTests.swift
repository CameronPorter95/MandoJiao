import Foundation
import Testing
import CoreTestSupport
@testable import CoreUI

@Suite("Child drivers")
@MainActor
struct ChildDriversTests {
    private enum Lifecycle: Decodable {
        case appeared, disappeared
    }

    private final class Log {
        var events: [String] = []
        var made: [String] = []
    }

    private func make(_ key: String, into log: Log) -> ScreenDriver {
        log.made.append(key)
        return ScreenDriver(
            name: key, actions: ["appeared", "disappeared"], state: { key }, summary: { $0 },
            send: { (action: Lifecycle) in log.events.append("\(key) \(action)") },
            effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
        )
    }

    @Test("a push covers the screen beneath, which comes back as it was when uncovered")
    func pushAndPop() {
        let log = Log()
        let children = ChildDrivers<String>()

        #expect(children.front(of: ["a"]) { make($0, into: log) }?.name == "a")
        #expect(children.front(of: ["a", "b"]) { make($0, into: log) }?.name == "b")
        #expect(children.front(of: ["a"]) { make($0, into: log) }?.name == "a")

        #expect(log.events == ["a appeared", "a disappeared", "b appeared", "b disappeared", "a appeared"])
        #expect(log.made == ["a", "b"])
    }

    @Test("asking again for the same stack changes nothing")
    func steady() {
        let log = Log()
        let children = ChildDrivers<String>()
        _ = children.front(of: ["a"]) { make($0, into: log) }
        _ = children.front(of: ["a"]) { make($0, into: log) }
        #expect(log.events == ["a appeared"])
    }

    @Test("the front screen's effects reach the relay while it is in front, and wait while covered")
    func relaysEffects() async {
        let channel = EffectChannel<String>()
        let covered = ScreenDriver(
            name: "covered", actions: ["appeared", "disappeared"], state: { 0 }, summary: { _ in "" },
            send: { (_: Lifecycle) in }, effects: { channel.stream() }, follow: { $0 }
        )
        let log = Log()
        let children = ChildDrivers<String>()
        let relayed = EffectLog(ScreenDriver(
            name: "parent", actions: [], state: { 0 }, summary: { _ in "" }, send: { (_: Lifecycle) in },
            effects: { AsyncStream<Int> { _ in } }, follow: { $0 }, relay: children.relay
        ).effects())

        _ = children.front(of: ["covered"]) { _ in covered }
        channel.send("shown")
        #expect(await relayed.equals(["shown"]))

        _ = children.front(of: ["covered", "b"]) { make($0, into: log) }
        channel.send("while covered")
        await settle()
        #expect(relayed.effects == ["shown"])

        _ = children.front(of: ["covered"]) { _ in covered }
        #expect(await relayed.equals(["shown", "while covered"]))
    }

    @Test("an emptied stack takes its front screen away")
    func emptied() {
        let log = Log()
        let children = ChildDrivers<String>()
        _ = children.front(of: ["a", "b"]) { make($0, into: log) }

        #expect(children.front(of: []) { make($0, into: log) } == nil)
        #expect(log.events == ["b appeared", "b disappeared"])
    }
}
